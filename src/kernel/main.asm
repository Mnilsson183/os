org 0x7C00
bits 16

;macro for a newline
%define ENDL 0x0D, 0x0A

start:
    jmp main
; This is a function to print a string to the screen
; put string
;Params
;ds:si input points to a string in memory
puts: 
                                        ; save the registers that will be changed
    push si                             ; Si is a register being source index meaning a pointer to 
                                        ; an array or string
    push ax                             ; ax is used for input/output and moth math instructions
.loop:
    lodsb                               ; lodsb, lodsw, lodsd these load a byte word or double word 
                                        ; from DS:SI into Al AX EAX then increments by the number of bytes
    or al, al                           ; loop exit condition verifies if the next char is null
                                        ; the or will return zero if null is encountered
    jz .done                            ; jump zero (if zero then jump)

    mov ah, 0x0E                        ; Requirment to print
    mov bh, 0                           ; page number
    int 0x10                            ; The interupt call to print
    jmp .loop                           ; to continue the loop
.done:
    pop ax                              ; I no longer need these registers
    pop si
    ret
main:
    mov ax, 0                           ; cannot write to ds/ ex directly
    mov ds, ax
    mov es, ax
                                        ; Init stack
    mov ss, ax                          ; ss is the first starting section of the stack
    mov sp, 0x7C00                      ; sp is the last location of the stack
                                        ; stack grows downward untill it hits adress 0x7C00
                                        ; Stack is first in first out memory 
                                        ; The zero here is the begaining of the os
    mov si, msg_hello                   ; putting the string hello into the si register
    call puts
    hlt
.halt:
    jmp .halt

msg_hello: db 'Hello World!', ENDL, 0   ; This is where the string is defined
times 510-($-$$) db 0
dw 0AA55H
