###########################################################
# Last Modified: Jul-12, 2015
###########################################################
# READ ARGUMENTS -> DECODE ARGS -> FIND GCD -> SHOW GCD
# INTERRUPT : CHANGE INDEX TO DISPLAY
###########################################################
#---------------- Assignment of Registers ----------------#
# $s0: UART_CON ADDRESS     0x40000020
# $s1: PARAMETER 1
# $s2: PARAMETER 2
# $s3: GREATEST COMMON DIVISOR
# $s4: 7-segment DISPLAY CODE of AN0
# $s5: 7-segment DISPLAY CODE of AN1
# $s6: 7-segment DISPLAY CODE of AN2
# $s7: 7-segment DISPLAY CODE of AN3
# $t7: INDEX OF AN TO SHOW
###########################################################
#--------------- Addresses of Peripherals ----------------#
# UART_CON:             0X40000020 = 0($s0)
# LEDs:                 0x4000000C = -20($s0)
# 7-segment display:    0x40000014 = -12($s0)
# UART_RX:              0x4000001C = -4($s0)
# UART_TX:              0x40000018 = -8($s0)
###########################################################

    j   MAIN
    j   INTERRUPT
    j   EXCEPTION

MAIN:     
    lui  $t0, 0x4000            # $t0 = 0x40000000
    addi $s0, $t0, 0x0020       # $s0 = 0x40000020

###########################################################
# Read 2 Arguments from UART
# if (UART_CON[1] == 1) {
#     Read Data
# } else {
#     Waiting till UART_CON[1] == 1
# }
###########################################################
    addiu $t0, $zero, 0x0002
    sw    $t0, 0($s0)        # enable UART receiver
READ_LOOP_1:
    # Read 1st Argument from UART
    lw   $t0, 0($s0)
    andi $t0, $t0, 0x0004    # $t0[3] = UART_CON[3], $t0[31:4] = $t0[2:0] = 0
    beq  $t0, $zero, READ_LOOP_1
    # If (UART_CON[1] == 1), Read data (1st Argument). 
    lw   $s1, -4($s0)

READ_LOOP_2:
    # Read 2nd Argument from UART
    lw   $t0, 0($s0)
    andi $t0, $t0, 0x0004    # $t0[3] = UART_CON[3], $t0[31:4] = $t0[2:0] = 0
    beq  $t0, $zero, READ_LOOP_2
    # If (UART_CON[1] == 1), Read data (2nd Argument). 
    lw   $s2, -4($s0)

###########################################################
# Using 7-segment display, format ..._mmmm_0_xxxxxxx
# xxxxxxx is the corresponding 7-segments
# mmmm is the index of value to display
###########################################################

DECODEARGS: 
    sll  $a0, $s1, 24
    srl  $a0, $a0, 28            # $a0 = $s1[7:4]
    jal  DECODE
    add  $s4, $v0, $zero         # $s4 = ..._0000_0_xxxxxxx
    addi $t0, $zero, 0x0008     
    sll  $t0, $t0, 8             # $t0 = ..._1000_0_0000000
    or   $s4, $s4, $t0           # $s4 = ..._1000_0_xxxxxxx

    sll  $a0, $s1, 28
    srl  $a0, $a0, 28            # $a0 = $s1[3:0]
    jal  DECODE
    add  $s5, $v0, $zero         # $s5 = ..._0000_0_xxxxxxx
    addi $t0, $zero, 0x0004     
    sll  $t0, $t0, 8             # $t0 = ..._0100_0_0000000
    or   $s5, $s5, $t0           # $s5 = ..._0100_0_xxxxxxx

    sll  $a0, $s2, 24
    srl  $a0, $a0, 28            # $a0 = $s2[7:4]
    jal  DECODE
    add  $s6, $v0, $zero         # $s6 = ..._0000_0_xxxxxxx
    addi $t0, $zero, 0x0002     
    sll  $t0, $t0, 8             # $t0 = ..._0010_0_0000000
    or   $s6, $s6, $t0           # $s6 = ..._0010_0_xxxxxxx

    sll  $a0, $s2, 28
    srl  $a0, $a0, 28            # $a0 = $s2[3:0]
    jal  DECODE
    add  $s7, $v0, $zero         # $s7 = ..._0000_0_xxxxxxx
    addi $t0, $zero, 0x0001     
    sll  $t0, $t0, 8             # $t0 = ..._0001_0_0000000
    or   $s7, $s7, $t0           # $s7 = ..._0001_0_xxxxxxx

