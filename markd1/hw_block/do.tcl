analyze -sv09 "hw_block.sv"
elaborate -top {hw_block}
clock clk
reset rst
prove -bg -all
