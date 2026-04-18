clear -all
analyze -vhdl2k sort_hw.vhd dual_port_bram.vhd
analyze -sv09 top.sv
elaborate -top {top}
clock clk
reset reset
prove -bg -all

