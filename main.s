.data
clear_screen: .asciz "\033[2J\033[H"
print_snake_segment: .asciz "\33[%u;%uH@"

old_termios: .zero 64
current_termios: .zero 64
old_flags: .quad 0

.equ MAX_SNAKE, 400
.equ SIZE, 20


.bss
snake: .skip MAX_SNAKE * 2

head_index: .quad 0
tail_index: .quad 0
direction: .byte 0

key: .byte 0

.text

.extern tcgetattr
.extern tcsetattr
.extern fcntl

dir_jumptable:
    .quad move_up        # 0
    .quad move_right     # 1
    .quad move_down      # 2
    .quad move_left      # 3

# TODO: implement array wrap back to 0th index when reached the end

move_up:
    cmpb    $1, %dl
    jle     at_edge

    mov     $1, %rax
    dec     %dl             # decrement y to go up (top left is 0)
    ret
move_down:
    cmpb    $SIZE, %dl
    jge     at_edge

    mov     $1, %rax
    inc     %dl             # increment y to go down (top left is 0)
    ret
move_right:

    # make sure not at edge
    cmpb    $SIZE, %cl
    jge     at_edge
    
    mov     $1, %rax
    inc     %cl     # cl holds the x value, we increment that
    ret    
move_left:
    # make sure not at edge
    cmpb    $1, %cl
    jle     at_edge

    mov     $1, %rax
    dec     %cl
    ret

at_edge:
    ret

handle_movement:

    leaq    snake(%rip), %rbx
    # get current head 
    mov     head_index(%rip), %r12
    movb    (%rbx,%r12,2), %cl       # x
    movb    1(%rbx,%r12,2), %dl      # y

    movzbq  direction(%rip), %rax
    shlq    $3, %rax
    movq    dir_jumptable(%rax), %rax
    call    *%rax

    cmp     $1, %rax
    jne     movement_skipped

    incq     head_index(%rip)
    incq     tail_index(%rip)

    inc     %r12    # inc r12 which we will use to update the head index 
    movb    %cl, (%rbx,%r12,2)      # put incemented x and y in mem 
    movb    %dl, 1(%rbx,%r12,2)     # .
    
    movement_skipped:
    ret

setup_terminal:
    
    pushq    %rbp
    movq     %rsp, %rbp

    # tcgetattr to get the old termios settings
    movq    $0, %rdi                    # stdin file descriptor
    leaq    old_termios(%rip), %rsi
    call    tcgetattr


    movq    $0, %rdi                    # stdin file descriptor
    leaq    current_termios(%rip), %rsi
    call    tcgetattr

    # Setting ICANON (2) and ECHO (8) flag bits to 0 and keep the rest same
    andl     $~10, current_termios+12(%rip)

    mov     $0, %rdi
    mov     $0, %rsi
    leaq    current_termios(%rip), %rdx
    call    tcsetattr

    # Get current file control flags
    movq $0, %rdi                    # stdin
    movq $3, %rsi                    # 3:  F_GETFL
    call fcntl

    movq %rax, old_flags(%rip)

    movq %rax, %rdx
    orq $2048, %rdx                 # Add the non blocking flag (value 2048) to the flags we got

    # set file control flags
    movq $0, %rdi
    movq $4, %rsi                    # 4: F_SETFL
    call fcntl

    movq     %rbp, %rsp
    popq     %rbp

    ret

restore_terminal:
    
    pushq    %rbp
    movq     %rsp, %rbp

    mov     $0, %rdi
    mov     $0, %rsi
    mov     old_termios(%rip), %rdx
    call    tcsetattr
    
    movq $0, %rdi
    movq $4, %rsi                    # F_SETFL
    movq old_flags(%rip), %rdx
    call fcntl

    movq     %rbp, %rsp
    popq     %rbp

    ret


read_key:
    movq    $0, %rax            # sys_read
    movq    $0, %rdi            # stdin
    leaq    key(%rip), %rsi     # write location
    movq    $1, %rdx            # read 1 byte
    syscall

    # rax == 1 means a key was read
    cmpq $1, %rax
    jne no_key

    movzbl key(%rip), %eax
    ret
    
    no_key:
        mov     $0, %rax
        ret


pressed_up:     
    movb    $0, direction(%rip)
    jmp continue_game_loop
pressed_right:  
    movb    $1, direction(%rip)
    jmp continue_game_loop
pressed_down:   
    movb    $2, direction(%rip)
    jmp continue_game_loop
pressed_left:   
    movb    $3, direction(%rip)
    jmp continue_game_loop

.globl main
main:

    pushq    %rbp
    movq     %rsp, %rbp

    call setup_terminal

    leaq snake(%rip), %rbx
    # segment 0 = (5,5)
    movb $5, (%rbx)      # x
    movb $5, 1(%rbx)      # y

    # segment 1 = (6,5)
    movb $6, 2(%rbx)      # x
    movb $5, 3(%rbx)      # y

    # segment 2 = (7,5)
    movb $7, 4(%rbx)      # x
    movb $5, 5(%rbx)      # y

    movq $0, tail_index(%rip)
    movq $2, head_index(%rip)

    movb $2, direction(%rip)

    game_loop:
        call    read_key

        cmpb $'w', %al
        je pressed_up

        cmpb $'a', %al
        je pressed_left

        cmpb $'s', %al
        je pressed_down

        cmpb $'d', %al
        je pressed_right

        continue_game_loop:
        call    handle_movement
        call    render_screen

        mov $500000, %rdi
        call usleep

        jmp game_loop

    call restore_terminal

    movq     %rbp, %rsp
    popq     %rbp

    mov $0, %rdi
    call exit

render_screen:
    pushq    %rbp
    movq     %rsp, %rbp

    mov     tail_index(%rip), %r12

    mov $clear_screen, %rdi
    mov $0, %rax
    call printf

    leaq    snake(%rip), %rbx
    render_snake_loop:

        movb    (%rbx,%r12,2), %cl       # x
        movb    1(%rbx,%r12,2), %dl      # y

        mov $print_snake_segment, %rdi
        movzbq %dl, %rsi
        movzbq %cl, %rdx
        mov $0, %rax
        call printf

        mov $0, %rdi       # NULL = flush all output streams
        call fflush

        inc %r12
        cmp %r12, head_index(%rip)
        jge render_snake_loop

    movq     %rbp, %rsp
    popq     %rbp
    ret
