; ===================================================================
; DSM-51 STOPWATCH - CURSOR VERSION (UP/DOWN ALARM)
; ===================================================================

; --- Hardware Definitions ---
SEG_ON  EQU P1.6            
KEY     EQU P3.5            
BUZZER  EQU P1.5            

; --- Memory Map ---
SEC_ONES    EQU 30H         
SEC_TENS    EQU 31H         
MIN_ONES    EQU 32H         
MIN_TENS    EQU 33H         
HOUR_ONES   EQU 34H          
HOUR_TENS   EQU 35H         

FLAGS       EQU 20H
KEY_LAST    EQU 36H
TICKS       EQU 37H
ALARM_VAL   EQU 38H         

; --- Bit Definitions ---
RUNNING      BIT FLAGS.0    
ALARM_ACTIVE BIT FLAGS.1    

; --- Timer 0 Settings (50ms) ---
TH0_SET     EQU 04CH
TL0_SET     EQU 00H
TMOD_SET    EQU 01H         

; ===================================================================
; VECTORS
; ===================================================================
    ORG 0000H
    LJMP START

    ORG 000BH
    LJMP ISR_TIMER0

; ===================================================================
; MAIN PROGRAM
; ===================================================================
    ORG 0100H

START:
    MOV SP, #60H            
    MOV KEY_LAST, #00H
    MOV TICKS, #20
    CLR RUNNING
    CLR ALARM_ACTIVE        
    SETB BUZZER             

    ; --- DEFAULT SELECTION ---
    MOV ALARM_VAL, #2       ; Default: Alarm at 2 Minutes

    ; Clear Digits
    MOV SEC_ONES, #0
    MOV SEC_TENS, #0
    MOV MIN_ONES, #0
    MOV MIN_TENS, #0
    MOV HOUR_ONES, #0
    MOV HOUR_TENS, #0

    MOV TMOD, #TMOD_SET
    MOV TH0, #TH0_SET
    MOV TL0, #TL0_SET
    SETB ET0                
    SETB EA                 
    SETB TR0                

; ===================================================================
; MAIN LOOP
; ===================================================================
MAIN_LOOP:
    MOV R0, #SEC_ONES       
    MOV R2, #6              
    MOV R3, #00000001B      

SCAN_NEXT:
    MOV DPTR, #0FF30H       ; CSDS Address
    MOV A, R3
    MOVX @DPTR, A           

    MOV A, @R0
    LCALL GET_COD7          
    
    ; Handle Dot Points
    CJNE R3, #04H, CHECK_DOT_HOURS
    ORL A, #80H             
    SJMP WRITE_DISP

CHECK_DOT_HOURS:
    CJNE R3, #10H, WRITE_DISP
    ORL A, #80H             

WRITE_DISP:
    MOV DPTR, #0FF38H       ; CSDB Address
    MOVX @DPTR, A           
    
    CLR SEG_ON              ; Display ON

    LCALL HANDLE_KEYS       ; Check Buttons

    SETB SEG_ON             ; Display OFF
    INC R0                  
    MOV A, R3
    RL A                    
    MOV R3, A
    DJNZ R2, SCAN_NEXT      

    LJMP MAIN_LOOP

; ===================================================================
; SUBROUTINE: HANDLE KEYS (WITH CURSOR LOGIC)
; ===================================================================
HANDLE_KEYS:
    MOV C, KEY
    JNC NO_KEY_PRESS
    MOV A, #20
    LCALL MY_DELAY
    JC KEY_ACTUAL

NO_KEY_PRESS:
    MOV A, R3
    CPL A
    ANL KEY_LAST, A
    RET                     

KEY_ACTUAL:
    MOV A, R3
    ANL A, KEY_LAST
    JNZ RET_KEYS            

    MOV A, R3
    ORL KEY_LAST, A

    ; --- KEY 1: START / STOP (Bit 0) ---
    CJNE R3, #01H, CHECK_RESET
    CPL RUNNING
    
    ; Auto-Clear logic: If we start running, ensure visual count starts at 0
    ; (In case user was just looking at the Alarm Setting)
    JNB RUNNING, RET_KEYS   ; If stopping, do nothing
    MOV MIN_ONES, #0        ; If starting, reset the visual counter to 0
    RET

