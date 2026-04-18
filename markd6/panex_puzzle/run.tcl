clear -all
analyze -sv09 panex.sv
analyze -sv09 assertions.sv
analyze -sv09 bind.sv
elaborate -top panex
clock clk
reset rst
prove -bg -all
