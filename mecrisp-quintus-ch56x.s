#
#    Mecrisp-Quintus - A native code Forth implementation for RISC-V
#    Copyright (C) 2018  Matthias Koch
#    Copyright (C) 2022  Hans Baier <hansfbaier@gmail.com> (CH56x port)
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

# -----------------------------------------------------------------------------
# Swiches for capabilities of this chip
# -----------------------------------------------------------------------------

.option norelax
.option rvc
.equ compressed_isa, 1

# -----------------------------------------------------------------------------
# Speicherkarte für Flash und RAM
# Memory map for Flash and RAM
# -----------------------------------------------------------------------------

# Konstanten für die Größe des Ram-Speichers

.equ RamAnfang,  0x20020000  # Start of RAM
.equ RamEnde,    0x20030000  # End   of RAM.   64 kb.
# the area above 64kb is reserved for DMA

# Konstanten für die Größe und Aufteilung des Flash-Speichers

.equ FlashAnfang, 0x00000000 # Start of Flash

# .equ FlashEnde,   0x00070000 # End   of Flash.  448 kb.
# Only 64 kB are cached in RAMX and able to run forth code efficiently
# If we try to run code outside that range it will run at 1/8 speed
# also writes to it will need a reset in order to appear visibles
.equ FlashEnde,   0x0010000 # End   of Flash.  64 kb.

# we need to start at a 64k page boundary because otherwise
# we could not erase and reprogram flash without erasing
# parts of the core
.equ FlashDictionaryAnfang, FlashAnfang + 0x5000
.equ FlashDictionaryEnde,   FlashEnde

.equ R8_SAFE_ACCESS_SIG,   0x40001000
.equ R8_CLK_PLL_DIV,       0x40001008
.equ R8_CLK_CFG_CTRL,      0x4000100A
.equ RB_CLK_SEL_PLL,       2

.macro dbg, char
  li    x14, 0x40003408    # R8_UART1_THR
  li    x15, \char
  sb    x15, 0 (x14)
.endm

# -----------------------------------------------------------------------------
# Core start
# -----------------------------------------------------------------------------

.text

# -----------------------------------------------------------------------------
# Vector table
# -----------------------------------------------------------------------------

.global _start
.align  1
  j Reset
.align  1
_vector_base:
.option norvc;
  .word   0
  .word   0
  j irq_software                /* NMI Handler */
  j irq_memfault                /* Hard Fault Handler */
  .word   0xf7f9bf11
  .word   0
  .word   0
  .word   0
  .word   0
  .word   0
  .word   0
  .word   0
  j irq_systick            /* SysTick Handler */
  .word   0
  j irq_software           /* SW Handler */
  .word   0
  /* External Interrupts */
  j irq_collection          /* WDOG */
  j irq_collection          /* TMR0 */
  j irq_collection          /* GPIO */
  j irq_collection          /* SPI0 */
  j irq_usbss               /* USBSS */
  j irq_collection          /* LINK */
  j irq_timer1              /* TMR1 */
  j irq_timer2              /* TMR2 */
  j irq_collection          /* UART0 */
  j irq_usbhs               /* USBHS */
  j irq_collection          /* EMMC */
  j irq_collection          /* DVP */
  j irq_hspi                /* HSPI */
  j irq_collection          /* SPI1 */
  j irq_collection          /* UART1 */
  j irq_collection          /* UART2 */
  j irq_collection          /* UART3 */
  j irq_serdes              /* SERDES */
  j irq_collection          /* ETH */
  j irq_collection          /* PMT */
  j irq_collection          /* ECDC */
.option rvc;

enable_safe_access:
  li a0, R8_SAFE_ACCESS_SIG
  # write safe access sequence
  li t0, 0x57
  sb t0, 0(a0)
  li t0, 0xa8
  sb t0, 0(a0)
  ret

disable_safe_access:
  li a0, R8_SAFE_ACCESS_SIG
  sb x0, 0(a0)
  ret

# -----------------------------------------------------------------------------
# Include the Forth core of Mecrisp-Quintus
# -----------------------------------------------------------------------------

  .include "../common/forth-core.s"

# -----------------------------------------------------------------------------
Reset: # Forth begins here
csrrsi zero, mstatus, 8    # MSTATUS: Set Machine Interrupt Enable Bit

# -----------------------------------------------------------------------------
  /* init system clock */
  call enable_safe_access

  # write clock PLL divider
  li a0, R8_CLK_PLL_DIV
  li t0, 0x40 | 4
  sb t0, 0(a0)

  # write clock PLL divider
  li a0, R8_CLK_CFG_CTRL
  li t0, (0x80 | RB_CLK_SEL_PLL)
  sb t0, 0(a0)

  call disable_safe_access

  # Initialisation of terminal hardware, without stacks
  call uart_init

  # replace the encrypted erased flash pattern with FFFFFFFF
  # because that is what mecrisp expects when looking for the
  # end of the flash dictionary
  li     a0, FlashAnfang
  li     a1, FlashEnde - 4
  li     a2, 0xffffffff
  li     a3, 0xf7f9bf11 # encrypted erased flash

3:
  lw     t0, 0(a1)    # load word at current location
  bne    t0, a3, 4f   # check if it contains the erased flash pattern, otherwise we are done
  sw     a2, 0(a1)    # replace it with 0xffffffff in the flash mirror RAM
  addi   a1, a1, -4   # next address

  bge    a1, a0, 3b   # repeat until we hit the beginning of flash

4:
	/* enable all interrupts */
  li      t0, 0x88
  csrs    mstatus, t0
	la      t0, _vector_base
  ori     t0, t0, 1
	csrw    mtvec, t0
	la      t0, init
	csrw    mepc, t0
	mret

init:
  # Catch the pointers for Flash dictionary
  .include "../common/catchflashpointers.s"

  welcome " for RISC-V 32 IMAC by Matthias Koch, ported to CH56x by Hans Baier\r\n"

  # Ready to fly !
  .include "../common/boot.s"
