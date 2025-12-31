; Example bootloader binary
; This is a placeholder file for demonstration purposes
; In a real bootloader, this would contain the actual boot code

; Boot sector code starts here
BITS 16
ORG 0x7C00

start:
    ; Clear screen
    mov ax, 0x0003
    int 0x10
    
    ; Print boot message
    mov si, msg
print_loop:
    lodsb
    or al, al
    jz load_kernel
    mov ah, 0x0E
    int 0x10
    jmp print_loop

load_kernel:
    ; Load kernel from disk
    ; This is where kernel loading code would go
    
    ; Infinite loop (halt)
    cli
    hlt
    jmp $

msg db 'NaoBootloader v1.0 - Loading...', 0x0D, 0x0A, 0

; Boot sector signature
times 510-($-$$) db 0
dw 0xAA55
