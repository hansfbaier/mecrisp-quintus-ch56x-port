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
.equ  RB_ROM_WRITE,      0x80 # RWA, needs to be written for flashing

.equ  R8_SPI_ROM_DATA,   0x40001018
.equ  R32_SPI_ROM_DATA,  0x40001014
.equ  R32_SPI_ROM_CTRL,  0x40001018
.equ  R16_SPI_ROM_CR,    0x4000101A

.equ ROM_BEGIN_READ,    0b1011
.equ ROM_BEGIN_WRITE,   0b0110
.equ ROM_END_WRITE,     0b0101

.equ ROM_ADDR_OFFSET,   0x8000
.equ ROM_END,           0x80000


safe_access_mode_on:
  push x1
  li     x14, SPI_ROM_BASE
  li     x15, 0x57
  sb     x15, 0 (x14)
  li     x15, 0xa8
  sb     x15, 0 (x14)
  pop x1
  ret

rom_write_enable:
  push x1
  call  safe_access_mode_on
  li    x14, SPI_ROM_BASE
  li    x15, R8_GLOB_ROM_CFG
  lb    x16, 0 (x15)
  ori   x16, x16, (RB_ROM_DATA_WE | RB_ROM_CODE_WE | RB_ROM_WRITE)
  sb    x16, 0 (x15)
  pop x1
  ret

rom_write_disable:
  push  x1
  call  safe_access_mode_on
  li    x14, SPI_ROM_BASE
  li    x15, R8_GLOB_ROM_CFG
  lb    x16, 0 (x15)
  andi  x16, x16, ~(RB_ROM_DATA_WE | RB_ROM_CODE_WE)
  ori   x16, x16, RB_ROM_WRITE
  sb    x16, 0 (x15)
  pop x1
  ret

rom_begin: # ( code -- )
  push  x1
  li    x14,  R16_SPI_ROM_CR
  sb    zero, 0 (x14)
  li    x15,  0b111
  sb    x15,  0 (x14)
  li    x14,  R32_SPI_ROM_CTRL
  popda x15
  sb    x15,  0 (x14)
  pop x1
  ret

rom_program_start: # ( code -- )
  push   x1
  li     x14, ROM_BEGIN_WRITE
  pushda x14
  call   rom_begin
  call   rom_access_end
  call   rom_begin
  pop    x1
  ret

rom_data_read:   # ( -- data )
  push   x1
  li     x14, R16_SPI_ROM_CR
1:
  lb     x15, 0 (x14)
  slli   x15, x15, 24
  srai   x15, x15, 24
  bltz   x15, 1b

  li     x14, R8_SPI_ROM_DATA
  lb     x15, 0 (x14)
  pushda x15
  pop    x1
  ret

rom_data_write:   # ( data -- )
  push   x1
  li     x14, R16_SPI_ROM_CR
1:
  lb     x15, 0 (x14)
  slli   x15, x15, 24
  srai   x15, x15, 24
  bltz   x15, 1b

  li     x14, R8_SPI_ROM_DATA
  popda  x15
  sb     x15, 0 (x14)
  pop    x1
  ret

rom_access:   # ( data -- )
  push   x1
  li     x14, R16_SPI_ROM_CR
1:
  lb     x15, 0 (x14)
  slli   x15, x15, 24
  srai   x15, x15, 24
  bltz   x15, 1b

  popda  x15
  sb     x15, 0 (x14)
  pop    x1
  ret

rom_access_end:  # ( -- )
  push   x1
  pushda zero
  call   rom_access
  pop    x1
  ret

rom_write_addr:   # ( addr -- )
  push    x1
  popda   x14
  mv      x15, x14
  srli    x15, x15, 16
  andi    x15, x15, 0xff
  pushda  x15
  call    rom_data_write

  mv      x15, x14
  srli    x15, x15, 8
  andi    x15, x15, 0xff
  pushda  x15
  call    rom_data_write

  andi    x14, x14, 0xff
  pushda  x14
  call    rom_data_write

  pop     x1
  ret

rom_write_start:  # ( -- )
  push   x1
  li     x14, 0b10
  pushda x14
  call   rom_program_start
  pop    x1
  ret

rom_write_end:   # ( -- status )
  push    x1
  call    rom_access_end
  li      x14, 0x280000  # counter