CHECK_RESET:
    ; --- KEY 2: RESET (Bit 1) ---
    CJNE R3, #02H, CHECK_CURSORS
    CLR RUNNING
    CLR ALARM_ACTIVE        
    MOV SEC_ONES, #0
    MOV SEC_TENS, #0
    MOV MIN_ONES, #0
    MOV MIN_TENS, #0
    MOV HOUR_ONES, #0
    MOV HOUR_TENS, #0
    SETB BUZZER             
    MOV TICKS, #20
    RET

CHECK_CURSORS:
    ; Only allow changing settings if NOT running
    JB RUNNING, RET_KEYS

    ; --- KEY 3: CURSOR UP (Bit 2 / 0x04) ---
    CJNE R3, #04H, CHECK_CURSOR_DOWN
    
    INC ALARM_VAL           ; Increase N
    MOV A, ALARM_VAL
    CJNE A, #10, SHOW_SETTING ; Limit to 9
    MOV ALARM_VAL, #0       ; Wrap to 0
    SJMP SHOW_SETTING

CHECK_CURSOR_DOWN:
    ; --- KEY 4: CURSOR DOWN (Bit 3 / 0x08) ---
    CJNE R3, #08H, RET_KEYS
    
    DEC ALARM_VAL           ; Decrease N
    MOV A, ALARM_VAL
    CJNE A, #0FFH, SHOW_SETTING ; Check for -1
    MOV ALARM_VAL, #9       ; Wrap to 9
    
SHOW_SETTING:
    ; VISUAL FEEDBACK: 
    ; Show the 'N' value on the Minutes Digit so user knows what they picked
    MOV MIN_ONES, ALARM_VAL
    RET

RET_KEYS:
    RET

; ===================================================================
; TIMER ISR 
; ===================================================================
ISR_TIMER0:
    PUSH ACC
    PUSH PSW

    MOV TH0, #TH0_SET
    
    ; Buzzing Sound Generation
    JNB ALARM_ACTIVE, CHECK_RUNNING
    CPL BUZZER              

CHECK_RUNNING:
    JNB RUNNING, POP_EXIT   

    DJNZ TICKS, POP_EXIT    
    MOV TICKS, #20          

    ; --- TIME COUNTING ---
    INC SEC_ONES
    MOV A, SEC_ONES
    CJNE A, #10, CHECK_TRIGGER
    MOV SEC_ONES, #0
    
    INC SEC_TENS
    MOV A, SEC_TENS
    CJNE A, #6, CHECK_TRIGGER
    MOV SEC_TENS, #0

    INC MIN_ONES
    MOV A, MIN_ONES
    CJNE A, #10, CHECK_TRIGGER
    MOV MIN_ONES, #0

    INC MIN_TENS
    MOV A, MIN_TENS
    CJNE A, #6, CHECK_TRIGGER
    MOV MIN_TENS, #0

    INC HOUR_ONES
    MOV A, HOUR_ONES
    CJNE A, #10, POP_EXIT
    MOV HOUR_ONES, #0

    INC HOUR_TENS

CHECK_TRIGGER:
    ; Don't re-trigger if already buzzing
    JB ALARM_ACTIVE, POP_EXIT
    
    ; Compare Current Minutes (MIN_ONES) with User Setting (ALARM_VAL)
    MOV A, MIN_ONES
    CJNE A, ALARM_VAL, POP_EXIT
    
    ; Ensure strict match (XX:0N:00)
    MOV A, MIN_TENS
    JNZ POP_EXIT
    MOV A, SEC_TENS
    JNZ POP_EXIT
    MOV A, SEC_ONES
    JNZ POP_EXIT
    
    ; If Time == Alarm N -> Turn on Sound
    SETB ALARM_ACTIVE       
    
POP_EXIT:
    POP PSW
    POP ACC
    RETI

; ===================================================================
; HELPERS
; ===================================================================

MY_DELAY:
    MOV R7, #250
D_LOOP:
    DJNZ R7, D_LOOP
    DJNZ ACC, MY_DELAY 
    RET

GET_COD7:
    ANL A, #0FH             
    MOV DPTR, #COD_7SEG     
    MOVC A, @A+DPTR         
    RET

COD_7SEG:
    DB 03FH, 006H, 05BH, 04FH, 066H
    DB 06DH, 07DH, 007H, 07FH, 067H


STOP_HERE:
    SJMP STOP_HERE