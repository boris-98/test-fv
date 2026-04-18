analyze -sv09 panex_rod.sv
elaborate -top {panex}
clock clk
reset rst
prove -bg -all
