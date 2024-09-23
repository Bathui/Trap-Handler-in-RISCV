##
# Copyright (c) 1990-2023 James R. Larus.
# Copyright (c) 2023 LupLab.
#
# SPDX-License-Identifier: AGPL-3.0-only
##

# This a modified version of the default system code for VRV.
# What is VRV: https://gitlab.com/luplab/vrv/vrv

# It contains three parts:

# 1. The machine boot code, starting from global label
#    `__mstart`. This boot code sets up the trap vector, and jumps to
#    label `__user_bootstrap` in user mode.

# 2. The trap handler, which is called upon an exception (interrupts
#    are not enabled by default).
	
# 3. The small user bootstrap code, starting from global label
#    `__user_bootstrap`. This bootstrap code calls `main`, which is expected to
#     be defined by the user program. If main returns, the bootstrap code exits
#     with the value returned by main.

# Following is what trap handler does:

# a) Save all registers

# b) Examine the cause to determine if it is a misaligned load word.

# c) If it IS a misaligned load word, it should patch up the
# result and resume execution at the next instruction.

# d) Otherwise, it should jump to the terminate operation
# which is the default printing routine from VRV's default
# system file.

	## Constants
.equ    PRINT_DEC  0
.equ    PRINT_HEX   1
.equ    PRINT_CHR   3
.equ    PRINT_STR   4
.equ    EXIT        20

.equ    NEWLN_CHR   '\n'
.equ    SPACE_CHR   ' '

.equ 	KSTACK_SIZE 4096
	
# YOU can add more constants here, and you probably will want to!

## System data
    .kdata
__m_exc:    .string "  Exception"
__m_int:    .string "  Interrupt"

__m_mcause: .string "\n    MCAUSE: "
__m_mepc:   .string "\n    MEPC:   "
__m_mtval:  .string "\n    MTVAL:  "

__e0:   .string " [Misaligned instruction address]"
__e1:   .string " [Instruction access fault]"
__e2:   .string " [Illegal instruction]"
__e3:   .string " [Breakpoint]"
__e4:   .string " [Misaligned load address]"
__e5:   .string " [Load access fault]"
__e6:   .string " [Misaligned store address]"
__e7:   .string " [Store access fault]"
__e8:   .string " [User-mode ecall]"
__e11:  .string " [Machine-mode ecall]"

__i3:   .string " [Software]"
__i7:   .string " [Timer]"
__i11:  .string " [External]"

__evec: .word __e0, __e1, __e2, __e3, __e4, __e5, __e6, __e7, __e8, 0, 0, __e11
__ivec: .word 0, 0, 0, __i3, 0, 0, 0, __i7, 0, 0, 0, __i11

	.align 2

	# A small stack for kernel data
kstack:  .zero   KSTACK_SIZE

## System code
    .ktext
### Boot code
    .globl __mstart
__mstart:
    la      t0, __mtrap
    csrw    mtvec, t0

	la      t0, __user_bootstrap
	csrw    mepc, t0

	# Allocates space so the trap handler has a
	# small stack and can therefore call functions 
	# itself.
	la 	t0, kstack
	li	t1, KSTACK_SIZE
	add 	t0 t0 t1
	csrw   	mscratch, t0
	mret    # Enter user bootstrap
 
### Trap handler
### You will need to write your own trap handler functionality here.
__mtrap:
    csrrw sp mscratch sp 
    sw x1 4(sp)
    sw x3 12(sp)
    sw x4 16(sp)
    sw x5 20(sp)
    sw x6 24(sp)
    sw x7 28(sp)
    sw x8 32(sp)
    sw x9 36(sp)
    sw x10 40(sp)
    sw x11 44(sp)
    sw x12 48(sp)
    sw x13 52(sp)
    sw x14 56(sp)
    sw x15 60(sp)
    sw x16 64(sp)
    sw x17 68(sp)
    sw x18 72(sp)
    sw x19 76(sp)
    sw x20 80(sp)
    sw x21 84(sp)
    sw x22 88(sp)
    sw x23 92(sp)
    sw x24 96(sp)
    sw x25 100(sp)
    sw x26 104(sp)
    sw x27 108(sp)
    sw x28 112(sp)
    sw x29 116(sp)
    sw x30 120(sp)
    sw x31 124(sp)
    csrr t0 mepc    # store the pc of the incorrect instruction to t0
    csrr t1 mtval   # store the address where the fault happened in t1
    srli t3 t0 2
    srli t4 t1 2

    beq t3 t4 terminate
    
    li t1 4
    lw t3 0(t0)
    csrr t0 mcause
    beq t0 t1 misaligned_load
	j terminate

