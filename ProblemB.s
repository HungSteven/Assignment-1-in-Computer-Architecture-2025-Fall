.data
.align 2
msg_all_passed:   .string "All tests passed.\n"

# Strings for detailed error messages
err_msg_1_p1:     .string ": produces value "
err_msg_1_p2:     .string " but encodes back to "
err_msg_2_p1:     .string ": value "
err_msg_2_p2:     .string " <= previous_value "
newline:          .string "\n"

.text
.globl main

# main function: Entry point of the program.
main:
    addi sp, sp, -4
    sw   ra, 0(sp)
    
    call test
    
    lw   ra, 0(sp)
    addi sp, sp, 4

    li   t0, 1
    beq  a0, t0, tests_passed

tests_failed:
    li   a0, 1
    li   a7, 93
    ecall

tests_passed:
    la   a0, msg_all_passed
    li   a7, 4
    ecall
    li   a0, 0
    li   a7, 93
    ecall

#----------------------------------------------------
# test()
# Implements the full test logic from the original C code.
# @return a0: 1 if all tests passed, 0 otherwise
#----------------------------------------------------
test:
    addi sp, sp, -24
    sw   ra, 20(sp)
    sw   s0, 16(sp)
    sw   s1, 12(sp)
    sw   s2, 8(sp)
    sw   s3, 4(sp)
    sw   s4, 0(sp)

    li   s0, 0
    li   s1, -1
    li   s4, 1

test_loop:
    li   t0, 256
    bge  s0, t0, test_loop_end

    mv   a0, s0
    call uf8_decode
    mv   s2, a0

    mv   a0, s2
    call uf8_encode
    mv   s3, a0

    beq  s0, s3, check_monotonic
    
    li   s4, 0
    mv   a0, s0
    li   a7, 1
    ecall
    la   a0, err_msg_1_p1
    li   a7, 4
    ecall
    mv   a0, s2
    li   a7, 1
    ecall
    la   a0, err_msg_1_p2
    li   a7, 4
    ecall
    mv   a0, s3
    li   a7, 1
    ecall
    la   a0, newline
    li   a7, 4
    ecall
    
check_monotonic:
    bgt  s2, s1, update_and_continue

    li   s4, 0
    mv   a0, s0
    li   a7, 1
    ecall
    la   a0, err_msg_2_p1
    li   a7, 4
    ecall
    mv   a0, s2
    li   a7, 1
    ecall
    la   a0, err_msg_2_p2
    li   a7, 4
    ecall
    mv   a0, s1
    li   a7, 1
    ecall
    la   a0, newline
    li   a7, 4
    ecall

update_and_continue:
    mv   s1, s2
    addi s0, s0, 1
    j    test_loop

test_loop_end:
    mv a0, s4

    lw   ra, 20(sp)
    lw   s0, 16(sp)
    lw   s1, 12(sp)
    lw   s2, 8(sp)
    lw   s3, 4(sp)
    lw   s4, 0(sp)
    addi sp, sp, 24
    ret

#----------------------------------------------------
# Core Functions (clz, uf8_decode, uf8_encode)
#----------------------------------------------------
clz:
    mv   t0, a0
    li   t1, 32
    li   t2, 16
clz_loop_start:
    beq  t2, zero, clz_end_loop
    srl  t3, t0, t2
    beq  t3, zero, clz_no_shift
    sub  t1, t1, t2
    mv   t0, t3
clz_no_shift:
    srli t2, t2, 1
    j    clz_loop_start
clz_end_loop:
    sub  a0, t1, t0
    ret

uf8_decode:
    andi t0, a0, 0x0f
    srli t1, a0, 4
    li   t2, 15
    sub  t2, t2, t1
    li   t3, 0x7FFF
    srl  t3, t3, t2
    slli t3, t3, 4
    sll  t0, t0, t1
    add  a0, t0, t3
    ret

uf8_encode:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    mv   s0, a0
    li   t0, 16
    blt  s0, t0, encode_ret_value
    call clz
    li   t1, 31
    sub  t1, t1, a0
    li   t2, 0
    li   t3, 0
    li   t0, 5
    blt  t1, t0, find_exact_exponent_entry
    addi t2, t1, -4
    li   t0, 15
    ble  t2, t0, exponent_ok
    li   t2, 15
exponent_ok:
    li   t4, 0
for_loop_overflow:
    bge  t4, t2, adjust_estimate
    slli t3, t3, 1
    addi t3, t3, 16
    addi t4, t4, 1
    j    for_loop_overflow
adjust_estimate:
    blez t2, find_exact_exponent_entry
    bge  s0, t3, find_exact_exponent_entry
    srli t3, t3, 1
    addi t3, t3, -8
    addi t2, t2, -1
    j    adjust_estimate
find_exact_exponent_entry:
    li   t0, 15
    bge  t2, t0, calc_mantissa
    slli t1, t3, 1
    addi t1, t1, 16
    blt  s0, t1, calc_mantissa
    mv   t3, t1
    addi t2, t2, 1
    j    find_exact_exponent_entry
calc_mantissa:
    sub  t0, s0, t3
    srl  t0, t0, t2
    slli a0, t2, 4
    or   a0, a0, t0
    j    encode_cleanup
encode_ret_value:
    mv   a0, s0
encode_cleanup:
    lw   ra, 4(sp)
    lw   s0, 0(sp)
    addi sp, sp, 8
    ret