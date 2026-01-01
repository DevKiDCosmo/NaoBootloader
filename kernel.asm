; NaoKernel - Simple 16-bit Kernel

BITS 16
ORG 0x0000

kernel_start:
    ; Set up segments for kernel
    mov ax, 0x1000
    mov ds, ax
    mov es, ax
    
    ; Clear screen
    mov ax, 0x0003
    int 0x10
    
    ; Print kernel banner in bright green
    mov si, kernel_banner
    mov bl, 0x0A        ; Bright green
    call print_string_color
    
    ; Print kernel message in bright white
    mov si, kernel_msg
    mov bl, 0x0F        ; Bright white
    call print_string_color
    
    ; Print separator in cyan
    mov si, kernel_separator
    mov bl, 0x0B        ; Bright cyan
    call print_string_color
    
    ; Simple shell prompt
    call shell_loop
    
shell_loop:
    ; Print prompt
    mov si, prompt_msg
    call print_string
    
    ; Wait for key
    xor ah, ah
    int 0x16
    
    ; Echo character
    mov ah, 0x0E
    int 0x10
    
    ; New line
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    
    jmp shell_loop

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp print_string
.done:
    ret

print_string_color:
    ; Print string with color
    ; BL = color attribute
    lodsb
    or al, al
    jz .done
    
    ; Check for special characters
    cmp al, 0x0D        ; Carriage return
    je .carriage_return
    cmp al, 0x0A        ; Line feed
    je .line_feed
    
    ; Normal character
    mov ah, 0x09        ; Write character with attribute
    mov cx, 1           ; Write 1 character
    int 0x10
    
    ; Move cursor forward
    mov ah, 0x03        ; Get cursor position
    mov bh, 0           ; Page 0
    int 0x10
    inc dl              ; Move cursor right
    mov ah, 0x02        ; Set cursor position
    int 0x10
    jmp print_string_color

.carriage_return:
    mov ah, 0x03        ; Get cursor position
    mov bh, 0
    int 0x10
    mov dl, 0           ; Move to column 0
    mov ah, 0x02        ; Set cursor position
    int 0x10
    jmp print_string_color

.line_feed:
    mov ah, 0x03        ; Get cursor position
    mov bh, 0
    int 0x10
    inc dh              ; Move down one line
    mov ah, 0x02        ; Set cursor position
    int 0x10
    jmp print_string_color

.done:
    ret

kernel_banner db '[DEBUG] Mini Kernel Stage 3: Init Complete', 0x0D, 0x0A, 0
kernel_msg db '========================================', 0x0D, 0x0A
           db '   NaoKernel v1.0 - System Started   ', 0x0D, 0x0A
           db '========================================', 0x0D, 0x0A, 0
kernel_separator db 0x0D, 0x0A, 0
prompt_msg db '> ', 0

times 1024 db 0
