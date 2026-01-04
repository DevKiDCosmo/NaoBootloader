; Stage 2 Bootloader - Extended Loader
; This is loaded by stage 1 at 0x7E00 and loads the kernel

BITS 16
ORG 0x7E00

stage2_start:
    ; Set up segments
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00      ; Stack below bootloader
    sti
    
    ; Save boot drive (passed from Stage 1 in DL)
    mov [boot_drive], dl
    
    ; Print stage 2 active message in bright green
    mov si, stage2_active_msg
    mov bl, 0x0A        ; Bright green
    call print_string_color
    
    ; Debug: Starting kernel load in yellow
    mov si, loading_kernel_msg
    mov bl, 0x0E        ; Yellow
    call print_string_color
    
    ; Load kernel from disk (starting at sector 5)
    ; BIOS sectors: 1=boot, 3-4=stage2, 5+=kernel
    mov ah, 0x02        ; BIOS read sector
    mov al, 80          ; Read 80 sectors (40KB) to allow larger payloads
    mov ch, 0           ; Cylinder 0
    mov cl, 5           ; Start at sector 5 (dd seek=4 writes to sector 5 in BIOS)
    mov dh, 0           ; Head 0
    mov dl, [boot_drive]; Use the boot drive from Stage 1
    mov bx, 0x1000      ; Load kernel to segment 0x1000
    mov es, bx
    xor bx, bx          ; Offset 0 (0x1000:0x0000 = 0x10000)
    int 0x13
    jc disk_error
    
    ; Print kernel loaded message in bright cyan
    mov si, kernel_loaded_msg
    mov bl, 0x0B        ; Bright cyan
    call print_string_color
    
    ; Debug: Setting up kernel environment in yellow
    mov si, setup_env_msg
    mov bl, 0x0E        ; Yellow
    call print_string_color
    
    ; Debug: Jumping to kernel in bright white
    mov si, jumping_kernel_msg
    mov bl, 0x0F        ; Bright white
    call print_string_color
    
    ; Set up environment for kernel
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00      ; Stack below bootloader
    sti
    
    ; Jump to kernel entry point
    jmp 0x1000:0x0000

disk_error:
    mov si, disk_error_msg
    mov bl, 0x0C        ; Bright red
    call print_string_color
    jmp halt

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

halt:
    cli
    hlt
    jmp halt

stage2_active_msg db '[DEBUG] Stage 2: Loader Active', 0x0D, 0x0A, 0
loading_kernel_msg db '[DEBUG] Stage 2: Loading Kernel...', 0x0D, 0x0A, 0
kernel_loaded_msg db '[DEBUG] Stage 2: Kernel OK', 0x0D, 0x0A, 0
setup_env_msg db '[DEBUG] Stage 2: Setup Environment', 0x0D, 0x0A, 0
jumping_kernel_msg db '[DEBUG] Stage 2: Jump -> Kernel', 0x0D, 0x0A, 0x0D, 0x0A, 0
disk_error_msg db '[ERROR] Stage 2: Kernel Failed!', 0x0D, 0x0A, 0

; Boot drive variable
boot_drive db 0

; Pad to 1KB (2 sectors)
times 1024-($-$$) db 0
