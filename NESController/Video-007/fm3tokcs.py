#!/usr/bin/env python3
# fm3kcs.py
#
# Author : Greg Strike (https://www.youtube.com/@GregStrike)
# Copyright (C) 2023
#
# Requires Python 3.1.2 or newer

"""
A tool that converts FCEUX / TAS Editor .FM3 files
to Kansas City Standard encoded audio.

The result is an IMPERFECT representation as KCS
data that is encoded at 300 baud, which is slower
than the NES queries the controller (8 bits * 60 
times a second). The tool attempts to encode only 
controller changes vs. frame-level details to 
make up for this.  If button changes happen 
faster it will be sent ASAP, but, sync problems 
may still occur.
"""

import wave

# KCS parameters 
KCS_FRAMERATE = 9600   # Hz
ONES_FREQ = 2400       # Hz (per KCS)
ZERO_FREQ = 1200       # Hz (per KCS)
AMPLITUDE = 128        # Amplitude of generated square waves
CENTER    = 128        # Center point of generated waves
BYTE_TIME = 0          # Amount of time a byte takes to output (calculated below)

#FM3 parameters
FM3_FRAMES  = 0                                  # Number of frames in the recording (will be read from header later)
FM3_PORTS = 0                                  # Number of controllers in recording (Read from file, only outputs Player1)
#FM3_FRAMERATE = 60.099822938442230224609375      # Each frame is 1 / FM3_FRAMERATE
FM3_FRAMERATE = 60 # Each frame is 1 / FM3_FRAMERATE
FM3_FRAMETIME = 1 / FM3_FRAMERATE

WAV_FRAMES_PER_BYTE = 0 #Number of wave frames for each byte.
WAV_FRAMES_PER_FM3  = 0 #Number of wave frames for each FM3 frame.
wave_frames = 0


