clear -all

analyze -sv09 panex.sv
analyze -sv09 top.sv

elaborate -top {top}

clock clk
reset rst

prove -bg -all

