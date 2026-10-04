.data
clear_screen: .asciz "\033[2J\033[H"
print_snake_segment: .asciz "\33[%u;%uH@"

.equ MAX_SNAKE, 400
.equ SIZE, 20


.bss
snake: .skip MAX_SNAKE * 2

head_index: .quad 0
tail_index: .quad 0
direction: .byte 0

.text

dir_jumptable:
    .quad up        # 0
    .quad right     # 1
    .quad down      # 2
    .quad left      # 3

# TODO: implement array wrap back to 0th index when reached the end
up:

    leaq    snake(%rip), %rbx
    # get current head 
    mov     head_index(%rip), %r12
    movb    (%rbx,%r12,2), %cl       # x
    movb    1(%rbx,%r12,2), %dl      # y

    cmpb    $0, %dl
    jle     at_edge
    
    incq     head_index(%rip)
    incq     tail_index(%rip)

    dec     %dl             # decrement y to go up (top left is 0)
    inc     %r12
    
    movb    %cl, (%rbx,%r12,2)      # put incemented x and y in mem 
    movb    %dl, 1(%rbx,%r12,2) 

    ret
down:
    ret
right:
    leaq    snake(%rip), %rbx
    # get current head 
    mov     head_index(%rip), %r12
    movb    (%rbx,%r12,2), %cl       # x
    movb    1(%rbx,%r12,2), %dl      # y

    # make sure not at edge
    cmpb    $SIZE, %cl
    jge     at_edge
    
    # move the head and tail one unit to the right
    incq     head_index(%rip)
    incq     tail_index(%rip)
    
    inc     %r12    # inc r12 which we will use to update the head index 
    inc     %cl     # cl holds the x value, we increment that
    
    movb    %cl, (%rbx,%r12,2)      # put incemented x and y in mem 
    movb    %dl, 1(%rbx,%r12,2)     # .
    ret    
left:
    leaq snake(%rip), %rbx

    # get current tail 
    mov     tail_index(%rip), %r12
    movb    (%rbx,%r12,2), %cl       # x
    movb    1(%rbx,%r12,2), %dl      # y

    # make sure not at edge
    cmpb    $0, %cl
    jle     at_edge
    
    # move the head and tail one unit to the left
    decq     head_index(%rip)
    decq     tail_index(%rip)

    dec     %r12
    dec     %cl 
    
    movb    %cl, (%rbx,%r12,2) 
    movb    %dl, 1(%rbx,%r12,2)
    ret

at_edge:
    ret

.globl main
main:

    pushq    %rbp
    movq     %rsp, %rbp

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

    movb $0, direction(%rip)

    game_loop:
        call    render_screen

        movzbq  direction(%rip), %rax
        shlq     $3, %rax
        movq    dir_jumptable(%rax), %rax
        call    *%rax

        mov $500000, %rdi
        call usleep

        jmp game_loop

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
