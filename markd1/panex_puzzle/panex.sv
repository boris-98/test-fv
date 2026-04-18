

module panex #(parameter S = 3)
(
  input logic clk,
  input logic rst,
  input logic[1:0] fr,
  input logic[1:0] to
  );

  // niz za svaki stap
  logic[$clog2(S*2)-1:0] left_stick [S:0];
  logic[$clog2(S*2)-1:0] left_stick_next [S:0];
  logic[$clog2(S*2)-1:0] right_stick  [S:0];
  logic[$clog2(S*2)-1:0] right_stick_next [S:0];
  logic[$clog2(S*2)-1:0] neutral_stick  [S:0];
  logic[$clog2(S*2)-1:0] neutral_stick_next [S:0];
  // brojac koji ce da ide kroz stapove - ograniciti da broji do S
  logic[$clog2(S)-1:0] counter_ls, counter_ls_next;
  logic[$clog2(S)-1:0] counter_ns, counter_ns_next;
  logic[$clog2(S)-1:0] counter_rs, counter_rs_next;

  //logic[$clog2(S)-1:0] counter, counter_next;
  
  // registar koji govori da li je vrednost diska veca od S
  logic disk_from_right_stick_flag,disk_from_right_stick_flag_next;
  // ako jeste, konvertuj vrednost da bude u rangu od 0 do S
  logic[$clog2(S*2)-1:0] moved_disk_converted_num, moved_disk_converted_num_next;
  // registar za disk koji se prenosi
  logic[$clog2(S*2)-1:0] moved_disk_number, moved_disk_number_next;

  logic[$clog2(S*2)-1:0] right_stick_real_num, right_stick_real_num_next;

  logic neutral_stick_empty_flag;

  const logic[$clog2(S)-1:0] one = 1;

  const logic[$clog2(S)-1:0] s_converted = S;

 
  // FSM
  typedef enum logic [2:0] {IDLE = 3'b000, TAKE_DISK = 3'b001, PUT_DISK = 3'b010, DONE = 3'b011, FINISH = 3'b100} state_t;
  state_t curr_state;
  state_t next_state;
  
  // invalid flag
  logic invalid_move_reg, invalid_move_next;
  
  logic game_finished;

  // sekvencijalna logika
  always_ff@(posedge clk) begin
	
	if (rst) begin
		for (int i = 1; i <= S; i++) begin
		  left_stick[i]     <= i;
		  right_stick[i]    <= i + S;
		  neutral_stick[i]  <= 0;
		end
		// prva lokacija sa sva tri stapa je uvek nula
		left_stick[0]     <= 0;
		right_stick[0]    <= 0;
		neutral_stick[0]  <= 0;
		counter_ls <= 0;
		counter_rs <= 0;
		counter_ns <= 0;
	//	counter <= 0;
		moved_disk_number <= 0;
		moved_disk_converted_num <= 0;	
		right_stick_real_num <= 0;
		invalid_move_reg <= 0;
		disk_from_right_stick_flag <= 0;	
		curr_state <= IDLE;
	end 
	else begin
		curr_state <= next_state;
		counter_ls <= counter_ls_next;
		counter_rs <= counter_rs_next;
		counter_ns <= counter_ns_next;
	//	counter <= counter_next;
		moved_disk_number <= moved_disk_number_next;
		moved_disk_converted_num <= moved_disk_converted_num_next;
		right_stick_real_num <= right_stick_real_num_next;
		disk_from_right_stick_flag <= disk_from_right_stick_flag_next;
		invalid_move_reg <= invalid_move_next;
		for (int i = 0; i <= S; i++) begin
		  left_stick[i]     <= left_stick_next[i];
		  right_stick[i]    <= right_stick_next[i];
		  neutral_stick[i]  <= neutral_stick_next[i];
		end
	end // if rst
  end // always

  always_comb begin
	// default values
	next_state = curr_state;
	counter_ls_next = counter_ls;
	counter_ns_next = counter_ns;
	counter_rs_next = counter_rs;
//	counter_next = counter;
	moved_disk_number_next        = moved_disk_number;
	moved_disk_converted_num_next = moved_disk_converted_num;

	right_stick_real_num_next = right_stick_real_num;
	invalid_move_next = invalid_move_reg;

	disk_from_right_stick_flag_next = disk_from_right_stick_flag;
	for (int i = 0; i <= S; i++) begin
		left_stick_next[i]     = left_stick[i];
		right_stick_next[i]    = right_stick[i];
		neutral_stick_next[i]  = neutral_stick[i];
	end

	//invalid_move = 0;

	case (curr_state)
		
	IDLE: begin
		next_state = TAKE_DISK;
	end
		
	TAKE_DISK: begin
		if (game_finished) begin
			next_state = FINISH;
		end
		else if (fr == 2'b00) begin
			if (left_stick[counter_ls] == 0) begin
				// stap je prazan
				if (counter_ls == S) begin
					next_state = DONE;
				end
				else begin
					next_state = TAKE_DISK;
					counter_ls_next = counter_ls + one;
				end
			end
			else begin
				next_state = PUT_DISK;
				//moved_disk_number_next <= neutral_stick[counter_ls];
				if (left_stick[counter_ls] > S) begin
					disk_from_right_stick_flag_next    = 1;
					moved_disk_number_next = left_stick[counter_ls] - s_converted;
					right_stick_real_num_next = left_stick[counter_ls];
				end else begin
					moved_disk_number_next = left_stick[counter_ls];
				end
				// obrisi disk sa te lokacije
				//left_stick_next[counter_ls] = 0;
				// reset brojaca
				//counter_ls_next = 0;						
			end
		end
		else if (fr == 2'b01) begin
			if (neutral_stick[counter_ns] == 0) begin
				// stap je prazan
				if (counter_ns == S) begin
					next_state = DONE;
				end
				else begin
					next_state = TAKE_DISK;
					counter_ns_next = counter_ns + one;
				end
			end
			else begin
				next_state = PUT_DISK;
				//moved_disk_number_next <= neutral_stick[counter_ns];
				if (neutral_stick[counter_ns] > S) begin
					disk_from_right_stick_flag_next    = 1;
					moved_disk_number_next = neutral_stick[counter_ns] - s_converted;
					right_stick_real_num_next = neutral_stick[counter_ns];
				end else begin
					moved_disk_number_next = neutral_stick[counter_ns];
				end
				// obrisi disk sa te lokacije
				//neutral_stick_next[counter] = 0;
				//counter_ns_next = 0;						
			end			
		end
		else if (fr == 2'b10) begin
			if (right_stick[counter_rs] == 0) begin
				// stap je prazan
				if (counter_rs == S) begin
					next_state = DONE;
				end
				else begin
					next_state = TAKE_DISK;
					counter_rs_next = counter_rs + one;
				end
			end
			else begin
				next_state = PUT_DISK;
				//moved_disk_number_next <= right_stick[counter_rs];
				if (right_stick[counter_rs] > S) begin
					disk_from_right_stick_flag_next    = 1;
					moved_disk_number_next = right_stick[counter_rs] - s_converted;
					right_stick_real_num_next = right_stick[counter_rs];
				end else begin
					moved_disk_number_next = right_stick[counter_rs];
				end
				// obrisi disk sa te lokacije
				//right_stick_next[counter] = 0;	
				//counter_rs_next = 0;					
			end			
		end // if fr	
		
	end // take_disk

	PUT_DISK: begin
		// Left stick 
		if (to == 2'b00) begin
			if (left_stick[counter_ls] == 0) begin
				if (counter_ls == moved_disk_number || counter_ls == S ) begin
					// put disk at this location 
					if (disk_from_right_stick_flag) begin
						left_stick_next[counter_ls] = moved_disk_number + s_converted;
					end else begin
						left_stick_next[counter_ls] = moved_disk_number;
					end
					next_state = DONE;
					// remove disk from previous location
					if ( fr == 2'b01) begin
						neutral_stick_next[counter_ns] = 0;
					end
					else if ( fr == 2'b10) begin
						right_stick_next[counter_rs] = 0;
					end
				end
				else if (counter_ls < moved_disk_number && left_stick[counter_ls+one] == 0 && counter_ls < S ) begin
					// go to next location
					counter_ls_next = counter_ls + one;
					next_state = PUT_DISK;
				end
				else if (counter_ls < moved_disk_number && left_stick[counter_ls+one] != 0 && counter_ls < S ) begin
					// put disk at this location
					if (disk_from_right_stick_flag) begin
						left_stick_next[counter_ls] = moved_disk_number + s_converted;
					end else begin
						left_stick_next[counter_ls] = moved_disk_number;
					end
					next_state = DONE;
					// remove disk from previous location
					if ( fr == 2'b01) begin
						neutral_stick_next[counter_ns] = 0;
					end
					else if ( fr == 2'b10) begin
						right_stick_next[counter_rs] = 0;
					end
				end
				else if (counter_ls > moved_disk_number) begin
					// invalid 
        				invalid_move_next = 1;
       					next_state = DONE;
				end
			end else begin
      				invalid_move_next = 1;
       				next_state = DONE;
			end
		end
		// Neutral Stick 
		else if (to == 2'b01) begin
			if (neutral_stick[counter_ns] == 0) begin
				if (counter_ns == moved_disk_number || counter_ns == S ) begin
					// put disk at this location 
					if (disk_from_right_stick_flag) begin
						neutral_stick_next[counter_ns] = moved_disk_number + s_converted;
					end else begin
						neutral_stick_next[counter_ns] = moved_disk_number;
					end
					next_state = DONE;
					// remove disk from previous location
					if ( fr == 2'b00) begin
						left_stick_next[counter_ls] = 0;
					end
					else if ( fr == 2'b10) begin
						right_stick_next[counter_rs] = 0;
					end
				end
				else if (counter_ns < moved_disk_number && neutral_stick[counter_ns+one] == 0 && counter_ns < S ) begin
					// go to next location
					counter_ns_next = counter_ns + one;
					next_state = PUT_DISK;
				end
				else if (counter_ns < moved_disk_number && neutral_stick[counter_ns+one] != 0 && counter_ns < S ) begin
					// put disk at this location
					if (disk_from_right_stick_flag) begin
						neutral_stick_next[counter_ns] = moved_disk_number + s_converted;
					end else begin
						neutral_stick_next[counter_ns] = moved_disk_number;
					end
					next_state = DONE;
					// remove disk from previous location
					if ( fr == 2'b00) begin
						left_stick_next[counter_ls] = 0;
					end
					else if ( fr == 2'b10) begin
						right_stick_next[counter_rs] = 0;
					end
				end
				else if (counter_ns > moved_disk_number) begin
					// invalid 
        				invalid_move_next = 1;
       					next_state = DONE;
				end
			end else begin
      				invalid_move_next = 1;
       				next_state = DONE;
			end
		end
		// Right Stick 
		else if (to == 2'b10) begin
			if (right_stick[counter_rs] == 0) begin
				if (counter_rs == moved_disk_number || counter_rs == S ) begin
					// put disk at this location 
					if (disk_from_right_stick_flag) begin
						right_stick_next[counter_rs] = moved_disk_number + s_converted;
					end else begin
						right_stick_next[counter_rs] = moved_disk_number;
					end
					next_state = DONE;
					// remove disk from previous location
					if ( fr == 2'b00) begin
						left_stick_next[counter_ls] = 0;
					end
					else if ( fr == 2'b01) begin
						neutral_stick_next[counter_ns] = 0;
					end
				end
				else if (counter_rs < moved_disk_number && right_stick[counter_rs+one] == 0 && counter_rs < S ) begin
					// go to next location
					counter_rs_next = counter_rs + one;
					next_state = PUT_DISK;
				end
				else if (counter_rs < moved_disk_number && right_stick[counter_rs+one] != 0 && counter_rs < S ) begin
					// put disk at this location
					if (disk_from_right_stick_flag) begin
						right_stick_next[counter_rs] = moved_disk_number + s_converted;
					end else begin
						right_stick_next[counter_rs] = moved_disk_number;
					end
					next_state = DONE;
					// remove disk from previous location
					if ( fr == 2'b00) begin
						left_stick_next[counter_ls] = 0;
					end
					else if ( fr == 2'b01) begin
						neutral_stick_next[counter_ns] = 0;
					end
				end
				else if (counter_rs > moved_disk_number) begin
					// invalid 
        				invalid_move_next = 1;
       					next_state = DONE;
				end
			end else begin
      				invalid_move_next = 1;
       				next_state = DONE;
			end
		end // if to
	end // put disk

	DONE: begin
		// vrati uzet disk na svoje mesto
		if (invalid_move_reg == 1) begin
/*
			if (fr == 2'b00) begin		
					if (disk_from_right_stick_flag) begin
						left_stick_next[moved_disk_number] = right_stick_real_num; //moved_disk_number + s_converted;					
					end else begin
						left_stick_next[moved_disk_number] = moved_disk_number;					
					end	
			end
			else if (fr == 2'b01) begin
					if (disk_from_right_stick_flag) begin
						neutral_stick_next[moved_disk_number] = right_stick_real_num; //moved_disk_number + s_converted;					
					end else begin
						neutral_stick_next[moved_disk_number] = moved_disk_number;					
					end
			end			
			else if (fr == 2'b10) begin
					if (disk_from_right_stick_flag) begin
						right_stick_next[moved_disk_number] = right_stick_real_num; // moved_disk_number + s_converted;					
					end else begin
						right_stick_next[moved_disk_number] = moved_disk_number;					
					end
			end	
			invalid_move_next = 0;	
*/			
			invalid_move_next = 0;
		end	

		disk_from_right_stick_flag_next = 0;		
			
		// reset counters
		counter_ls_next = 0;
		counter_rs_next = 0;
		counter_ns_next = 0;
		
	//	counter_next = 0;
		// obrisi disk sa stare lokacije
			
		// 
		if (game_finished) begin
			next_state = FINISH;
		end else begin
			next_state = TAKE_DISK;
		end
					
	end
			
	FINISH: begin
		next_state = FINISH;
	end

	default: next_state = IDLE;

	endcase

  end // always
	

  // logika koja odreduje da li se igra zavrsila 
  always_comb begin
    game_finished = 1'b0;
/*
    for (int j = 1; j <= S; j++) begin
        if (/*left_stick[j] != j + S || neutral_stick[j] != 0 || right_stick[j] != j) begin
            game_finished = 1'b0;
	end
    end
*/
	if ( right_stick[1] == 1 && right_stick[2] == 2 && right_stick[3] == 3 ) begin
		game_finished = 1'b1;
	end
  end

  always_comb begin
    neutral_stick_empty_flag = 1'b1;

    for (int j = 0; j <= S; j++) begin
        if (neutral_stick[j] != 0) begin
            neutral_stick_empty_flag = 1'b0;
	end
    end
  end

	default clocking
		 @(posedge clk);
	endclocking
		
	default disable iff (rst);
		
	no_fr_11: assume property ( fr != 2'b11 );
		
	no_tr_11: assume property ( to != 2'b11 ); 
		
	no_same_stick: assume property ( fr != to );

	no_direct_from_left_to_right: assume property ( fr == 2'b00 |-> to != 2'b10 );

	no_direct_from_right_to_left: assume property ( fr == 2'b10 |-> to != 2'b00 );

	assume property ( curr_state == TAKE_DISK |=> $stable(fr) until curr_state == DONE);// ##1 curr_state == TAKE_DISK) );
	assume property ( curr_state == TAKE_DISK |=> $stable(to) until curr_state == DONE); // ##1 curr_state == TAKE_DISK) );

	assume property (counter_ls <= S);
	assume property (counter_ns <= S);
	assume property (counter_rs <= S);

	//assume property (counter <= S);
	//assume property (counter_next <= S);

	//assume property ( neutral_stick_empty_flag == 1 && curr_state == DONE |=> fr != 2'b01);
	//assume property ( neutral_stick_empty_flag == 1 && curr_state == DONE |=> fr != 2'b01);
logic [1:0] prev_fr, prev_to;
/*
always_ff @(posedge clk)
    if (!rst && curr_state == DONE) begin
        prev_fr <= fr;
        prev_to <= to;
    end

assume property (
    curr_state == TAKE_DISK |->
        !(fr == prev_to && to == prev_fr)
);
*/
	genvar i;
	generate
		for (i=0; i<= S; i++) begin
			assume property (
  				left_stick[i] inside {[0:2*S]}
			);
			assume property (
  				neutral_stick[i] inside {[0:2*S]}
			);
			assume property (
  				right_stick[i] inside {[0:2*S]}
			);
		end
	endgenerate

	genvar k;
	generate
		for (k=0; k<= S; k++) begin
			assume property (
  				left_stick_next[k] inside {[0:2*S]}
			);
			assume property (
  				neutral_stick_next[k] inside {[0:2*S]}
			);
			assume property (
  				right_stick_next[k] inside {[0:2*S]}
			);
		end
	endgenerate
//	no_free_space_on_stick: assume property ( left_stick[0] != 0 && curr_state == DONE |-> to != 2'b00);
 
	cover_game_is_finished: cover property (curr_state == FINISH |=> curr_state == FINISH );

	kkk: cover property (game_finished );

cover property (
    curr_state == IDLE ##[1:500] curr_state == FINISH
);
/*
	property p1;
		( $changed(fr) |=> fr [*S] );
	endproperty
	pp: assume property (p1);
*/
endmodule

