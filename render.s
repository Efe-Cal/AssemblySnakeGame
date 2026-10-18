.data

print_snake_segment: .asciz "\33[%u;%uH@"
print_apple: .asciz "\33[%u;%uHA"
snake_head_chars:
    .asciz "\33[%u;%uH^"
    .asciz "\33[%u;%uH>"
    .asciz "\33[%u;%uHv"
    .asciz "\33[%u;%uH<"
clear_char: .asciz "\33[%u;%uH "

frame:
    .ascii "+--------------------+\n"
    .rept 20
        .ascii "|                    |\n"
    .endr
    .ascii "+--------------------+\n"

frame_end:
.equ FRAME_LEN, frame_end - frame

.text

.globl render_screen
render_screen:
    pushq    %rbp
    movq     %rsp, %rbp

    push    %rbx
    push    %r12
    push    %r13
    push    %r14

    mov     tail_index(%rip), %r12

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

.globl draw_frame
draw_frame:
    movq $1, %rax           # SYS_write
    movq $1, %rdi           # stdout
    leaq frame(%rip), %rsi  # buffer
    movq $FRAME_LEN, %rdx   # bytes
    syscall
    ret

.global clear_position
clear_position:
    push %rbp
    mov %rsp, %rbp

    movzbq    %dil, %rdx    # column = x
    movzbq    %sil, %rsi    # row = y
    mov     $clear_char, %rdi
    xorq    %rax, %rax
    call    printf

    leave
    ret
