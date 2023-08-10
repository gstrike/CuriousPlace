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

string_pointer   = $0007 ; 2 bytes

program          = $0A00 ; 13824 bytes 

max_spaces       = $0200 ; 1 byte
cur_spaces	 = $0201
cur_char	 = $0202
loop_spaces	 = $0203

E  = %10000000
RW = %01000000
RS = %00100000

  .org $0A00

reset:  
  lda #%00000001 ; Clear display
  jsr lcd_instruction
  
  lda #%00001100 ; Display on; cursor off; blink off
  jsr lcd_instruction
  
  lda #<str_congrats
  sta string_pointer
  lda #>str_congrats
  sta string_pointer + 1
  jsr print_string

  ldy #$ff
delay2:
  ldx #$ff
inner_delay2:
  dex
  nop
  nop
  nop
  nop
  nop
  nop
  nop  
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  bne inner_delay2
  dey
  bne delay2
  
  lda #<str_curious
  sta string_pointer
  lda #>str_curious
  sta string_pointer + 1
  jsr print_string

  ldy #$ff
delay3:
  ldx #$ff
inner_delay3:
  dex
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  bne inner_delay3
  dey
  bne delay3

  lda #$0F
  sta max_spaces

start_left:  
  lda #%00111100
  sta cur_char
  lda max_spaces
  sta loop_spaces

left_loop:
  lda loop_spaces
  sta cur_spaces

  jsr draw

  dec loop_spaces
  beq start_right
  
  jmp left_loop
  
start_right: 
  lda #%00111110
  sta cur_char
  lda #$00
  sta loop_spaces

right_loop:
  lda loop_spaces
  sta cur_spaces
  
  jsr draw
  
  inc loop_spaces
  lda loop_spaces
  cmp max_spaces
  beq start_left
  
  jmp right_loop


draw:
  lda #%00000001 ; Clear display
  jsr lcd_instruction
  
  lda #$20
draw_loop:
  jsr print_char
  dec cur_spaces
  bne draw_loop
  lda cur_char
  jsr print_char
  
  ldy #$ff
delay:
  ldx #$66
inner_delay:
  dex
  bne inner_delay
  dey
  bne delay
  
  rts

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
  
;str_template: .asciiz "ABCDEFGHIJKLMNOP------------------------QRSTUVWXYZ012345------------------------"
 str_congrats: .asciiz "Congratulations!                        It's working!                           "
  str_curious: .asciiz "The Curious Plce                        Love,Greg Strike                        "
