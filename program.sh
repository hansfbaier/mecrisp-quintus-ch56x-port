
#!/bin/bash
/opt/wch-openocd/bin/openocd -f /opt/wch-openocd/bin/wch-riscv.cfg &
sleep 1
nc localhost 4444 <<EOF
program mecrisp-quintus-ch56x.hex 0 verify reset
EOF
pkill openocd
