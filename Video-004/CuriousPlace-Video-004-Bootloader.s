VIA1_PORTB = $6000
VIA1_PORTA = $6001
VIA1_DDRB  = $6002
VIA1_DDRA  = $6003
VIA1_T1CL  = $6004
VIA1_T1CH  = $6005
VIA1_ACR   = $600b
VIA1_PCR   = $600c
VIA1_IFR   = $600d
VIA1_IER   = $600e

VIA2_PORTB = $5000
VIA2_PORTA = $5001
VIA2_DDRB  = $5002
VIA2_DDRA  = $5003
VIA2_PCR   = $500c
VIA2_IFR   = $500d
VIA2_IER   = $500e


;bootloader_flags
; bit 7-2: Reserved
;   bit 1: Receive Started
;   bit 0: Receive Complete
ticks            = $0000 ; 4 bytes
bootloader_flags = $0004 ; 1 byte
load_pointer     = $0005 ; 2 bytes
string_pointer   = $0007 ; 2 bytes
last_receive     = $0009 ; 2 bytes

program    = $0A00 ; 13824 bytes


E  = %10000000
RW = %01000000
RS = %00100000

  .org $8000

reset:
  ldx #$ff
  txs

  ;VIA1 Init
  lda #%01111111 ; Disable all Interrupts
  sta VIA1_IER
  lda #%00000000 ; Set all negative edge
  sta VIA1_PCR
  lda #%11111111 ; Set all pins on port B to output
  sta VIA1_DDRB
  lda #%11100000 ; Set top 3 pins on port A to output
  sta VIA1_DDRA
  
  lda #%11000000 ; Enable Timer 1 Interrupt
  sta VIA1_IER

  ;VIA2 Init
  lda #%10010000 ; Enable CB1 Interrupt
  sta VIA2_IER
  lda #%00000000 ; Set all negative edge
  sta VIA2_PCR
  lda #%00000000 ; Set all pins on port B to input
  sta VIA2_DDRB
  lda #%11111111 ; Set all pins on port A to output
  sta VIA2_DDRA
  
  bit VIA2_PORTB ; Clear any existing IRQ
  
  
  lda #%00111000 ; Set 8-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001110 ; Display on; cursor on; blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display
  jsr lcd_instruction
  lda #%00000001 ; Clear display
  jsr lcd_instruction
  
  ;Ensure variables start at zero
  lda #0
  sta ticks
  sta ticks + 1
  sta ticks + 2
  sta ticks + 3
  sta bootloader_flags
  sta last_receive
  sta last_receive + 1
  
  ;Store starting address of program
  lda #<program
  sta load_pointer
  lda #>program
  sta load_pointer + 1
  
  ;Set VIA1 Timer1 to Free Run Mode
  lda #%01000000
  sta VIA1_ACR
  
  ;Set VIA1 Timer1 for every 9998 cycles (n+2)
  lda #$0e
  sta VIA1_T1CL
  lda #$27
  sta VIA1_T1CH
  
  lda #%00000010 ; Home
  jsr lcd_instruction
  
  lda #<str_ready
  sta string_pointer
  lda #>str_ready
  sta string_pointer + 1
  jsr print_string

  cli ; Enable Interrupts
  
loop:
  ;Check if receive has started
  lda bootloader_flags
  and #%00000010 ; Mask out only receive started bit
  cmp #%00000010 ; Has receive started?
  bne loop
  
  ;Check if receive has completed
  lda bootloader_flags
  and #%00000001 ; Mask out only received finish bit
  cmp #%00000001 ; Has receive finished?
  beq receive_complete
  
  sec 
  lda ticks + 1
  sbc last_receive + 1
  cmp #%00000010 ; High byte of 1000 (10 seconds)
  bcc loop
  
  lda bootloader_flags
  ora #%00000001	; Set receive complete
  sta bootloader_flags
  
  jmp loop

print_string:
  ldy #0