###########################################################
# Find GCD
###########################################################

    addi $t7, $zero, 0           # $t7 = 0, initialize the index to show

    # Find GCD (Greatest Common Divisor)
    addi $a0, $s1, 0
    addi $a1, $s2, 0
    jal  GCD                     # $v0 = GCD($a0, $a1)
    addi $s3, $v0, 0

    # Display result with LED
    sw   $s3, -20($s0)

###########################################################
# Send Data to UART
###########################################################

SEND_LOOP:
    lw   $t0, 0($s0)
    andi $t0, $t0, 0x0010    # $t0[4] = UART_CON[4]
    bne  $t0, $zero, SEND_LOOP

    # Enable TX_STATUS
    addi $t0, $t0, 0x0001
    lw   $t1, 0($s0)
    or   $t0, $t0, $t1       # Set UART_CON[0] to 1, the rest remains the same
    sw   $t0, 0($s0)

    # Save result to UART_TXD, and Trigger a new transmission
    sw   $s3, -8($s0)
    
    # Restore TX_STATUS and Continue reading from UART
    lw   $t1, 0($s0)
    addi $t0, $zero, -2      # -2 = 16'b1111_1111_1111_1110
    and  $t0, $t0, $t1       # Set UART_CON[0] to 0, the rest remains the same
    sw   $t0, 0($s0)
    j    READ_LOOP_1

###########################################################
#              BELOW this line are functions
###########################################################

###########################################################
# $v0 = GCD($a0, $a1)
###########################################################

GCD:
    # $t8, $t9 are temp variables storing the arguments. 
    addi $t8, $a0, 0             # $t8 = $a0
    addi $t9, $a1, 0             # $t9 = $a1

GCD_LOOP:
    slt $t0, $t8, $t9
    beq $t0, $zero, NOT_SWAP_CONTINUE

    # Swap $t8 and $t9 to make sure $t8 > $t9
    addi $t0, $t8, 0
    addi $t8, $t9, 0
    addi $t9, $t0, 0

NOT_SWAP_CONTINUE:
    # If $t8 == $t9, then exit loop and return
    sub $t0, $t8, $t9
    beq $t0, $zero, GCD_RETURN
    # Else $t8 = $t8 - $t9, and continue to loop
    addi $t8, $t0, 0
    j GCD_LOOP

GCD_RETURN:
    addi $v0, $t8, 0
    jr $ra

###########################################################
# $v0 = 7-segment display code of $a0
# e.g. $a0 = 2 => $v0 = 0x00000012
###########################################################

DECODE:
    # 0 -> 000_0001 ($v0 = 0x00000001)
    bne $a0, $zero, DECODE_NOT_0
    addi $v0, $zero, 0x0001
    j DECODE_RETURN

DECODE_NOT_0:
    addi $t0, $zero, 1
    bne $a0, $t0, DECODE_NOT_1

    # 1 -> 100_1111 ($v0 = 0x0000004E)
    addi $v0, $zero, 0x004E
    j DECODE_RETURN

DECODE_NOT_1:
    addi $t0, $zero, 2
    bne $a0, $t0, DECODE_NOT_2

    # 2 -> 001_0010 ($v0 = 0x00000012)
    addi $v0, $zero, 0x0012
    j DECODE_RETURN

DECODE_NOT_2:
    addi $t0, $zero, 3
    bne $a0, $t0, DECODE_NOT_3

    # 3 -> 000_0110 ($v0 = 0x00000006)
    addi $v0, $zero, 0x0006
    j DECODE_RETURN

DECODE_NOT_3:
    addi $t0, $zero, 4
    bne $a0, $t0, DECODE_NOT_4

    # 4 -> 100_1100 ($v0 = 0x0000004C)
    addi $v0, $zero, 0x4C
    j DECODE_RETURN

