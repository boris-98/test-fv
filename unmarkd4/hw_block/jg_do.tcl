analyze -sv09 my_pkg.sv mem.sv sort_ip.sv  top_checkers.sv bind.sv 
elaborate -disable_auto_bbox -top {sort_ip}
clock clk -factor 1 -phase 1
reset -expression {rst}
prove -bg -all