misaligned_load:

    csrr t0 mepc    # store the pc of the incorrect instruction to t0
    csrr t1 mtval   # store the address where the fault happened in t1
    lw t3 0(t0)
    li t2 0x7F 
    and t3 t3 t2   # get the opcode
    li t2 3
    bne t3 t2 terminate

    lw t3 0(t0)
    li t2 3
    srli t3 t3 12 
    and t3 t3 t2   # get func_3
    li t2 2
    beq t3 t2 else
    j terminate

else:
    lbu t3 3(t1)   # read from the first element 
    lbu t4 2(t1)   # read from the second element
    lbu t5 1(t1)   # read from the third element
    lbu t6 0(t1)   # read from the fourth element

    slli t3 t3 24
    slli t4 t4 16
    or t3 t3 t4   # combine t3 and t4
    slli t5 t5 8
    or t3 t3 t5   # combine t3, t4 and t5 
    or t3 t3 t6
    
    lw t2 0(t0)

    mv t6 sp
    andi t2 t2 0x0f80
    slli t2 t2 20
    srli t2 t2 20
    srli t2 t2 7
    slli t2 t2 2
    add sp sp t2
    addi t0 t0 4
    csrw mepc t0
    sw t3 0(sp)
    lw x1 4(t6)
    lw x3 12(t6)
    lw x4 16(t6)
    lw x5 20(t6)
    lw x6 24(t6)
    lw x7 28(t6)
    lw x8 32(t6)
    lw x9 36(t6)
    lw x10 40(t6)
    lw x11 44(t6)
    lw x12 48(t6)
    lw x13 52(t6)
    lw x14 56(t6)
    lw x15 60(t6)
    lw x16 64(t6)
    lw x17 68(t6)
    lw x18 72(t6)
    lw x19 76(t6)
    lw x20 80(t6)
    lw x21 84(t6)
    lw x22 88(t6)
    lw x23 92(t6)
    lw x24 96(t6)
    lw x25 100(t6)
    lw x26 104(t6)
    lw x27 108(t6)
    lw x29 116(t6)
    lw x30 120(t6)
    lw x28 112(t6)
    lw x31 124(t6)
    csrrw sp mscratch sp 
    mret

# This code is taken from the default VRV system code.  It prints out
# a message indicating the cause of an unhandled exception.  We are
# keeping this in this form to make it easier for you to debug.

# It is allowed to trash registers (unlike the normal trap handler)
# because it never returns	
terminate:
    csrr    t0, mcause      # Get mcause CSR
    li      t1, 0x80000000
    and     t1, t0, t1      # mcause & 0x80000000
    beqz    t1, ____not_interrupt   # mcause has bit 31 set for an interrupt

    # 2a. Interrupt
    la      a0, __m_int     # Interrupt header message
    xor     t0, t0, t1      # Isolate interrupt code
    la      t1, __ivec      # Interrupt vector
    j       ____print_trap_message

    # 2b. Exception
____not_interrupt:
    la      a0, __m_exc     # Exception header message
    la      t1, __evec      # Isolate exception code

    # 3. Print header message
____print_trap_message:
    li      a7, PRINT_STR
    ecall

    # 4. Print vector entry for this exception/interrupt
    slli    a0, t0, 2       # mcause * 4
    add     a0, t1, a0      # Index in vector
    lw      a0, (a0)        # Entry from vector
    ecall

    # 5. Print mcause
    la      a0, __m_mcause
    ecall
    csrr    a0, mcause
    li      a7, PRINT_HEX
    ecall

    # 6. Print mepc
    la      a0, __m_mepc
    li      a7, PRINT_STR
    ecall
    csrr    a0, mepc
    li      a7, PRINT_HEX
    ecall

    # 7. Print mtval
    la      a0, __m_mtval
    li      a7, PRINT_STR
    ecall
    csrr    a0, mtval
    li      a7, PRINT_HEX
    ecall
    li      a0, NEWLN_CHR
    li      a7, PRINT_CHR
    ecall

    # Exit with code -1
    li      a0, -1
    li      a7, EXIT
    ecall



## User boot code
    .text
__user_bootstrap:
    # exit(main())
    jal     main
    li      a7, EXIT
    ecall

# Useful utility function
kprintstr:
	li a7, PRINT_STR
	ecall
	ret