DECODE_NOT_4:
    addi $t0, $zero, 5
    bne $a0, $t0, DECODE_NOT_5

    # 5 -> 010_0100 ($v0 = 0x00000024)
    addi $v0, $zero, 0x0024
    j DECODE_RETURN

DECODE_NOT_5:
    addi $t0, $zero, 6
    bne $a0, $t0, DECODE_NOT_6

    # 6 -> 010_0000 ($v0 = 0x00000020)
    addi $v0, $zero, 0x0020
    j DECODE_RETURN

DECODE_NOT_6:
    addi $t0, $zero, 7
    bne $a0, $t0, DECODE_NOT_7

    # 7 -> 000_1111 ($v0 = 0x0000000E)
    addi $v0, $zero, 0x000E
    j DECODE_RETURN

DECODE_NOT_7:
    addi $t0, $zero, 8
    bne $a0, $t0, DECODE_NOT_8

    # 8 -> 000_0000 ($v0 = 0x00000000)
    addi $v0, $zero, 0x0000
    j DECODE_RETURN

DECODE_NOT_8:
    addi $t0, $zero, 9
    bne $a0, $t0, DECODE_NOT_9

    # 9 -> 000_0100 ($v0 = 0x00000004)
    addi $v0, $zero, 0x0004
    j DECODE_RETURN

DECODE_NOT_9:
    addi $t0, $zero, 10
    bne $a0, $t0, DECODE_NOT_A

    # A -> 000_1000 ($v0 = 0x00000008)
    addi $v0, $zero, 0x0008
    j DECODE_RETURN

DECODE_NOT_A:
    addi $t0, $zero, 11
    bne $a0, $t0, DECODE_NOT_B

    # B -> 110_0000 ($v0 = 0x00000060)
    addi $v0, $zero, 0x0060
    j DECODE_RETURN

DECODE_NOT_B:
    addi $t0, $zero, 12
    bne $a0, $t0, DECODE_NOT_C

    # C -> 011_0001 ($v0 = 0x00000031)
    addi $v0, $zero, 0x0031
    j DECODE_RETURN

DECODE_NOT_C:
    addi $t0, $zero, 13
    bne $a0, $t0, DECODE_NOT_D

    # D -> 100_0010 ($v0 = 0x00000042)
    addi $v0, $zero, 0x0042
    j DECODE_RETURN

DECODE_NOT_D:
    addi $t0, $zero, 14
    bne $a0, $t0, DECODE_NOT_E

    # E -> 011_0000 ($v0 = 0x00000030)
    addi $v0, $zero, 0x0030
    j DECODE_RETURN

DECODE_NOT_E:
    # F -> 011_1000 ($v0 = 0x00000038)
    addi $v0, $zero, 0x0038
    j DECODE_RETURN

DECODE_RETURN:
    jr $ra
    
###########################################################
# Interrupt to show DIGITs on 7-segment display. 
# Jump to $26 afterwards. 
###########################################################

INTERRUPT:
    # use the DIGITs to show the parameters
    bne  $t7, $zero, INTERRUPT_NOT_0
    sw   $s4, -12($s0)
    addi $t7, $zero, 1
    j INTERRUPT_RETURN

INTERRUPT_NOT_0:
    addi $t0, $zero, 1
    bne  $t7, $t0, INTERRUPT_NOT_1
    sw   $s5, -12($s0)
    addi $t7, $zero, 2
    j INTERRUPT_RETURN

INTERRUPT_NOT_1:
    addi $t0, $zero, 2
    bne  $t7, $t0, INTERRUPT_NOT_2
    sw   $s6, -12($s0)
    addi $t7, $zero, 3
    j INTERRUPT_RETURN

INTERRUPT_NOT_2:
    sw   $s7, -12($s0)
    addi $t7, $zero, 0
    j INTERRUPT_RETURN

INTERRUPT_RETURN:
    addi $t0, $t0, -4
    sub $26, $26, $t0
    jr $26

###########################################################
# Do NOT handle exceptions currently, just stop here. 
###########################################################

EXCEPTION:
    j EXCEPTION
