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

.equ  SPI_ROM_BASE,      0x40001000
.equ  R8_GLOB_ROM_CFG,   0x40001004  # RWA, flash ROM configuration, SAM and bit7:6 must write 1:0

.equ  RB_ROM_EXT_RE,     0x01 # RWA, enable flash ROM being read by external programmer: 0=reading protect, 1=enable read
.equ  RB_CODE_RAM_WE,    0x02 # RWA, enable code RAM being write: 0=writing protect, 1=enable write
.equ  RB_ROM_DATA_WE,    0x04 # RWA, enable flash ROM data area being erase/write: 0=writing protect, 1=enable program and erase
.equ  RB_ROM_CODE_WE,    0x08 # RWA, enable flash ROM code & data area being erase/write: 0=writing protect, 1=enable program and erase
.equ  RB_ROM_CODE_OFS,   0x10 # RWA, user code offset in ROM: 1: 0x04000; 0: 0x00000.

.equ  R8_SPI_ROM_DATA,   0x40001018
.equ  SPI_ROM_DATA,      0x18
.equ  R16_SPI_ROM_CR,    0x4000101A
.equ  SPI_ROM_CR,        0x1A

# -----------------------------------------------------------------------------
  Definition Flag_visible, "flash!"
flashstore: # ( x addr -- )
# -----------------------------------------------------------------------------
  j store

# -----------------------------------------------------------------------------
  Definition Flag_visible, "hflash!"
hflashstore: # ( x addr -- )
# -----------------------------------------------------------------------------
  j hstore


# a0: byte to write to control register
flash_begin:
  li              a5,   SPI_ROM_BASE
  sb              zero, SPI_ROM_CR(a5)   # CR = 0
  c.li            a4,   0b0111
  sb              a4,   SPI_ROM_CR(a5)   # CR = 0b111
  sb              a0,   SPI_ROM_DATA(a5)
  ret

flash_end:
  li              a4, R16_SPI_ROM_CR

1:
  lbu             a5, 0(a4)
  c.slli          a5, 24
  c.srai          a5, 24
  blt             a5, zero,1b  # while the control register is nonzero, wait

  sb              zero, 0(a4) # write zero to control register
  ret


flash_read_reg:
  li              a5, SPI_ROM_BASE

1:
  lbu             a5, SPI_ROM_CR(a4)
  c.slli          a5, 24
  c.srai          a5, 24
  blt             a5, zero,1b  # while the control register is nonzero, wait

  lbu             a0, SPI_ROM_DATA(a4) # return content of data register
  ret


flash_write_reg:
  li              a5, SPI_ROM_BASE

1:
  lbu             a5, SPI_ROM_CR(a4)
  c.slli          a5, 24
  c.srai          a5, 24
  blt             a5, zero,1b  # while the control register is nonzero, wait

  sb              a0, SPI_ROM_DATA(a4) # write data register
  ret


flash_write_addr:
  # write MSB of address
  c.mv           a6, a0      # save full address into a6
  srai           a0, a0, 16
  andi           a0, a0, 0xff
  call           flash_write_reg

  # write middle byte of address
  c.mv           a0, a6
  srai           a0, a0, 8
  andi           a0, a0, 0xff
  call           flash_write_reg

  # write LSB of address
  c.mv           a0, a6
  andi           a0, a0, 0xff
  call           flash_write_reg

  c.mv           a0, a6
  ret
