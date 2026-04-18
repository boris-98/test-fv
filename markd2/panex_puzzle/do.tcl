clear -all
analyze -sv09 panex.sv top.sv 
elaborate -top {top} 
clock clk
reset rst
prove -bg -all

