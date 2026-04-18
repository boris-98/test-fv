analyze -sv09 "pan.sv"
elaborate -top {pan}
clock clk
reset rst
prove -bg -all