1:
  li      x15, ROM_END_WRITE
  pushda  x15
  call    rom_begin
  call    rom_data_read
  drop
  call    rom_data_read
  call    rom_access_end
  popda   x15
  andi    x15, x15, 1
  addi    x14, x14, -1
  beqz    x14, 2f
  beqz    x15, 1b

  pushda  zero
  pop     x1
  ret
2:
  li      x14, 0xff
  pushda  x14
  pop     x1
  ret

rom_write_word:   # ( data addr -- )
  push    x1

  popda   x14
  andi    x14, x14, ~0b11
  li      x15, ROM_ADDR_OFFSET
  add     x14, x14, x15     # x14: rom-address
  pushda  x14

  li      x15, ROM_END
  bge     x14, x15, 2f

  call    rom_write_enable
1:
  call    rom_write_start
  call    rom_write_addr
  li      x14, R32_SPI_ROM_DATA
  popda   x15
  sw      x15, 0 (x14)

  li      x14, R16_SPI_ROM_CR
  lb      x15, 0 (x14)
  ori     x15, x15, 0x10
  pushda  x15
  dup
  call    rom_access
  dup
  call    rom_access
  dup
  call    rom_access
  call    rom_access
  call    rom_write_end

  popda   x14
  beqz    x14, 1b

  call    rom_write_disable
  pop     x1
  ret

2:
  writeln "address out of range"
  j quit

# -----------------------------------------------------------------------------
  Definition Flag_visible, "flash!" # ( x Addr -- )
  # writes a data word into flash
# -----------------------------------------------------------------------------
flashstore:
  push_x1_x10_x11

  # Is the desired location in the flash dictionary?
  dup
  call addrinflash
  popda x15
  beq x15, zero, 3f

  # outside the forth core?
  laf x15, FlashDictionaryAnfang
  bltu x8, x15, 3f

  popda x10 # Adress
  popda x11 # Data

  # address must be word aligned
  andi x15, x10, 3
  bne x15, zero, 3f

  # writing flash works on the ch56x without having to erase beforehand,
  # so now we just write

  pushda x11
  pushda x10
  call   rom_write_word

  # since ROM is mirrored in RAMX, we have to write there to, so
  # that the changes become visible immediately
  # TODO: make this conditional depending on the RAMX size configuration
  sw     x11, 0 (x10)

2:pop_x1_x10_x11
  ret

3:writeln "Wrong address or data for writing flash !"
  j quit

# -----------------------------------------------------------------------------
  Definition Flag_visible, "hflash!" # ( x Addr -- )
  # writes a data halfword into flash
# -----------------------------------------------------------------------------
hflashstore:
  push_x1_x10_x11

  # Is the desired location in the flash dictionary?
  dup
  call addrinflash
  popda x15
  beq x15, zero, 4f

  # outside the forth core?
  laf x15, FlashDictionaryAnfang
  bltu x8, x15, 4f

  popda x10 # Adress
  popda x11 # Data

  # address must be halfword aligned
  andi x15, x10, 1
  bne x15, zero, 4f

  # writing flash works on the ch56x without having to erase beforehand,
  # so now we just write

  # read the old flash contents and replace only the said halfword
  andi   x14, x10, ~0b11   # align to word address => x14 = rom address
  lw     x15, 0 (x14)      # x15: old memory content

  # if we are on an odd halfword, place the data on the high halfword
  bne    x14, x10, 2f

1:
  # even halfword, place new data in lower halfword
  # first clear out lower halfword in old data
  srli   x15, x15, 16
  slli   x15, x15, 16
  # then clear out upper halfword in new data
  slli   x11, x11, 16
  srli   x11, x11, 16
  # and combine them
  or     x11, x11, x15
  j      3f

2:
  # odd halfword, place new data in upper halfword
  # first clear out upper halfword in old data
  slli   x15, x15, 16
  srli   x15, x15, 16
  # then clear out lower halfword in new data
  srli   x11, x11, 16
  slli   x11, x11, 16
  # and combine them
  or     x11, x11, x15

3:
  pushda x11
  pushda x10
  call   rom_write_word

  # since ROM is mirrored in RAMX, we have to write there to, so
  # that the changes become visible immediately
  # TODO: make this conditional depending on the RAMX size configuration
  sw     x11, 0 (x10)

  pop_x1_x10_x11
  ret

4:writeln "Wrong address or data for writing flash !"
  j quit
