analyze -sv09 puzzle.sv  
elaborate -top {puzzle}
clock clk -factor 1 -phase 1
reset -expression {rst}
prove -bg -all
