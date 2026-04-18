library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sort_hw is
    Generic (EL_NUM : integer := 1024;
          DATA_WIDTH : integer := 16;
          ADDR_WIDTH : integer := 10
          
          );
    Port (
           clk: in std_logic;
	   reset: in std_logic;
           -- A_in
           ain_tdata_i:in std_logic_vector(2*DATA_WIDTH-1 downto 0);
           ain_tvalid_i: in std_logic;
           ain_tready_o: out std_logic;
           ain_tlast_i: in std_logic;

           sort_dir_i: in std_logic;
           
           -- A_out
           aout_tdata_o:out std_logic_vector(2*DATA_WIDTH-1 downto 0);
           aout_tvalid_o: out std_logic;
           aout_tready_i: in std_logic;
           aout_tlast_o: out std_logic;
           
           
           dup_cnt_o: out std_logic_vector(ADDR_WIDTH-1 downto 0)
           
           );
end sort_hw;

architecture Behavioral of sort_hw is

    type state_type is (idle, load_array, read_op_phase, comp_and_swap_phase , read_array, dup_counter, ende); 
    signal state_reg, state_next : state_type;
  
 signal idx_reg, idx_next : std_logic_vector(ADDR_WIDTH downto 0);
-- Memory access
   signal we_a_s, we_b_s: std_logic;
   signal wdata_a_s, wdata_b_s, rdata_a_s, rdata_b_s: std_logic_vector(DATA_WIDTH-1 downto 0);
   signal addr_a_s, addr_b_s : std_logic_vector(ADDR_WIDTH-1 downto 0);   

-- even_odd sorting algorithm - helper signals
   signal phase_even_reg, phase_even_next : std_logic; -- '1' even, '0' odd
   signal isSorted_reg, isSorted_next     : std_logic;

-- duplicate counter signals 
   signal dup_cnt_reg, dup_cnt_next:std_logic_vector(ADDR_WIDTH-1 downto 0);
   signal tmp_reg, tmp_next: std_logic_vector(DATA_WIDTH-1 downto 0);

-- pair of the same elements indicator
   signal pair_reg, pair_next: std_logic;

--internal reg - sorting finished?   
   signal sort_fin_reg, sort_fin_next: std_logic; 

-- dual port memory
component dual_port_bram is
    generic (
        g_DATA_WIDTH : integer := 16; -- Width of data bus
        g_ADDR_WIDTH : integer := 8    -- Width of address bus (2^8 = 256 words deep)
    );
    Port (
	rst  : in STD_LOGIC;
        -- Port A
        clk  : in STD_LOGIC;
        we_a    : in STD_LOGIC; -- Write enable A (active high)
        addr_a  : in STD_LOGIC_VECTOR(g_ADDR_WIDTH-1 downto 0);
        di_a    : in STD_LOGIC_VECTOR(g_DATA_WIDTH-1 downto 0); -- Data in A
        do_a    : out STD_LOGIC_VECTOR(g_DATA_WIDTH-1 downto 0); -- Data out A
        -- Port B
        
        we_b    : in STD_LOGIC; -- Write enable B (active high)
        addr_b  : in STD_LOGIC_VECTOR(g_ADDR_WIDTH-1 downto 0);
        di_b    : in STD_LOGIC_VECTOR(g_DATA_WIDTH-1 downto 0); -- Data in B
        do_b    : out STD_LOGIC_VECTOR(g_DATA_WIDTH-1 downto 0)  -- Data out B
    );
end component;

