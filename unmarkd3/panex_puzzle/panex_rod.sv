module panex #(parameter S=4)
(
    input clk,
    input rst,
    input [1:0] fr,
    input [1:0] to
);

// left tower  <=> tower0
// right tower <=> tower1

// The number of bits needed to represent S disk positions + 1 (for the road)
// disks are enumerated from 1 to S
localparam int W = $clog2(S+1);

//2 upper bits tell us which tower the piece belongs to or
//if the position is free while [W-1:0] bits tells us disk size
// 00 => empty slot 01 => tower0 10 => tower1
logic [W+1:0] rod0[0:S];
logic [W+1:0] rod1[0:S];
logic [W+1:0] rod2[0:S];

// flag for game over
bit game_won;
bit tower0_switched;
bit tower1_switched;

// valid disk values = [1...S]
// invalid disk value = 0
logic [W+1:0] fr_disk;
logic [W-1:0] fr_pos;
logic [W-1:0] to_pos;

logic [W+1:0] curr_from;
logic [W+1:0] curr_to;

//Change position of disks
always_ff @(posedge clk) begin
    if (rst) begin
        // Initialize rod positions => upper 2 bits meaning
        // 00 => empty | pos 01 => tower0 | 10 => tower1
        for (int i = 0; i <= S; ++i) begin
            if (i == 0) begin
                rod0[i] <= 0; 
                rod1[i] <= 0;
                rod2[i] <= 0;
            end
            else begin
		rod1[i] <= 0;

                rod0[i][W+1:W] <= 2'b01; 
                rod2[i][W+1:W] <= 2'b10;
                rod0[i][W-1:0] <= i;
                rod2[i][W-1:0] <= i;
            end
        end
    end
    else begin
        // If there was a valid input move chosen disk
        case (to)
        2'b00: rod0[to_pos] <= fr_disk;
        2'b01: rod1[to_pos] <= fr_disk;
        2'b10: rod2[to_pos] <= fr_disk;
        endcase

        case (fr)
        2'b00: rod0[fr_pos] <= 0;
        2'b01: rod1[fr_pos] <= 0;
        2'b10: rod2[fr_pos] <= 0;
        endcase
    end
end

default clocking @(posedge clk); endclocking
default disable iff (rst);

//get disk on top of rod fr and disk on top of rod to
always_comb begin
    //assume there are no disks on chosen to and from rod initially
    fr_disk = 0;
    to_pos = S;
    fr_pos = S;

    for (int i = S; i >= 0; --i) begin

	case (fr)
		2'b00: curr_from = rod0[i];
		2'b01: curr_from = rod1[i];
		2'b10: curr_from = rod2[i];
		default: curr_from = 0;
	endcase

	case (to)
		2'b00: curr_to = rod0[i];
		2'b01: curr_to = rod1[i];
		2'b10: curr_to = rod2[i];
		default: curr_to = 0;
	endcase

        // smallest disk wins (top of stack)
        if (curr_from[W+1:W] != 2'b00) begin
            fr_disk = curr_from;
            fr_pos = i;
        end

        //free spot is above a taken one
        if (i > 0) begin
            if (curr_to[W+1:W] != 2'b00)
                to_pos = i-1;
        end 
        else begin
            if (curr_to[W+1:W] != 2'b00) begin
                //invalid value since there is no space on rod_to
                fr_disk = 0;
            end
            else if (rod1[0][W+1:W] != 2'b00 && fr != 1) begin
                //invalid value since there is a block in the middle rod
                fr_disk = 0;
            end
        end
    end

    if (to_pos > fr_disk[W-1:0])
        to_pos = fr_disk[W-1:0];
end


always_comb begin
    game_won = 1'b0;
    tower0_switched = 1'b1;
    tower1_switched = 1'b1;

    for (int i = 1; i <= S; ++i) begin
        if (rod0[i][W+1:W] != 2'b10 || rod0[i][W-1:0] != i)
            tower0_switched = 1'b0;

        if (rod2[i][W+1:W] != 2'b01 || rod2[i][W-1:0] != i)
            tower1_switched = 1'b0;
    end

    if (tower0_switched && tower1_switched)
        game_won = 1'b1;
end

// limit the choice of input fr and to for valid input
restrict property (fr >= 0 && fr < 3);
restrict property (to >= 0 && to < 3);
restrict property (fr != to);

restrict property (fr_disk != 0); 

cover property (game_won);

endmodule
