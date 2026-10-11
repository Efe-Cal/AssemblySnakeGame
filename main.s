.data
clear_screen: .asciz "\033[2J\033[H"
print_snake_segment: .asciz "\33[%u;%uH@"
print_apple: .asciz "\33[%u;%uHA"
snake_head_chars:
    .asciz "\33[%u;%uH^"
    .asciz "\33[%u;%uH>"
    .asciz "\33[%u;%uHv"
    .asciz "\33[%u;%uH<"

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

.text

.extern tcgetattr
.extern tcsetattr
.extern fcntl

.include "handle_movement.s"
.include "handle_terminal.s"


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

    push    $0
    push    %rbx
    push    %r12   
    push    %r13

    mov     $0, %r13   

    call setup_terminal

    # setup random from time seed
    call time
    mov %rax, %rdi
    call srand

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


render_screen:
    pushq    %rbp
    movq     %rsp, %rbp

    push    %rbx
    push    %r12
    push    %r13
    push    %r14

    mov     tail_index(%rip), %r12

    mov $clear_screen, %rdi
    mov $0, %rax
    call printf

    # Render apple
    leaq    apple(%rip), %rbx
    movb    (%rbx), %cl       # x
    movb    1(%rbx), %dl      # y
    
    mov $print_apple, %rdi
    movzbq %dl, %rsi
    movzbq %cl, %rdx
    mov $0, %rax
    call printf

    leaq    snake(%rip), %rbx
    render_snake_loop:

        movb    (%rbx,%r12,2), %cl       # x
        movb    1(%rbx,%r12,2), %dl      # y

        mov $print_snake_segment, %rdi

        cmp      %r12, head_index(%rip)
        jne      not_head

        movzbq  direction, %rax
        imulq   $10, %rax
        add     $snake_head_chars, %rax
        mov     %rax, %rdi

        not_head:
        movzbq %dl, %rsi
        movzbq %cl, %rdx
        mov $0, %rax
        call printf

        # Stop after drawing the head
        cmp     %r12, head_index(%rip)
        je      render_snake_done

        inc %r12

        mov     $MAX_SNAKE, %r14    # r14 holds the array size 
        cmp     %r14, %r12
        mov     $0, %r13
        cmove   %r13, %r12      # move zero to r12

        jmp     render_snake_loop

    render_snake_done:
    # flush the stdin buffer 
    mov $0, %rdi       # NULL = flush all output streams
    call fflush
    
    pop     %r14
    pop     %r13
    pop     %r12
    pop     %rbx

    movq    %rbp, %rsp
    popq    %rbp
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
