library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory is
  generic (
    NUM_OF_WORDS  : natural := 1024;
    WORD_WIDTH  : natural := 16;
    ADDR_WIDTH : natural := 10
  );
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;

    wr_a   : in  std_logic;
    addr_a : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    din_a  : in  std_logic_vector(WORD_WIDTH-1 downto 0);
    dout_a : out std_logic_vector(WORD_WIDTH-1 downto 0);

    wr_b   : in  std_logic;
    addr_b : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    din_b  : in  std_logic_vector(WORD_WIDTH-1 downto 0);
    dout_b : out std_logic_vector(WORD_WIDTH-1 downto 0)
  );
end entity;

architecture behavioral of memory is
  type mem_array_type is array (0 to NUM_OF_WORDS-1) of std_logic_vector(WORD_WIDTH-1 downto 0);
  signal mem : mem_array_type;
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        mem <= (others => (others => '0'));
      else
        if wr_a = '1' then
          mem(to_integer(unsigned(addr_a))) <= din_a;
        end if;
        if wr_b = '1' then
          mem(to_integer(unsigned(addr_b))) <= din_b;
        end if;
      end if;
    end if;
  end process;

  dout_a <= mem(to_integer(unsigned(addr_a)));
  dout_b <= mem(to_integer(unsigned(addr_b)));

end architecture;
