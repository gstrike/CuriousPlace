VIA1_PORTB = $6000
VIA1_PORTA = $6001
VIA1_DDRB  = $6002
VIA1_DDRA  = $6003
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

value = $0200 ; 2 bytes
mod10 = $0202 ; 2 bytes
message = $0204 ; 6 bytes
counter = $020a ; 2 bytes

E  = %10000000
RW = %01000000
RS = %00100000

  .org $8000

reset:
  ldx #$ff
  txs
  cli

  ;VIA1 Init
  lda #%01111111 ; Disable all Interrupts
  sta VIA1_IER
  lda #%00000000 ; Set all negative edge
  sta VIA1_PCR
  lda #%11111111 ; Set all pins on port B to output
  sta VIA1_DDRB
  lda #%11100000 ; Set top 3 pins on port A to output
  sta VIA1_DDRA

  ;VIA2 Init
  lda #%10010000 ; Enable CB1 Interrupt
  sta VIA2_IER
  lda #%00000000 ; Set all negative edge
  sta VIA2_PCR
  lda #%00000000 ; Set all pins on port B to input
  sta VIA2_DDRB
  lda #%11111111 ; Set all pins on port A to output
  sta VIA2_DDRA
  
  
  lda #%00111000 ; Set 8-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001110 ; Display on; cursor on; blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display
  jsr lcd_instruction
  lda #%00000001 ; Clear display
  jsr lcd_instruction

  ;lda #0
  ;sta counter
  ;sta counter + 1
  
  lda #%00000010 ; Home
  jsr lcd_instruction

loop:
  jmp loop

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
  lda VIA2_PORTB  ; clears interrupt & loads a
  sta message
  jsr print_char

  ;inc counter
  ;bne exit_irq
  ;inc counter + 1
exit_irq:  
  rti

  .org $fffa
  .word nmi
  .word reset
  .word irq
