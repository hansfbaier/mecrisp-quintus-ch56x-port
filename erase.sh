
#!/bin/bash
/opt/wch-openocd/bin/openocd -f /opt/wch-openocd/bin/wch-riscv.cfg &
sleep 1
nc localhost 4444 <<EOF
flash erase_sector wch_riscv 0 last
EOF
