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

# Interrupt handling and CSR register access

  .include "../common/interrupt-common.s"
  .include "../common/cycles.s"

# -----------------------------------------------------------------------------
  Definition Flag_visible, "mepc!" # Where did it occour ?
mepc_store:
# -----------------------------------------------------------------------------
  csrrw x0, mepc, x8
  drop
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "mepc@" # Where did it occour ?
mepc_fetch:
# -----------------------------------------------------------------------------
  pushdatos
  csrrs x8, mepc, zero
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "mcause@" # Which interrupt ?
mcause_fetch:
# -----------------------------------------------------------------------------
  pushdatos
  csrrs x8, mcause, zero
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "mtval@" # Which value ? Important for memory errors.
mtval_fetch:
# -----------------------------------------------------------------------------
  pushdatos
  csrrs x8, mtval, zero
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "memfault"  # Message for wild memory access
memfault:                              #
# -----------------------------------------------------------------------------
  push x1
  write "Memory access error"
  j unhandled_intern

# -----------------------------------------------------------------------------
  Definition Flag_visible, "unhandled-nonvector" # Message for wild interrupts
unhandled_nonvector:                             #   and handler for unused nonvectored interrupts
# -----------------------------------------------------------------------------
  push x1
  write "Unhandled Interrupt (non-vectored)"
  j unhandled_intern

# -----------------------------------------------------------------------------
  Definition Flag_visible, "unhandled" # Message for wild interrupts
unhandled:                             #   and handler for unused interrupts
# -----------------------------------------------------------------------------
  push x1
  write "Unhandled Interrupt (vectored)"

unhandled_intern:
  call trap_signature

  # Clear pending interrupt in ECLIC

  csrrs x15, mcause, zero     # Extract the interrupt number
  li x14, 0xFFF
  and x15, x15, x14

  pop x1
  ret

# -----------------------------------------------------------------------------
  Definition Flag_visible, "fault" # Message for unhandled exceptions
fault:
# -----------------------------------------------------------------------------
  push x1

  write "Unhandled Exception"
  call trap_signature

  # Advance the location we are returning to in order to skip the faulty instruction
  csrrs x15, mepc, zero
  lhu x14, 0(x15)     # Fetch the opcode which caused this exception

  andi x14, x15,  3   # Compressed opcodes end with %00, %01 or %10. Normal 4 byte opcodes end with %11.
  addi x14, x14, -3   # Gives zero for long opcodes only

  addi x15, x15,  2   # Skip 2 bytes for a compressed opcode
  bne  x14, zero, 1f
  addi x15, x15,  2 # Skip 4 bytes in total for a long opcode

1:csrrw x0, mepc, x15 # Set return address.

  pop x1
  ret

# -----------------------------------------------------------------------------
trap_signature:
# -----------------------------------------------------------------------------
  push x1

  write " mcause: "
  call mcause_fetch
  call hexdot

  write "mepc: "
  call mepc_fetch
  call hexdot

  write "mtval: "
  call mtval_fetch
  call hexdot

  writeln "!"

  pop x1
  ret

# -----------------------------------------------------------------------------
  .include "../common/irq-handler.s"
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Fault and collection vectors, special:
# -----------------------------------------------------------------------------

initinterrupt  fault,      irq_fault,      fault, 6  # In CLIC mode, the trap entry must be 64 bytes aligned

initinterrupt  nonvector,  irq_nonvector,  unhandled_nonvector
initinterrupt  collection, irq_collection, unhandled

# -----------------------------------------------------------------------------
# For all these vectors in the interrupt vector table you may wish to use from Forth:
# -----------------------------------------------------------------------------

initinterrupt  systick,    irq_systick,    unhandled
initinterrupt  software,   irq_software,   unhandled
initinterrupt  memfault,   irq_memfault,   memfault

initinterrupt  timer1,     irq_timer1,     unhandled
initinterrupt  timer2,     irq_timer2,     unhandled
initinterrupt  usbss,      irq_usbss,      unhandled
initinterrupt  usbhs,      irq_usbhs,      unhandled
initinterrupt  hspi,       irq_hspi,       unhandled
initinterrupt  serdes,     irq_serdes,     unhandled

#              Forth-Name  Assembler-Name  Default handler
