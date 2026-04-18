analyze -sv09 +define+ADDR_WIDTH=2 +define+DATA_WIDTH=8 param_pkg.sv top.sv sort.sv memory.sv
elaborate -top {top}
clock clk
reset rst
prove -bg -all
