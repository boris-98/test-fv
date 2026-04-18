module panex #(parameter S = 4) (
    input clk,
    input rst,
    input [1:0] fr, 
    input [1:0] to 
);
    logic [2:0] poles [0:2][0:S-1];

    integer i, j, fr_idx, to_idx;
    logic move_possible;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 3; i++) begin
                for (j = 0; j < S; j++) begin
                    if (i == 0) poles[i][j] <= j + 1;
                    else        poles[i][j] <= 0;
                end
            end
        end else begin

            fr_idx = -1;
            to_idx = -1;

            for (int i = 0; i < S; i++) begin
                if (poles[fr][i] != 0) begin
                    fr_idx = i;
                    break;
                end
            end

            if (fr_idx != -1) begin
                for (int i = 0; i < S; i++) begin
                    if (poles[to][i] == 0 && i <= (poles[fr][fr_idx] - 1)) begin
                        to_idx = i;
                    end else begin
                        break; 
                    end
                end
            end

            if (fr != to && fr_idx != -1 && to_idx != -1) begin
                poles[to][to_idx] <= poles[fr][fr_idx];
                poles[fr][fr_idx] <= 0;
            end
        end
    end


    default clocking cb @(posedge clk); endclocking
    default disable iff (rst);

    assume_valid_poles : assume property (fr <= 2 && to <= 2);
assume_adjacent: assume property (@(posedge clk) 
    (fr > to ? fr - to : to - fr) == 1
);
    //restrict_not_empty : restrict property (poles[fr][S-1] != 0);

    restrict_depth : restrict property (fr != to);

    logic win;
    assign win = (poles[2][0] == 1 && 
                  poles[2][1] == 2 && 
                  poles[2][2] == 3 && 
                  poles[2][3] == 4);

    cov_main: cover property (win);

endmodule

