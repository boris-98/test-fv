clear -all
analyze -sv09 sort_ip.sv
analyze -sv09 top.sv
elaborate -top top
clock clk
reset rst
prove -all
report -summary
