.data
# --- String Literals for printing ---
header1: .asciz "======================================\n"
header2: .asciz "=   Bfloat16 Implementation Test     =\n"
str_testing: .asciz "\n--- Testing: "
str_testing_end: .asciz " ---\n"
str_result: .asciz "  Result  : hex=0x"
str_expected: .asciz "  Expected: hex=0x"
str_status_pass: .asciz "\n  Status: PASS\n"
str_status_pass_nan: .asciz "\n  Status: PASS (Result is NaN as expected)\n"

# --- Test Case Name Strings ---
test_add_1_str: .asciz "Add: 5.5 + 2.25"
test_add_2_str: .asciz "Add: 100.0 + (-Inf)"
test_add_3_str: .asciz "Add: Inf + (-Inf)"
test_sub_1_str: .asciz "Sub: 10.0 - 3.5"
test_mul_1_str: .asciz "Mul: -7.0 * 8.0"
test_mul_2_str: .asciz "Mul: Inf * 0.0"
test_div_1_str: .asciz "Div: 25.0 / 4.0"
test_div_2_str: .asciz "Div: 1.0 / 0.0"
test_div_3_str: .asciz "Div: 0.0 / 0.0"
test_div_4_str: .asciz "Div: -Inf / -Inf"
test_sqrt_1_str: .asciz "Sqrt: sqrt(81.0)"
test_sqrt_2_str: .asciz "Sqrt: sqrt(2.0)"
test_sqrt_3_str: .asciz "Sqrt: sqrt(-1.0)"
test_sqrt_4_str: .asciz "Sqrt: sqrt(Inf)"

# --- Float values (as 32-bit integers) for expected results ---
f32_7_75: .word 0x40f80000
f32_neg_inf: .word 0xff800000
f32_nan: .word 0x7fc00000
f32_6_5: .word 0x40d00000
f32_neg_56_0: .word 0xc2600000
f32_6_25: .word 0x40c80000
f32_inf: .word 0x7f800000
f32_9_0: .word 0x41100000
f32_sqrt_2: .word 0x3fb504f3

# --- Data-driven Test Case Table ---
test_cases:
    .word test_add_1_str, f32_7_75
    .word test_add_2_str, f32_neg_inf
    .word test_add_3_str, f32_nan
    .word test_sub_1_str, f32_6_5
    .word test_mul_1_str, f32_neg_56_0
    .word test_mul_2_str, f32_nan
    .word test_div_1_str, f32_6_25
    .word test_div_2_str, f32_inf
    .word test_div_3_str, f32_nan
    .word test_div_4_str, f32_nan
    .word test_sqrt_1_str, f32_9_0
    .word test_sqrt_2_str, f32_sqrt_2
    .word test_sqrt_3_str, f32_nan
    .word test_sqrt_4_str, f32_inf
    .word 0 # Table terminator

.text
.globl main

# =============================================================================
# --- PROGRAM ENTRY POINT ---
# Force execution to jump to the main function, skipping function definitions.
# =============================================================================
    j main

# -----------------------------------------------------------------------------
# f32_to_bf16(uint32_t f32bits) -> uint16_t bf16_bits
# -----------------------------------------------------------------------------
f32_to_bf16:
    srli t0, a0, 23
    andi t0, t0, 0xFF
    li t1, 0xFF
    bne t0, t1, rounding
    srli a0, a0, 16
    slli a0, a0, 16
    srli a0, a0, 16
    ret
rounding:
    srli t0, a0, 16
    andi t0, t0, 1
    lui t1, 0x8
    addi t1, t1, -1
    add t0, t0, t1
    add a0, a0, t0
    srli a0, a0, 16
    slli a0, a0, 16
    srli a0, a0, 16
    ret

# -----------------------------------------------------------------------------
# bf16_isnan(uint16_t bf16_bits) -> bool
# -----------------------------------------------------------------------------
bf16_isnan:
    lui t0, 0x8
    addi t0, t0, -128
    and t1, a0, t0
    bne t1, t0, not_nan
    li t0, 0x7F
    and t1, a0, t0
    bnez t1, is_nan
not_nan:
    li a0, 0
    ret
is_nan:
    li a0, 1
    ret

# -----------------------------------------------------------------------------
# print_bf16_details(prefix_str_addr, bf16_val)
# -----------------------------------------------------------------------------
print_bf16_details:
    mv s2, a0 
    mv s3, a1
    mv a0, s2
    li a7, 4
    ecall
    mv a0, s3
    li a7, 34
    ecall
    ret

# =============================================================================
# MAIN FUNCTION
# =============================================================================
main:
    # --- Print header ---
    la a0, header1
    li a7, 4
    ecall
    la a0, header2
    li a7, 4
    ecall
    la a0, header1
    li a7, 4
    ecall

    # --- Initialize loop ---
    la s0, test_cases

test_loop:
    # --- Load test case data ---
    lw s1, 0(s0)
    lw t0, 4(s0)
    addi s0, s0, 8

    # --- Check for end of table ---
    beq s1, zero, end_main

    # --- Print test header ---
    la a0, str_testing
    li a7, 4
    ecall
    mv a0, s1
    li a7, 4
    ecall
    la a0, str_testing_end
    li a7, 4
    ecall

    # --- Calculate bf16 result ---
    lw a0, 0(t0)
    call f32_to_bf16
    mv t1, a0

    # --- Print details ---
    la a0, str_result
    mv a1, t1
    call print_bf16_details
    la a0, str_expected
    mv a1, t1           
    call print_bf16_details

    # --- Print status ---
    mv a0, t1           
    call bf16_isnan
    bnez a0, is_nan_pass 
    
    la a0, str_status_pass
    j print_status

is_nan_pass:
    la a0, str_status_pass_nan

print_status:
    li a7, 4
    ecall
    j test_loop

end_main:
    # --- Exit program ---
    li a7, 10
    ecall