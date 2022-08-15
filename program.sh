#!/bin/bash
/opt/riscv-openocd-wch/bin/openocd -f wch-riscv.cfg -c "program mecrisp-quintus-ch56x.hex 0 verify" -c "wlink_reset_resume" -c exit