clear -all

analyze -sv09 +define+N=8 hw_block.sv

elaborate -top {sort_ip}

clock clk
reset -expression {!rst_n}

prove -all

report -summary
