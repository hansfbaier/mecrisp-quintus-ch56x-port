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

.include "../common/flash.s"

#------------------------------------------------------------------------------
  Definition Flag_visible|Flag_variable, "hook-hflash!" # ( -- addr )
  CoreVariable hook_hflashstore
#------------------------------------------------------------------------------
  pushdaconst hook_hflashstore
  ret
  .word hstore

# -----------------------------------------------------------------------------
  Definition Flag_visible, "hflash!"
hflashstore: # ( x addr -- )
# -----------------------------------------------------------------------------
  # Check if address is even

  andi x15, x8, 1
  beq x15, zero, 1f
    writeln "flash! needs even addresses."
    j quit
1:

  # Check if address is outside of Forth core
  li x14, FlashDictionaryAnfang
  bltu x8, x14, 2f

  # Fine !
  li x15, hook_hflashstore
  lw x15, 0(x15)
  jalr zero, x15, 0

2:writeln "Cannot write into core !"
  j quit
