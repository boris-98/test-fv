module puzzle    #(parameter S = 4)
    (
	input clk,
	input rst,
	input [1:0] fr,
	input [1:0] to);

int stapovi [2:0][S:0];
int zbir, zbir_0, zbir_1, zbir_2;
int tmp;
logic stap0_is0, stap1_is0, stap2_is0;

always @ (posedge clk) begin
	if (rst) begin
		for(int k=0; k<=S; k++) begin
		    stapovi[0][k] <= k;
		    stapovi[1][k] <= 0;
		    stapovi[2][k] <= k+S;
		end
		stapovi[0][0] <= 0;
		stapovi[2][0] <= 0;			
	end
    else begin
		//brisanje diska sa stapa fr
		for(int i=0; i<=S; i++) begin
			if(stapovi[fr][i] != 0) begin
				tmp = stapovi[fr][i]; 
				stapovi[fr][i] <= 0;		
				break;
			end
		end
		//dodavanje diska na stap to
		for(int j=1; j<=S; j++) begin
			if(stapovi[to][j] != 0) begin
				stapovi[to][--j] <= tmp;
				break;
			end
			if((j == S) || (j == tmp%S)) begin
				stapovi[to][j] <= tmp;
				break;
			end
		end	
	end
end

always_comb begin	
	zbir_0 = 0;
	zbir_1 = 0;
	zbir_2 = 0;

	for(int z=0; z<=S; z++) begin
		zbir_0 = zbir_0 + stapovi[0][z];
		zbir_1 = zbir_1 + stapovi[1][z];
		zbir_2 = zbir_2 + stapovi[2][z];
	end
end


assign zbir = zbir_0 + zbir_1 + zbir_2;
assign stap0_is0 = (zbir_0 == 0) ? 1'b1 : 1'b0;
assign stap1_is0 = (zbir_1 == 0) ? 1'b1 : 1'b0;
assign stap2_is0 = (zbir_2 == 0) ? 1'b1 : 1'b0;

default clocking
	@(posedge clk);
endclocking

default disable iff (rst);

//za 4 diska zbir mora biti 1+2+3+4+5+6+7+8 = 36
//assert_zbir36 : 
	//assert property (zbir == 36);

//restrict from mora da je razlicito od to
assume_razliciti_ulazi: 
	restrict property(fr != to);

//from i to uzimaju vrednost 0 1 2
assume_input012 :
      restrict property (fr != 2'b11 && to != 2'b11);

//ne moze da se prebacuje sa praznog stapa
assume_from_prazan_0:
	restrict property (stap0_is0 |-> fr != 2'b00);
assume_from_prazan_1:
	restrict property (stap1_is0 |-> fr != 2'b01);
assume_from_prazan_2:
	restrict property (stap2_is0 |-> fr != 2'b10);

//ne moze da se prebacuje na stap koji ima disk na vrhu 
assume_to_ogranicenje_0:
	restrict property (stapovi[0][0] != 0 |-> to != 2'b00);
assume_to_ogranicenje_2:
	restrict property (stapovi[2][0] != 0 |-> to != 2'b10);

//ne moze da se prebacuje na srednji stap ako na poz 1 (srednjeg stapa) postoji disk, ako bi to uradili zablokirali bi prolaza tj ne bi mogli da prebacujemo sa 0 na 2 i obrnuto
assume_to_ogranicenje_1:
	restrict property (stapovi[1][1] != 0 |-> to != 2'b01);

//pocetni cover
cov_start:
	cover property(stapovi[0][0] == 0 && stapovi[0][1] == 1 && stapovi[0][2] == 2 && stapovi[0][3] == 3 && stapovi[0][4] == 4 && stapovi[2][0] == 0 && stapovi[2][1] == 5 && stapovi[2][2] == 6 && stapovi[2][3] == 7 && stapovi[2][4] == 8);

//ciljni cover
cov_finish:
	cover property(stapovi[0][0] == 0 && stapovi[0][1] == 5 && stapovi[0][2] == 6 && stapovi[0][3] == 7 && stapovi[0][4] == 8 && stapovi[2][0] == 0 && stapovi[2][1] == 1 && stapovi[2][2] == 2 && stapovi[2][3] == 3 && stapovi[2][4] == 4);


endmodule
