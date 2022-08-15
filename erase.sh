#!/bin/bash
/opt/riscv-openocd-wch/bin/openocd -f wch-riscv.cfg &
sleep 1
nc localhost 4444 <<EOF
flash erase_sector wch_riscv 0 last
exit
EOF