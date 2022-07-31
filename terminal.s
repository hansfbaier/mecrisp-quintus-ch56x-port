#
#    Mecrisp-Quintus - A native code Forth implementation for RISC-V
#    Copyright (C) 2018  Matthias Koch
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

.include "interrupts.s"
.include "../common/terminalhooks.s"

# -----------------------------------------------------------------------------
# Labels for a few hardware ports
# -----------------------------------------------------------------------------

  .equ UART1_BASE,         0x40003400
  .equ R32_UART1_CTRL,     0x40003400  # RW, UART1 control
  .equ R8_UART1_MCR,       0x40003400  # RW, UART1 modem control
  .equ R8_UART1_IER,       0x40003401  # RW, UART1 interrupt enable
  .equ R8_UART1_FCR,       0x40003402  # RW, UART1 FIFO control
  .equ R8_UART1_LCR,       0x40003403  # RW, UART1 line control
  .equ R32_UART1_STAT,     0x40003404  # RO, UART1 status
  .equ R8_UART1_IIR,       0x40003404  # RO, UART1 interrupt identification
  .equ R8_UART1_LSR,       0x40003405  # RO, UART1 line status
  .equ R32_UART1_FIFO,     0x40003408  # RW, UART1 data or FIFO port
  .equ R8_UART1_RBR,       0x40003408  # RO, UART1 receiver buffer, receiving byte
  .equ R8_UART1_THR,       0x40003408  # WO, UART1 transmitter holding, transmittal byte
  .equ R8_UART1_RFC,       0x4000340A  # RO, UART1 receiver FIFO count
  .equ R8_UART1_TFC,       0x4000340B  # RO, UART1 transmitter FIFO count
  .equ R32_UART1_SETUP,    0x4000340C  # RW, UART1 setup
  .equ R16_UART1_DL,       0x4000340C  # RW, UART1 divisor latch
  .equ R8_UART1_DLL,       0x4000340C  # RW, UART1 divisor latch LSB byte
  .equ R8_UART1_DLM,       0x4000340D  # RW, UART1 divisor latch MSB byte
  .equ R8_UART1_DIV,       0x4000340E

  .equ R8_RST_WDOG_CTRL,   0x40001006

  .equ RB_SOFTWARE_RESET,  1
  .equ UART_FIFO_SIZE,     8

# -----------------------------------------------------------------------------
uart_init:
# -----------------------------------------------------------------------------
  li      a0, 500000 # baudrate
  lui     a5, 0x7271
  addi    a5, a5,-512 # 7270e00 = 120.000.000 MHz
  divu    a5, a5, a0  # a5 = freq/baudrate

  li      a0, 5
  mul     a5, a5, a0
  srai    a5, a5, 2   # a5 = 5/4*(freq/baudrate)

  lui     a4, 0x40003
  li      a3, 1
  sb      a3, 0x40E(a4) # 4000340e = R8_UART1_DIV

  addi    a5, a5, 5     # a5 = 5/4*(freq/baudrate) + 5
  li      a0, 10
  divu    a5, a5, a0    # a5 = (5/4*(freq/baudrate) + 5) / 10

  sh      a5, 0x40C(a4) # R16_UART1_DL

  li      a5, -57
  sb      a5, 0x402(a4) # R8_UART1_FCR = (2<<6) | RB_FCR_TX_FIFO_CLR | RB_FCR_RX_FIFO_CLR | RB_FCR_FIFO_EN

  li      a5, 3
  sb      a5, 0x403(a4) # R8_UART1_LCR = RB_LCR_WORD_SZ

  li      a5, 64
  sb      a5, 0x401(a4) # R8_UART1_IER = RB_IER_TXD_EN

  # configure serial GPIOs

  # R32_PA_SMT |= (1 << 8) | (1 << 7)
  lui     a5, 0x40001
  lw      a4, 92(a5)
  ori     a4, a4, 384
  sw      a4, 92(a5)

  # R32_PA_DIR |= (1 << 8);
  lw      a4, 64(a5)
  ori     a4, a4, 256
  sw      a4, 64(a5)

  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "serial-emit"
serial_emit: # ( c -- ) Emit one character
# -----------------------------------------------------------------------------
  push x1

1:call serial_qemit
  popda x15
  beq x15, zero, 1b

  li x14, R8_UART1_THR
  sb x8, 0(x14)
  drop

  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "serial-key"
serial_key: # ( -- c ) Receive one character
# -----------------------------------------------------------------------------
  push x1

1:call serial_qkey
  popda x15
  beq x15, zero, 1b

  li x14, R8_UART1_RBR
  pushdatos
  lbu x8, 0(x14)

  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "serial-emit?"
serial_qemit:  # ( -- ? ) Ready to send a character ?
# -----------------------------------------------------------------------------
  push x1
  call pause

  pushdatos
  li x8, R8_UART1_TFC
  lb x8, 0(x8)

  li   a4, UART_FIFO_SIZE-1
  sltu x8, a4, x8
  addi x8, x8, -1

  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "serial-key?"
serial_qkey:  # ( -- ? ) Is there a key press ?
# -----------------------------------------------------------------------------
  push x1
  call pause

  pushdatos
  li x8, R8_UART1_RFC
  lb x8, 0(x8)

  sltiu x8, x8, 1 # 0<>
  addi x8, x8, -1

  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "reset"
# -----------------------------------------------------------------------------
  call enable_safe_access
  li a4, R8_RST_WDOG_CTRL
  li a5, 0x40 | RB_SOFTWARE_RESET
  sb a5, 0(a4)

  call disable_safe_access
  # Real chip resets now; this jump is just to trap the emulator:
  j Reset
