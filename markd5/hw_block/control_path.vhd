library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- nisam uspeo preko alata da podesim parametre, pa sam ovde ... 
entity control_path is
  generic (
    NUM_OF_WORDS : natural := 4;
    ADDR_WIDTH   : natural := 2;
    WORD_WIDTH   : natural := 6
  );
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;

    ain_tvalid    : in  std_logic;
    ain_tlast     : in  std_logic;
    ain_tdata     : in  std_logic_vector(2*WORD_WIDTH-1 downto 0);
    ain_tready    : out std_logic;

    aout_tready   : in  std_logic;
    aout_tvalid   : out std_logic;
    aout_tlast    : out std_logic;

    pair_idx      : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    pair_valid    : out std_logic; 
    compare_and_swap_done : in  std_logic;
    cas_mem_wr_a  : in  std_logic;
    cas_mem_addr_a: in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    cas_mem_din_a : in  std_logic_vector(WORD_WIDTH-1 downto 0);
    cas_mem_wr_b  : in  std_logic;
    cas_mem_addr_b: in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    cas_mem_din_b : in  std_logic_vector(WORD_WIDTH-1 downto 0);

    mem_addr_a    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    mem_din_a     : out std_logic_vector(WORD_WIDTH-1 downto 0);
    mem_wr_a      : out std_logic;
    mem_addr_b    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    mem_din_b     : out std_logic_vector(WORD_WIDTH-1 downto 0);
    mem_wr_b      : out std_logic;

    cas_dup_found : in  std_logic;
    dup_nums      : out std_logic_vector(ADDR_WIDTH-1 downto 0)
  );
end entity;

architecture behavioral of control_path is

  type state_type is (IDLE, RECEIVE, SORTING, SEND);
  signal state : state_type;

  signal recv_cnt : unsigned(ADDR_WIDTH-1 downto 0);
  signal send_cnt : unsigned(ADDR_WIDTH-1 downto 0);

  signal pass_cnt      : unsigned(ADDR_WIDTH-1 downto 0);
  signal comp_cnt      : unsigned(ADDR_WIDTH-1 downto 0);
  signal sort_finished : std_logic;
  signal dup_counter   : unsigned(ADDR_WIDTH-1 downto 0);

begin

  ain_tready <= '1' when (state = IDLE or state = RECEIVE) else '0';
  aout_tvalid <= '1' when state = SEND else '0';
  aout_tlast <= '1' when (state = SEND and send_cnt = to_unsigned(NUM_OF_WORDS/2 - 1, ADDR_WIDTH))
                else '0';

  pair_idx   <= std_logic_vector(comp_cnt);
  pair_valid <= '1' when (state = SORTING and sort_finished = '0' and cas_mem_wr_a = '0' and compare_and_swap_done = '0') else '0';



  mem_addr_a <= std_logic_vector(recv_cnt) when (state = IDLE or state = RECEIVE) else
                std_logic_vector(shift_left(send_cnt, 1)) when state = SEND else
                cas_mem_addr_a when cas_mem_wr_a = '1' else
                std_logic_vector(comp_cnt);  -- SORTING read
  
  mem_din_a  <= ain_tdata(WORD_WIDTH-1 downto 0) when (state = IDLE or state = RECEIVE) else
                cas_mem_din_a;
  
  mem_wr_a   <= ain_tvalid when (state = IDLE or state = RECEIVE) else
                cas_mem_wr_a when state = SORTING else
                '0';

  -- Memorija port B
  mem_addr_b <= std_logic_vector(unsigned(recv_cnt) + 1) when (state = IDLE or state = RECEIVE) else
                std_logic_vector(shift_left(send_cnt, 1) + 1) when state = SEND else
                cas_mem_addr_b when cas_mem_wr_b = '1' else
                std_logic_vector(comp_cnt + 1);  -- SORTING read
  
  mem_din_b  <= ain_tdata(2*WORD_WIDTH-1 downto WORD_WIDTH) when (state = IDLE or state = RECEIVE) else
                cas_mem_din_b;
  
  mem_wr_b   <= ain_tvalid when (state = IDLE or state = RECEIVE) else
                cas_mem_wr_b when state = SORTING else
                '0';

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state         <= IDLE;
        recv_cnt      <= (others => '0');
        pass_cnt      <= (others => '0');
        comp_cnt      <= (others => '0');
        send_cnt      <= (others => '0');
        sort_finished <= '0';
        dup_counter   <= (others => '0');
      else
        case state is

          when IDLE =>
            recv_cnt      <= (others => '0');
            sort_finished <= '0';
            dup_counter   <= (others => '0');  
            if ain_tvalid = '1' then
              recv_cnt <= to_unsigned(2, ADDR_WIDTH);  
              state    <= RECEIVE;
            end if;

          when RECEIVE =>
            if ain_tvalid = '1' then
              recv_cnt <= recv_cnt + 2;  
              if ain_tlast = '1' then
                state    <= SORTING;
                pass_cnt <= (others => '0');
                comp_cnt <= (others => '0');
              end if;
            end if;

          when SORTING =>
            if sort_finished = '1' then
              if aout_tready = '1' then
                state    <= SEND;
                send_cnt <= (others => '0');
              end if;
            else
              if compare_and_swap_done = '1' then
                if cas_dup_found = '1' and pass_cnt = to_unsigned(NUM_OF_WORDS - 1, ADDR_WIDTH) then
                  dup_counter <= dup_counter + 1;
                end if;
                if comp_cnt = to_unsigned(NUM_OF_WORDS - 2, ADDR_WIDTH) then
                  comp_cnt <= (others => '0');
                  if pass_cnt = to_unsigned(NUM_OF_WORDS - 1, ADDR_WIDTH) then
                    sort_finished <= '1';
                  else
                    pass_cnt <= pass_cnt + 1;
                  end if;
                else
                  comp_cnt <= comp_cnt + 1;
                end if;
              end if;
            end if;

          when SEND =>
            if aout_tready = '1' then
              if send_cnt = to_unsigned(NUM_OF_WORDS/2 - 1, ADDR_WIDTH) then
                state <= IDLE;
              else
                send_cnt <= send_cnt + 1;
              end if;
            end if;

        end case;
      end if;
    end if;
  end process;

  dup_nums <= std_logic_vector(dup_counter) when state = SEND else (others => '0');

end architecture;
