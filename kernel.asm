; Example kernel binary
; This is a placeholder file for demonstration purposes

BITS 16

kernel_start:
    ; Set up video mode
    mov ax, 0x0003
    int 0x10
    
    ; Print kernel message
    mov si, kernel_msg
    call print_string
    
    ; Kernel main loop
kernel_loop:
    hlt
    jmp kernel_loop

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done:
    ret

kernel_msg db 'NaoKernel v1.0 - System Started', 0x0D, 0x0A, 0

times 1024 db 0