# Create a single square wave cycle of a given frequency
def make_square_wave(freq,KCS_FRAMERATE):
    n = int(KCS_FRAMERATE/freq/2)
    return bytearray([CENTER-AMPLITUDE//2])*n + \
           bytearray([CENTER+AMPLITUDE//2])*n

# Create the wave patterns that encode 1s and 0s
one_pulse  = make_square_wave(ONES_FREQ,KCS_FRAMERATE)*8
zero_pulse = make_square_wave(ZERO_FREQ,KCS_FRAMERATE)*4

# Pause to insert after carriage returns (10 NULL bytes)
null_pulse = ((zero_pulse * 9) + (one_pulse * 2))*10



# Take a single byte value and turn it into a bytearray representing
# the associated waveform along with the required start and stop bits.
def kcs_encode_byte(byteval):
    bitmasks = [0x1,0x2,0x4,0x8,0x10,0x20,0x40,0x80]
    # The start bit (0)
    encoded = bytearray(zero_pulse)

    # 8 data bits
    for mask in bitmasks:
                
        #Invert bits.  NES is active low.  FCEUX is active high.
        encoded.extend(zero_pulse if (byteval & mask) else one_pulse)
        #encoded.extend(one_pulse if (byteval & mask) else zero_pulse)

    # Two stop bits (1)
    encoded.extend(one_pulse)
    encoded.extend(one_pulse)
    return encoded

def encode_fm3_data(cur_fm3_frame, last_fm3_frame, byte):
    global wave_frames
    num_frames_passed = (cur_fm3_frame - last_fm3_frame)
    encoded = bytearray()
    encoded_byte = bytearray()
    encoded_adjust = bytearray()
    

    
    #Writes STOP bits for the length of time since last change.
    num_wav_count = num_frames_passed * WAV_FRAMES_PER_FM3
    encoded_adjust = make_square_wave(ONES_FREQ,KCS_FRAMERATE) * int(num_wav_count / len(make_square_wave(ONES_FREQ,KCS_FRAMERATE)))

    #Delete the time it takes to send the byte serially
    if len(encoded_adjust) > WAV_FRAMES_PER_BYTE:
        encoded_adjust = encoded_adjust[:-WAV_FRAMES_PER_BYTE]
    else:
        print("        ERROR: Adjust would overwrite last byte.")

    #Write adjustment wave to attempt sync to FM3 frames
    encoded.extend(encoded_adjust)
    wave_frames += len(encoded_adjust)
    
    fm3_time = cur_fm3_frame * FM3_FRAMETIME
    wav_time = wave_frames / KCS_FRAMERATE
    
    print("...  FM3 Time: {:0.7f}s".format(fm3_time))
    print("...  WAV Time: {:0.7f}s".format(wav_time))
    print("...     Drift: {:0.7f}s".format(fm3_time - wav_time))
    
    #Write actual byte
    encoded_byte = kcs_encode_byte(byte)
    encoded.extend(encoded_byte)
    wave_frames += len(encoded_byte)
    print()    
    return encoded


# Write a WAV file with encoded data. leader and trailer specify the
# number of seconds of carrier signal to encode before and after the data
def kcs_write_wav(filename,data,leader,trailer):
    w = wave.open(filename,"wb")
    w.setnchannels(1)
    w.setsampwidth(1)
    w.setframerate(KCS_FRAMERATE)

    # Write the leader
    w.writeframes(one_pulse*(int(KCS_FRAMERATE/len(one_pulse))*leader))

    lastbyte = None
    last_fm3_frame = 0
    
    for i, byte in enumerate(fm3_player1_data):
        binary_str = format(byte, '08b')
        
        #print("Frame {}: {}".format(i, binary_str))
        if byte != lastbyte or i == len(fm3_player1_data) - 1: #Write any byte that changes, and always last byte.
            print()
            print("Frame {}: {}".format(i, binary_str))
            print("...Writing {}: {}".format(i, binary_str))
            
            frames_to_write = encode_fm3_data(i, last_fm3_frame, byte)
            w.writeframes(frames_to_write)
                
            lastbyte = byte
            last_fm3_frame = i
    
    # Write the trailer
    w.writeframes(one_pulse*(int(KCS_FRAMERATE/len(one_pulse))*trailer))
    w.close()

if __name__ == '__main__':
    import sys
    import re
    if len(sys.argv) != 3:
        print("Usage : %s fm3file outfile" % sys.argv[0],file=sys.stderr)
        raise SystemExit(1)

    in_filename = sys.argv[1]
    out_filename = sys.argv[2]
    
    WAV_FRAMES_PER_BYTE = len(kcs_encode_byte(0x00))
    BYTE_TIME = WAV_FRAMES_PER_BYTE / KCS_FRAMERATE    #Amount of time it takes to play a single byte
    
    # Read the file until the first pipe character to get the header
    with open(in_filename, "rb") as file:
        header = ""
        while True:
            byte = file.read(1)
            if byte == b"|":
                break
            header += byte.decode("utf-8")

        match = re.search(r"port0 (\d+)", header)
        if match:
            port0 = int(match.group(1))
            print("port0:", port0)
        else:
            print("port0 not found.")            

        match = re.search(r"port1 (\d+)", header)
        if match:
            port1 = int(match.group(1))
            print("port1:", port1)
        else:
            print("port1 not found.")            
        
        FM3_PORTS = port0 + port1
        
        # Extract the value after the "length" header using regular expressions
        match = re.search(r"length (\d+)", header)
        if match:
            FM3_FRAMES = int(match.group(1))
        else:
            print("Length not found.")            
            
        WAV_FRAMES_PER_FM3 = KCS_FRAMERATE / FM3_FRAMERATE

        print("      KCS_FRAMERATE:",KCS_FRAMERATE)
        print("WAV_FRAMES_PER_BYTE:",WAV_FRAMES_PER_BYTE)
        print(" WAV_FRAMES_PER_FM3:",WAV_FRAMES_PER_FM3)
        print("          BYTE_TIME: {:0.4f}s".format(BYTE_TIME))
        print("          FM3_PORTS:", FM3_PORTS)
        print("      FM3_FRAMERATE: {:0.4f} fps".format(FM3_FRAMERATE))
        print("      FM3_FRAMETIME: {:0.4f}s".format(FM3_FRAMETIME))
        print("         FM3_FRAMES:", FM3_FRAMES)
            
        #We skip the first byte and then read every other because the first byte of each
        #frame is control signals (ie. soft reset, power, etc...)
        file.seek(len(header) + 2)  # Skip the first binary byte
        fm3_player1_data = file.read(FM3_FRAMES * 3)[::3]  # Read every other byte
    
    print()
    print()    
    kcs_write_wav(out_filename,fm3_player1_data,5,5)