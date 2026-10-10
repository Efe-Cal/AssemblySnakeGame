dir_jumptable:
    .quad move_up        # 0
    .quad move_right     # 1
    .quad move_down      # 2
    .quad move_left      # 3

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

# RDI: did eat apple (0/1)
handle_movement:
    push    %rbp
    mov     %rsp, %rbp

    push    $0
    push    %rbx
    push    %r12
    push    %r13

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

    mov     $MAX_SNAKE, %r13    # r13 temporarily holds the array size 
    dec     %r13
    cmp     %r13, %r12
    je      wrap_head_case

    incq    head_index(%rip)
    jmp     normal_case

    wrap_head_case:
        movq  $0, head_index(%rip)         # move zero to head_index
        movq  $0, %r12                     # move zero to r12 to later write to the array
        jmp   normal_case


    normal_case:
    cmpq    $0, %rdi
    jne     skip_tail_inc 
    incq    tail_index(%rip)

    check_tail_wrap:
        cmp     %r13, tail_index(%rip)
        jne     skip_tail_inc

        movq    $0, tail_index(%rip)

    skip_tail_inc:

    movq    head_index, %r12 
    movb    %cl, (%rbx,%r12,2)      # put incemented x and y in mem 
    movb    %dl, 1(%rbx,%r12,2)     # .
    
    movement_skipped:

    pop    %r13
    pop    %r12
    pop    %rbx

    mov    %rbp, %rsp
    pop    %rbp
    
    ret
