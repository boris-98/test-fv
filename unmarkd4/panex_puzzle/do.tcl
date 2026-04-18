clear -all
analyze -sv09 sv_model.sv
analyze -sv09 top.sv
analyze -sv09 bind.sv
elaborate -top panex
clock clk
reset rst
prove -bg -all

