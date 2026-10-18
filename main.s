.data
clear_screen: .asciz "\033[2J\033[H"

game_over_message: .asciz "Game Over\nYour Score: %d\n\n\n"

old_termios: .zero 64
current_termios: .zero 64
old_flags: .quad 0

.equ MAX_SNAKE, 400
.equ SIZE, 20


.bss
snake: .skip MAX_SNAKE * 2
apple: .skip 2

head_index: .quad 0
tail_index: .quad 0
direction: .byte 0

key: .byte 0
quit_requested: .byte 0

.text

.extern tcgetattr
.extern tcsetattr
.extern fcntl

.include "handle_movement.s"
.include "handle_terminal.s"
.include "render.s"


pressed_up:
    cmpb     $2, direction
    je      continue_game_loop
    
    movb    $0, direction(%rip)
    jmp continue_game_loop
pressed_right:
    cmpb     $3, direction
    je      continue_game_loop

    movb    $1, direction(%rip)
    jmp continue_game_loop
pressed_down:
    cmpb     $0, direction
    je      continue_game_loop

    movb    $2, direction(%rip)
    jmp continue_game_loop
pressed_left:
    cmpb     $1, direction
    je      continue_game_loop

    movb    $3, direction(%rip)
    jmp continue_game_loop

.globl main
main:

    pushq    %rbp
    movq     %rsp, %rbp

    push    $0
    push    %rbx
    push    %r12   
    push    %r13

    mov     $0, %r13   

    call setup_terminal

    # Register Ctrl+C handler
    mov $2, %edi                    # SIGINT
    lea sigint_handler(%rip), %rsi
    call signal@PLT

    mov $clear_screen, %rdi
    mov $0, %rax
    call printf

    xor %edi, %edi
    call fflush

    call draw_frame

    # setup random from time seed
    mov     $0, %rdi
    call    time
    mov     %rax, %rdi
    call    srand

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

    # apple
    movb $15, apple(%rip)
    movb $5,  apple+1(%rip)

    movq $0, tail_index(%rip)
    movq $2, head_index(%rip)

    movb $1, direction(%rip)

    game_loop:
        cmpb    $1, quit_requested
        je      game_over

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

        leaq    snake(%rip), %rbx
        # get current head 
        mov     head_index(%rip), %r12
        movb    (%rbx,%r12,2), %cl       # x
        movb    1(%rbx,%r12,2), %dl      # y

        movq    $0, %rdi

        cmpb    %cl, apple(%rip)
        jne     no_apple_eaten

        cmpb    %dl, apple+1(%rip)
        jne     no_apple_eaten

        # movq    $1, %rdi
        inc     %r13

        call    relocate_apple

        no_apple_eaten:
        call    handle_movement
        cmp     $1, %rax
        je      game_over
        call    render_screen

        mov $100000, %rdi
        call usleep

        jmp game_loop

    game_over:

    mov     $clear_screen, %rdi
    mov     $0, %rax
    call    printf

    mov     $game_over_message, %rdi
    mov     %r13, %rsi
    mov     $0, %rax
    call    printf
    

    call restore_terminal

    pop     %r13
    pop     %r12
    pop     %rbx

    movq    %rbp, %rsp
    popq    %rbp

    mov     $0, %rax
    ret

relocate_apple:
    push    %rbx

    movq    $SIZE, %rbx

    call    rand
    divq    %rbx, %rax          # apple = rand_num % SIZE 
    inc     %dl                 # rdx holds the remainder, inc to get value between 1-20
    movb    %dl, apple(%rip)

    call    rand
    xorq    %rdx, %rdx
    divq    %rbx, %rax
    inc     %dl
    movb    %dl, apple+1(%rip)
    
    pop     %rbx
    ret


sigint_handler:
    movl $1, quit_requested(%rip)
    ret
