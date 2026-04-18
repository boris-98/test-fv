clear -all
analyze -sv09 panex.sv
elaborate -top {panex}
clock clk	
reset rst
prove -all


