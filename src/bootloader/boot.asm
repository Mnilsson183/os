org 0x7C00
bits 16

;macro for a newline
%define ENDL 0x0D, 0x0A

;
;   FAT12 header
;
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; entended boot record
ebr_drive_number:               db 0
                                db 0                    ; reserved
ebr_signature:                  db 29h         
ebr_volume_id:                  db 12h, 34h, 56h, 78h
ebr_volume_label:               db 'MNILSSON183'        ;any 11 byte string padded with spaces
ebr_system_id:                  db 'FAT12   '              ; 8 bytes padded

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
    push bx
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

    pop bx
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

    ;read here
    mov [ebr_drive_number], dl
    mov ax, 1                           ;LBA=1 second sector from disk
    mov cl, 1                           ; 1 sector to read
    mov bx, 0x7E00                      ;data after the bootloader
    call disk_read

    mov si, msg_hello                   ; putting the string hello into the si register
    call puts

    cli
    hlt
;
;   Error handeling 
;
floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                                 ;wait for keypress
    jmp 0FFFFh:0                            ;jmp to begaining of bios and reboot

.halt:
    cli                                     ;disable interupts
    hlt


;
;   Disk routine
;

;
;   Convert a LBA adress to a chs address
;   Params
;   - ax: LBA adress
;   returns
;   cx [bits 0-5]: sector
;   cx [bits 6-15]: cylinder
;   dh: head
lba_to_chs:

    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                        ; dx = LBA % SectorsPerTrack

    inc dx                              ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx                          ; cx = sector

    xor dx, dx                          ; dx = 0
    div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                        ; dx = (LBA / SectorsPerTrack) % Heads = head
    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                           ; put upper 2 bits of cylinder in CL

    pop ax
    mov dl, al                          ; restore DL
    pop ax
    ret
;
;   Read the sectors from a disk
;   Params:
;       ax: LBA address
;       cl: number of sectors to read(up to 128)
;       dl: drive num
;       es:bx memory adress to read from
disk_read:

    push ax                             ;save registers we will modify
    push bx
    push cx
    push dx
    push di



    push cx                             ;tmp save cx
    call lba_to_chs                     ;compute CHS
    pop ax                              ;AL = number of sectors to read
    
    mov ah, 02h
    mov di, 3                           ;Retry count

.retry:

    pusha                               ; save all registers save all
    stc                                 ;set carry flag
    int 13h                             ; if carry flag cleared = all good
    jnc .done

    ;read fail
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry
                                        
.fail:
    ;all the disk reads failed
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax                             ; restore registers modified
    ret
;
;   reset disk controller
;   Params
;   dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret


msg_hello:              db 'Hello world!', ENDL, 0
msg_read_failed:        db 'Read from disk failed!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55H
