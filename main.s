.data
clear_screen: .asciz "\033[2J\033[H"
print_snake_segment: .asciz "\33[%u;%uH@"


.text

.globl main
main:

    pushq    %rbp
    movq     %rsp, %rbp


    pushq   $1
    mov $4, %rsi
    shl $32, %rsi
    orq $4, %rsi
    push %rsi

    movq    $60, %rbx       # put the starting x position to the register 
    shlq    $32, %rbx       # move 32 bits to the left
    orq     $20, %rbx       # OR the y position value with rbx, store it at the lower 32bits


    leaq    16(%rbp), %rsi
    mov     $1, %rdi
    call    render_screen

    movq     %rbp, %rsp
    popq     %rbp

    mov $0, %rdi
    call exit

# RDI: length of snake
# RSI: mem addr of the start
# RDX: apple location
render_screen:
    pushq    %rbp
    movq     %rsp, %rbp

    mov     %rdi, %r14
    mov     %rsi, %rbx
    mov     $0, %r12


    mov $clear_screen, %rdi
    mov $0, %rax
    call printf

    render_snake_loop:
        mov     (%rbx, %r12, 8), %r9

        mov     %r9d, %r10d
        shr     $32, %r9

        mov $print_snake_segment, %rdi
        mov %r9, %rsi
        mov %r10, %rdx
        mov $0, %rax
        call printf

        inc %r12
        cmp %r12, %r14
        jg render_snake_loop

    movq     %rbp, %rsp
    popq     %rbp
    ret