print:
  lda (string_pointer),y
  beq exit_print
  jsr print_char
  iny
  jmp print
exit_print:
  rts
  
str_ready:	.asciiz "Ready."
str_complete:   .asciiz "Complete."

receive_complete:
  lda #%00000001 ; Clear display
  jsr lcd_instruction

  lda #<str_complete
  sta string_pointer
  lda #>str_complete
  sta string_pointer + 1
  jsr print_string

  ldy #$ff
delay:
  ldx #$ff
inner_delay:
  dex
  bne inner_delay
  dey
  bne delay

  jmp program
  
lcd_wait:
  pha
  lda #%00000000  ; Port B is input
  sta VIA1_DDRB
lcdbusy:
  lda #RW
  sta VIA1_PORTA
  lda #(RW | E)
  sta VIA1_PORTA
  lda VIA1_PORTB
  and #%10000000
  bne lcdbusy

  lda #RW
  sta VIA1_PORTA
  lda #%11111111  ; Port B is output
  sta VIA1_DDRB
  pla
  rts

lcd_instruction:
  jsr lcd_wait
  sta VIA1_PORTB
  lda #0         ; Clear RS/RW/E bits
  sta VIA1_PORTA
  lda #E         ; Set E bit to send instruction
  sta VIA1_PORTA
  lda #0         ; Clear RS/RW/E bits
  sta VIA1_PORTA
  rts

print_char:
  jsr lcd_wait
  sta VIA1_PORTB
  lda #RS         ; Set RS; Clear RW/E bits
  sta VIA1_PORTA
  lda #(RS | E)   ; Set E bit to send instruction
  sta VIA1_PORTA
  lda #RS         ; Clear E bits
  sta VIA1_PORTA
  rts

nmi:
irq:
  pha
  txa
  pha
  tya
  pha
  
  lda VIA1_IFR		; Check VIA1 IFR
  and #%01000000	; Mask all but Timer1
  cmp #%01000000	; Check if flagged
  beq irq_via1_timer1 
  
  ;Check flag if receive is complete, if so, exit.
  lda bootloader_flags
  and #%00000001	;mask out only receive complete bit
  cmp #%00000001	;is receive complete bit set?
  beq ignore_via2_cb1_irq
  
  lda VIA2_IFR		; Check VIA2 IFR
  and #%00010000	; Mask all but CB1
  cmp #%00010000	; Check if flagged
  beq irq_via2_cb1 
  
  jmp exit_irq
    
ignore_via2_cb1_irq:
  bit VIA2_PORTB
  jmp exit_irq

irq_via1_timer1:
  bit VIA1_T1CL
  inc ticks
  bne exit_irq
  inc ticks + 1
  bne exit_irq
  inc ticks + 2
  bne exit_irq
  inc ticks + 3
  jmp exit_irq

exit_irq:  
  pla
  tay
  pla
  tax
  pla
  
  rti

irq_via2_cb1:
  ;Set flag that we have received our first byte (written over and over every byte.... better way?)
  lda bootloader_flags
  ora #%00000010 ; Set Receive Started flag
  sta bootloader_flags
  
  lda VIA2_PORTB  ; clears interrupt & loads a

  ;Lookup current pointer and store data
  ldy #0
  sta (load_pointer),y
  
  ;Keep track of last time we received a byte
  lda ticks
  sta last_receive
  lda ticks + 1
  sta last_receive + 1
  
  lda #$2E
  jsr print_char
  
  ;Increase pointer
  inc load_pointer
  bne exit_irq
  inc load_pointer + 1  
  

check_end:
  lda #$40             ;High byte of first unusable area
  cmp load_pointer + 1 ;Compare high byte of pointer
  bne exit_irq
  
  ;Reached the max - Set receive complete flag
  lda bootloader_flags
  ora #%00000001    ;Set receive Complete Flag
  sta bootloader_flags
      
  jmp exit_irq

  .org $fffa
  .word nmi
  .word reset
  .word irq
