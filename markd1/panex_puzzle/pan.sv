
module pan #(parameter S = 3)
(
  input logic clk,
  input logic rst,
  input logic[1:0] fr,
  input logic[1:0] to
  );
  // niz za svaki stap
  logic[$clog2(S*2):0] left_stick [S:0];
  logic[$clog2(S*2):0] left_stick_next [S:0];
  logic[$clog2(S*2):0] right_stick  [S:0];
  logic[$clog2(S*2):0] right_stick_next [S:0];
  logic[$clog2(S*2):0] neutral_stick  [S:0];
  logic[$clog2(S*2):0] neutral_stick_next [S:0];

  const logic[$clog2(S):0] one = 1;

  const logic[$clog2(S):0] s_converted = S;

  typedef enum logic [1:0] {IDLE = 2'b00, PUT_DISK = 2'b01, DONE = 2'b10, FINISH = 2'b11} state_t;
  state_t curr_state;
  state_t next_state;


  logic found_left,found_neutral,found_right;
  logic[$clog2(S):0] index_left, index_neutral, index_right;

  logic[$clog2(S):0] neutral_stick_minus_s, left_stick_minus_s, right_stick_minus_s;
  logic[$clog2(S):0] index_neutral_minus_one, index_left_minus_one, index_right_minus_one;
  logic[$clog2(S):0] left_stick_index_left,right_stick_index_right, neutral_stick_index_neutral;

  logic game_finished;

  // Sequential logic
  always_ff @(posedge clk) begin
    if (rst) begin
      curr_state <= IDLE;

      for (int i = 1; i <= S; i++) begin
        left_stick[i]    <= i;
	neutral_stick[i] <= 0;
        right_stick[i]   <= i + S;
      end
        left_stick[0]    <= 0;
	neutral_stick[0] <= 0;
        right_stick[0]   <= 0;
    end
    else begin
      curr_state <= next_state;
        for (int i = 0; i <= S; i++) begin
          left_stick[i]    <= left_stick_next[i]; 
	  neutral_stick[i] <= neutral_stick_next[i];
          right_stick[i]   <= right_stick_next[i];
        end

    end
  end 


  // FSM 
  always_comb begin

      next_state <= curr_state;
        for (int i = 0; i <= S; i++) begin
          left_stick_next[i]    <= left_stick[i]; 
	  neutral_stick_next[i] <= neutral_stick[i];
          right_stick_next[i]   <= right_stick[i];
        end


     case (curr_state)

	IDLE: begin
		next_state <= PUT_DISK;
	end

        // Write in next cycle
        PUT_DISK: begin
		if (game_finished) begin
			next_state <= DONE;
		end else
		// From Left to Neutral stick
		if (fr == 2'b00 && to == 2'b01) begin
			if (found_left && found_neutral) begin
				if ( index_neutral != 0 ) begin
					if (left_stick[index_left] > S) begin
						if (left_stick_minus_s >= index_neutral) begin
							// upisi na index_neutral - 1
							neutral_stick_next[index_neutral_minus_one] <= left_stick[index_left];
						end
						else begin
							// upisi na lokaciju koja je u index_left
							neutral_stick_next[left_stick_minus_s] <= left_stick[index_left];
						end
					end else begin
						if (left_stick[index_left] >= index_neutral) begin
							// upisi na index_neutral - 1
							neutral_stick_next[index_neutral_minus_one] <= left_stick[index_left];
						end
						else begin
							// upisi na lokaciju koja je u index_left
							neutral_stick_next[left_stick_index_left] <= left_stick[index_left];
						end
					end
					left_stick_next[index_left] <= 0;
					next_state <= PUT_DISK;
				end else begin
					// first location is having disk, invalid move 
					next_state <= IDLE;
				end
			// neutral stick is emprty
			end else if (found_left && !found_neutral) begin
				if (left_stick[index_left] > S) begin
					neutral_stick_next[left_stick_minus_s] <= left_stick[index_left];
				end else begin
					neutral_stick_next[ left_stick_index_left ] <= left_stick[index_left];
				end
				left_stick_next[index_left] <= 0;
				next_state <= PUT_DISK;
			end else begin
				// invalid combination
				next_state <= IDLE;
			end
		end
		// From Neutral to Left stick 
		else if (fr == 2'b01 && to == 2'b00) begin
			if (found_left && found_neutral) begin
				if ( index_left != 0 ) begin
					if (neutral_stick[index_neutral] > S) begin
						if (neutral_stick_minus_s >= index_left) begin
							// upisi na index_left - 1
							left_stick_next[index_left_minus_one] <= neutral_stick[index_neutral];
						end
						else begin
							// upisi na lokaciju
							left_stick_next[neutral_stick_minus_s] <= neutral_stick[index_neutral];
						end
					end else begin
						if (neutral_stick[index_neutral] >= index_left) begin
							// upisi na index_left - 1
							left_stick_next[index_left_minus_one] <= neutral_stick[index_neutral];
						end
						else begin
							// upisi na lokaciju 
							left_stick_next[neutral_stick_index_neutral] <= neutral_stick[index_neutral];
						end
					end
					neutral_stick_next[index_neutral] <= 0;
					next_state <= PUT_DISK;
				end else begin
					// first location is having disk, invalid move 
					next_state <= IDLE;
				end
			// left stick is empty
			end else if (!found_left && found_neutral) begin
				if (neutral_stick[index_neutral] > S) begin
					left_stick_next[neutral_stick_minus_s] <= neutral_stick[index_neutral];
				end else begin
					left_stick_next[ neutral_stick_index_neutral ] <= neutral_stick[index_neutral];
				end
				neutral_stick_next[index_neutral] <= 0;
				next_state <= PUT_DISK;
			end else begin
				// invalid combination
				next_state <= IDLE;
			end
		end
		// From Neutral to Right stick
		else if (fr == 2'b01 && to == 2'b10) begin
			if (found_right && found_neutral) begin
				// check if right stick is having space to put disk
				if (index_right != 0) begin
					if (neutral_stick[index_neutral] > S) begin
						if (neutral_stick_minus_s >= index_right) begin
							// upisi na index_right - 1
							right_stick_next[index_right_minus_one] <= neutral_stick[index_neutral];
						end
						else begin
							// upisi na lokaciju 
							right_stick_next[neutral_stick_minus_s] <= neutral_stick[index_neutral];
						end
					end else begin
						if (neutral_stick[index_neutral] >= index_right) begin
							// upisi na index_right - 1
							right_stick_next[index_right_minus_one] <= neutral_stick[index_neutral];
						end
						else begin
							// upisi na lokaciju koja je u index_left
							right_stick_next[neutral_stick_index_neutral] <= neutral_stick[index_neutral];
						end
					end
					neutral_stick_next[index_neutral] <= 0;
					next_state <= PUT_DISK;
				end else begin
					// first location is having disk, invalid move 
					next_state <= IDLE;
				end
			// right stick is empty
			end else if (!found_right && found_neutral) begin
				if (neutral_stick[index_neutral] > S) begin
					right_stick_next[neutral_stick_minus_s] <= neutral_stick[index_neutral];
				end else begin
					right_stick_next[ neutral_stick_index_neutral ] <= neutral_stick[index_neutral];
				end
				neutral_stick_next[index_neutral] <= 0;
				next_state <= PUT_DISK;
			end else begin
				// invalid combination
				next_state <= IDLE;
			end
		end
		// From Right to Neutral stick 
		else if (fr == 2'b10 && to == 2'b01) begin
			if (found_right && found_neutral) begin
				if ( index_neutral != 0 ) begin
					if (right_stick[index_right] > S) begin
						if (right_stick_minus_s >= index_neutral) begin
							// upisi na index_neutral - 1
							neutral_stick_next[index_neutral_minus_one] <= right_stick[index_right];
						end
						else begin
							// upisi na lokaciju 
							neutral_stick_next[right_stick_minus_s] <= right_stick[index_right];
						end
					end else begin
						if (right_stick[index_right] >= index_neutral) begin
							// upisi na index_neutral - 1
							neutral_stick_next[index_neutral_minus_one] <= right_stick[index_right];
						end
						else begin
							// upisi na lokaciju koja je u index_right
							neutral_stick_next[right_stick_index_right] <= right_stick[index_right];
						end
					end
					right_stick_next[index_right] <= 0;
					next_state <= PUT_DISK;
				end else begin
					// first location is having disk, invalid move 
					next_state <= IDLE;
				end
			// neutral stick is empty
			end else if (found_right && !found_neutral) begin
				if (right_stick[index_right] > S) begin
					neutral_stick_next[right_stick_minus_s] <= right_stick[index_right];
				end else begin
					neutral_stick_next[right_stick_index_right] <= right_stick[index_right];
				end
				right_stick_next[index_right] <= 0;
				next_state <= PUT_DISK;
			end else begin
				next_state <= PUT_DISK;
			end
		end
		// Invalid combination
		else begin
			next_state <= IDLE;
		end
        end

	DONE: begin
		//if (game_finished) begin
			next_state <= DONE;
		//end else begin
		//	next_state <= PUT_DISK;
		//end
	end

	default: next_state <= PUT_DISK;

      endcase
  end
  // indexes  used for accessing disks - used because bit width was not same
  assign right_stick_minus_s = right_stick[index_right] - s_converted;
  assign left_stick_minus_s = left_stick[index_left] - s_converted;
  assign neutral_stick_minus_s = neutral_stick[index_neutral] - s_converted;

  assign index_neutral_minus_one = index_neutral - one;
  assign index_left_minus_one = index_left - one;
  assign index_right_minus_one = index_right - one;

  assign left_stick_index_left       = /*left_stick[index_left] < S ? */left_stick[index_left];
  assign right_stick_index_right     = /*right_stick[index_right] < S ? */right_stick[index_right]; 
  assign neutral_stick_index_neutral = /*neutral_stick[index_neutral] < S ? */neutral_stick[index_neutral] ;

  // Search left stick for first disk
  always_comb begin
    found_left = 0;
    index_left = 0;

    for (int i = 0; i <= S; i++) begin
      if (left_stick[i] != 0 && found_left == 0) begin
        found_left = 1;
        index_left = i;
      end
    end
  end
  // Search neutral stick for first disk 
  always_comb begin
    found_neutral = 0;
    index_neutral = 0;

    for (int i = 0; i <= S; i++) begin
      if (neutral_stick[i] != 0 && found_neutral == 0) begin
        found_neutral = 1;
        index_neutral = i;
      end
    end
  end
  // Search right stick for first disk 
  always_comb begin
    found_right = 0;
    index_right = 0;

    for (int i = 0; i <= S; i++) begin
      if (right_stick[i] != 0 && found_right == 0) begin
        found_right = 1;
        index_right = i;
      end
    end
  end

  // Logic for end of game
  always_comb begin
    game_finished = 1'b1;

    for (int j = 1; j <= S; j++) begin
        if (left_stick[j] != j + S || neutral_stick[j] != 0 || right_stick[j] != j) begin
            game_finished = 1'b0;
	end
    end
  end


	default clocking
		 @(posedge clk);
	endclocking
		
	default disable iff (rst);

  	finish: cover property (game_finished);
	//done: cover property (curr_state == DONE ##1 curr_state == DONE ##1 curr_state == DONE);
	// for testing
	l1111:cover property (neutral_stick[1] == 1);
	l1:cover property (left_stick[1] == 4);
	l2:cover property (left_stick[2] == 5);
	l3:cover property (left_stick[3] == 6 && right_stick[3] == 3);

	no_fr_11: assume property ( fr != 2'b11 );
		
	no_tr_11: assume property ( to != 2'b11 ); 
		
	no_same_stick: assume property ( fr != to );

	no_direct_from_left_to_right: assume property ( fr == 2'b00 |-> to != 2'b10 );

	no_direct_from_right_to_left: assume property ( fr == 2'b10 |-> to != 2'b00 );

	// strangely tool works faster without these assumptions ??
/*
	assume property ( !found_right && curr_state == PUT_DISK |-> fr != 2'b10 );

	assume property ( !found_left && curr_state == PUT_DISK |-> fr != 2'b00 );

	assume property ( !found_neutral && curr_state == PUT_DISK |-> fr != 2'b01 );

	assume property ( left_stick[0] != 0 && curr_state == PUT_DISK |-> to != 2'b00 );
	assume property ( neutral_stick[0] != 0 && curr_state == PUT_DISK |-> to != 2'b01 );
	assume property ( right_stick[0] != 0 && curr_state == PUT_DISK |-> to != 2'b10 );
*/
	//assume property ( curr_state == PUT_DISK |=> $stable(fr) until curr_state == DONE);
	//assume property ( curr_state == PUT_DISK |=> $stable(to) until curr_state == DONE); 


endmodule 
