library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity compare_swap is
  generic (
    WORD_WIDTH : natural := 16;
    ADDR_WIDTH : natural := 2
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    sort_dir : in  std_logic; -- 1 - up
    pair_idx : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    pair_valid : in std_logic;

    -- 2 susedne mem lokacije
    mem_dout_a : in  std_logic_vector(WORD_WIDTH-1 downto 0);
    mem_dout_b : in  std_logic_vector(WORD_WIDTH-1 downto 0); 

    mem_wr_a   : out std_logic;
    mem_addr_a : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    mem_din_a  : out std_logic_vector(WORD_WIDTH-1 downto 0);

    mem_wr_b   : out std_logic;
    mem_addr_b : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    mem_din_b  : out std_logic_vector(WORD_WIDTH-1 downto 0);

    compare_and_swap_done : out std_logic;

    dup_found : out std_logic -- u pitanju je duplikat
  );
end entity;

architecture rtl of compare_swap is

  signal a, b : unsigned(WORD_WIDTH-1 downto 0);
  signal swap_needed : std_logic;
  signal eq : std_logic;
  signal pair_idx_r : std_logic_vector(ADDR_WIDTH-1 downto 0);  

begin

  a <= unsigned(mem_dout_a);
  b <= unsigned(mem_dout_b);

  eq <= '1' when a = b else '0';

  swap_needed <= '1' when ((sort_dir = '1' and a > b) or (sort_dir = '0' and a < b)) else '0';

 
  mem_addr_a <= pair_idx_r;
  mem_addr_b <= std_logic_vector(unsigned(pair_idx_r) + 1);

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        mem_wr_a <= '0';
        mem_wr_b <= '0';
        compare_and_swap_done <= '0';
        dup_found <= '0';
        pair_idx_r <= (others => '0');

      else
        mem_wr_a <= '0';
        mem_wr_b <= '0';
        compare_and_swap_done <= '0';
        dup_found <= '0';
        

        pair_idx_r <= pair_idx;
        
        if pair_valid = '1' then
          dup_found <= eq;
          if swap_needed = '1' then
            mem_wr_a <= '1';
            mem_din_a  <= std_logic_vector(b);
            mem_wr_b <= '1';
            mem_din_b  <= std_logic_vector(a);
          end if;
          compare_and_swap_done <= '1';
        end if;
      end if;
    end if;
  end process;
end architecture;