begin
    
    --State and data registers
    process (clk, reset) 
    begin
        if (rising_edge(clk)) then
            if (reset = '1') then
                state_reg <= idle;
                idx_reg <= (others => '0');
	        phase_even_reg <= '1';  -- start with even
	        isSorted_reg   <= '1';                
                dup_cnt_reg <=  (others => '0');
                tmp_reg <=  (others => '0');
                pair_reg <= '0';
                
            --
              sort_fin_reg <= '0';   
            else
                state_reg <= state_next;
                idx_reg <= idx_next;
    		phase_even_reg <= phase_even_next;
      		isSorted_reg   <= isSorted_next;
  		dup_cnt_reg <= dup_cnt_next;
  		tmp_reg <= tmp_next;
  		pair_reg <= pair_next;
  		
  		sort_fin_reg <= sort_fin_next;
            end if;
        end if;
    end process;
    
    
    --Combinatorial circuits
        
    process (state_reg, ain_tvalid_i, ain_tlast_i, sort_dir_i, idx_reg, phase_even_reg, isSorted_reg, tmp_reg, dup_cnt_reg, pair_reg, sort_fin_reg)
    begin
      
      --Default reg
	  
	  state_next      <= state_reg;
	  idx_next        <= idx_reg;
	  phase_even_next <= phase_even_reg;
	  isSorted_next   <= isSorted_reg;
        
      dup_cnt_next <= dup_cnt_reg;
      tmp_next <= tmp_reg;
      pair_next <= pair_reg;  

      sort_fin_next <= sort_fin_reg;

	  ain_tready_o    <= '0';
	  aout_tvalid_o   <= '0';
	  aout_tlast_o    <= '0';
	  aout_tdata_o <= (others=>'0');

	  we_a_s <= '0';
	  we_b_s <= '0';

	  -- default BRAM addr
	  addr_a_s <= idx_reg(ADDR_WIDTH-1 downto 0);
	  addr_b_s <= std_logic_vector(to_unsigned(to_integer(unsigned(idx_reg)) + 1, idx_reg'length - 1));
        
        case state_reg is
        
        when idle =>
        
	    idx_next <= (others => '0');
    	phase_even_next <= '1'; -- first phase -> Even
    	isSorted_next <= '1'; -- at the beginning flag set to '1'

	    sort_fin_next <= '0';
	    dup_cnt_next <= (others=>'0');
	    state_next <= load_array;
---------------------------------------------------------------------------------------------------------------	    
	    when load_array =>
	    
    	    ain_tready_o <= '1';
    	    
    	    if ain_tvalid_i = '1' then
      		  we_a_s <= '1';
      		  we_b_s <= '1';
        
              wdata_a_s <= ain_tdata_i(DATA_WIDTH-1 downto 0);
              wdata_b_s <= ain_tdata_i(DATA_WIDTH*2-1 downto DATA_WIDTH);
              
     	      if ain_tlast_i = '1' then
        	  idx_next        <= (others => '0');
        	  phase_even_next <= '1';
	          isSorted_next   <= '1';
        	  state_next      <= read_op_phase;
	          else
		      idx_next <= std_logic_vector(to_unsigned(to_integer(unsigned(idx_reg)) + 2, idx_reg'length));
      	      end if;
      	      
	        end if;
---------------------------------------------------------------------------------------------------------------	    
       when read_op_phase =>

        if (to_integer(unsigned(idx_reg)) < EL_NUM-1 ) then
        -- more pairs to be compared
        state_next <= comp_and_swap_phase;

        else 
        -- end of the even/odd comparison phase
        -- after phase even(comparing elements with even indices), start phase odd
        -- if phase odd is over, check if the array is sorted( "isSorted" flag should stay high if there were no swaps done)         
            if phase_even_reg = '1' then 
           
                phase_even_next <= '0';
                idx_next <= std_logic_vector(to_unsigned(1, idx_reg'length));
                state_next <= read_op_phase;
		
            else
                -- 'odd'  is over
                if isSorted_reg = '1' then
                    sort_fin_next <= '1';
                    idx_next <= (others => '0');
                    state_next <= read_array;

                else
                    
                    phase_even_next <= '1';
                    isSorted_next <= '1';
                    idx_next <= (others => '0');
                    state_next <= read_op_phase;
                    
                end if;
            end if;
        end if;



---------------------------------------------------------------------------------------------------------------
  when comp_and_swap_phase =>
  
	  if ((rdata_a_s > rdata_b_s and sort_dir_i = '1') or (rdata_a_s < rdata_b_s and sort_dir_i = '0')) then
        -- swap
        we_a_s <= '1';
        we_b_s <= '1';
        wdata_a_s <= rdata_b_s;
        wdata_b_s <= rdata_a_s;
        isSorted_next <= '0';

    else
        -- no swap
        wdata_a_s <= rdata_a_s;
        wdata_b_s <= rdata_b_s;
        we_a_s <= '0';
        we_b_s <= '0';
        
    end if;

    -- address next pair
    idx_next <= std_logic_vector(to_unsigned(to_integer(unsigned(idx_reg)) + 2, idx_reg'length));

    -- back to read_op
    state_next <= read_op_phase;

---------------------------------------------------------------------------------------------------------------
	    when read_array=>
	    
	    state_next   <= dup_counter;
-------------------------------------------------------------------	    
	    when dup_counter=>
--at the beginning idx_reg is 0
	    
    if aout_tready_i = '1' then
    aout_tvalid_o <= '1';	   
    aout_tdata_o(DATA_WIDTH-1 downto 0) <= rdata_a_s;
    aout_tdata_o(DATA_WIDTH*2-1 downto DATA_WIDTH) <= rdata_b_s;  
    ---------------------------------------------------------------------------------------      
    -- Count duplicates 
    		
	 if(to_integer(unsigned(idx_reg)) = 0 )then-- First iteration different
	     if rdata_a_s = rdata_b_s then--first comp
             dup_cnt_next <= std_logic_vector(to_unsigned(to_integer(unsigned(dup_cnt_reg)) + 1, dup_cnt_reg'length));
             pair_next <= '1';
         else    
         pair_next <= '0';
         end if;-- first comp
         
     else   -- other comparisons  
    
    	-- pair of the same elements (A,A)
    	if(rdata_a_s = rdata_b_s)then -- previous (X, tmp), X/=tmp
    	pair_next <= '1';
    	if(rdata_a_s = tmp_reg)then
             dup_cnt_next <= std_logic_vector(to_unsigned(to_integer(unsigned(dup_cnt_reg)) + 2, dup_cnt_reg'length));
        else
             dup_cnt_next <= std_logic_vector(to_unsigned(to_integer(unsigned(dup_cnt_reg)) + 1, dup_cnt_reg'length));                 	
        end if;
    	else -- not equal
    	pair_next <= '0';	
		if(rdata_a_s = tmp_reg)then
             dup_cnt_next <= std_logic_vector(to_unsigned(to_integer(unsigned(dup_cnt_reg)) + 1, dup_cnt_reg'length));
        end if;     
    	end if;
      end if;-- comp end    
        tmp_next <= rdata_b_s;  --> Update previous element        
    ---------------------------------------------------------------------------------------                    
      
      if ( to_integer(unsigned(idx_reg)) = EL_NUM-2)then  
       idx_next        <= (others => '0');
       aout_tlast_o <= '1';	
       sort_fin_next <= '0';
       state_next      <= idle;
      else
       idx_next <= std_logic_vector(to_unsigned(to_integer(unsigned(idx_reg)) + 2, idx_reg'length));    
	state_next <= dup_counter;
      end if;
      	      
    end if;
---------------------------------------------------------------------------------------------
     when others =>
            state_next   <= idle;
     end case;
    end process;


-- memory
BRAM: dual_port_bram 
    generic map(
        g_DATA_WIDTH => DATA_WIDTH, 
        g_ADDR_WIDTH => ADDR_WIDTH    
    )
    port map (
	rst => reset,
        -- Port A
        clk   => clk,
        we_a    => we_a_s,
        addr_a  => addr_a_s,
        di_a    => wdata_a_s,
        do_a    => rdata_a_s,
        -- Port B 
        we_b    => we_b_s,
        addr_b  => addr_b_s,
        di_b    => wdata_b_s,
        do_b    => rdata_b_s
    );

-- output 
    dup_cnt_o <= dup_cnt_next;

end Behavioral;
