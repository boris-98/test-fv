module panex #(parameter S=4)
	(
	input clk,
	input rst,
	input [1:0] fr,
	input [1:0] to);

// Map each disk to a rod 0 1 2
logic [1:0] disks[0:S-1];
// flag for game over
bit game_won;

// valid disk values = [0...S-1]
// invalid disk value = S => there is no disk on the chosen rod
integer fr_disk; //disk on top of fr rod
integer to_disk; //disk on top of to rod

//Change position of disks
always_ff @(posedge clk) begin
        // At the start all disks are on the leftmost rod '0'
		if(rst) begin
			for(int i = 0; i < S; ++i)
				disks[i] <= 2'd0;
		end
        // If there was a valid input move chosen disk
		else begin
			disks[fr_disk] <= to;
		end
end

default clocking @(posedge clk); endclocking
default disable iff (rst);

//get disk on top of rod fr and disk on top of rod to
always_comb begin
        //assume there are no disks on chosen rod initially
		to_disk = S;
		fr_disk = S;

        //start search from biggest to smallest disk 
        //so the final output is the smallest disk
        for(int i = S-1; i >= 0; --i) begin
			if(disks[i] == fr)
				fr_disk = i;

            if(disks[i] == to)
				to_disk = i;
		end
end

always_comb begin
	game_won = 1'd1;
	    for(int i = 0; i < S; ++i) begin
		if(disks[i] != 2'd2)
			game_won = 1'd0;
	    end
end

// limit the choice of input fr and to for valid input
restrict property (fr >= 0 && fr < 3);
restrict property (to >= 0 && to < 3);
restrict property (fr != to);

restrict property (fr_disk < to_disk);
restrict property (fr_disk != S);

cover property(game_won);

endmodule
