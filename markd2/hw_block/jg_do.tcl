analyze -sv09 my_pkg.sv bram.sv sort.sv sort_checker.sv bind.sv
elaborate -disable_auto_bbox -top {sort}
clock clk -factor 1 -phase 1
reset -expression {rst}
prove -bg -all

