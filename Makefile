
ARMGNU?=riscv64-linux-gnu

AOPS = --warn --fatal-warnings

all : mecrisp-quintus-ch56x.bin

mecrisp-quintus-ch56x.o : mecrisp-quintus-ch56x.s terminal.s interrupts.s flash.s
	$(ARMGNU)-as mecrisp-quintus-ch56x.s -o mecrisp-quintus-ch56x.o -march=rv32im

mecrisp-quintus-ch56x.bin : memmap mecrisp-quintus-ch56x.o
	$(ARMGNU)-ld -o mecrisp-quintus-ch56x.elf -T memmap mecrisp-quintus-ch56x.o -m elf32lriscv
	$(ARMGNU)-objdump -Mnumeric -D mecrisp-quintus-ch56x.elf > mecrisp-quintus-ch56x.list
	$(ARMGNU)-objcopy mecrisp-quintus-ch56x.elf mecrisp-quintus-ch56x.bin -O binary
	$(ARMGNU)-objcopy mecrisp-quintus-ch56x.elf mecrisp-quintus-ch56x.hex -O ihex

clean:
	rm -f *.bin
	rm -f *.hex
	rm -f *.o
	rm -f *.elf
	rm -f *.list
