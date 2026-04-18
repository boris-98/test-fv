library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sorter_top is
  generic (
    NUM_OF_WORDS : natural := 8;
    WORD_WIDTH   : natural := 4;
    ADDR_WIDTH   : natural := 4
  );
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;

    ain_tvalid    : in  std_logic;
    ain_tready    : out std_logic;
    ain_tdata     : in  std_logic_vector(2*WORD_WIDTH-1 downto 0); 
    ain_tlast     : in  std_logic;

    aout_tvalid   : out std_logic;
    aout_tready   : in  std_logic;
    aout_tdata    : out std_logic_vector(2*WORD_WIDTH-1 downto 0); 
    aout_tlast    : out std_logic;

    sort_dir      : in  std_logic; -- up = 1

    dup_nums      : out std_logic_vector(ADDR_WIDTH-1 downto 0)
  );
end entity;

architecture rtl of sorter_top is

  signal ctrl_pair_idx      : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal ctrl_pair_valid    : std_logic;
  signal ctrl_cas_done      : std_logic;

  signal mem_wr_a           : std_logic;
  signal mem_addr_a         : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal mem_din_a          : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal mem_dout_a         : std_logic_vector(WORD_WIDTH-1 downto 0);

  signal mem_wr_b           : std_logic;
  signal mem_addr_b         : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal mem_din_b          : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal mem_dout_b         : std_logic_vector(WORD_WIDTH-1 downto 0);

  signal cas_mem_wr_a       : std_logic;
  signal cas_mem_addr_a     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal cas_mem_din_a      : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal cas_mem_wr_b       : std_logic;
  signal cas_mem_addr_b     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal cas_mem_din_b      : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal cas_dup_found      : std_logic;
  signal aout_tvalid_i      : std_logic;

begin

  u_control_path : entity work.control_path
    generic map (
      NUM_OF_WORDS => NUM_OF_WORDS,
      ADDR_WIDTH   => ADDR_WIDTH,
      WORD_WIDTH   => WORD_WIDTH
    )
    port map (
      clk                   => clk,
      rst                   => rst,
      ain_tvalid            => ain_tvalid,
      ain_tlast             => ain_tlast,
      ain_tdata             => ain_tdata,
      ain_tready            => ain_tready,
      aout_tready           => aout_tready,
      aout_tvalid           => aout_tvalid_i,
      aout_tlast            => aout_tlast,
     pair_idx              => ctrl_pair_idx,
      pair_valid            => ctrl_pair_valid,
      compare_and_swap_done => ctrl_cas_done,
      cas_mem_wr_a          => cas_mem_wr_a,
      cas_mem_addr_a        => cas_mem_addr_a,
      cas_mem_din_a         => cas_mem_din_a,
      cas_mem_wr_b          => cas_mem_wr_b,
      cas_mem_addr_b        => cas_mem_addr_b,
      cas_mem_din_b         => cas_mem_din_b,
      mem_addr_a            => mem_addr_a,
      mem_din_a             => mem_din_a,
      mem_wr_a              => mem_wr_a,
      mem_addr_b            => mem_addr_b,
      mem_din_b             => mem_din_b,
      mem_wr_b              => mem_wr_b,
      cas_dup_found         => cas_dup_found,
      dup_nums              => dup_nums
    );

  u_memory : entity work.memory
    generic map (
      NUM_OF_WORDS => NUM_OF_WORDS,
      WORD_WIDTH   => WORD_WIDTH,
      ADDR_WIDTH   => ADDR_WIDTH
    )
    port map (
      clk    => clk,
      rst    => rst,
      wr_a   => mem_wr_a,
      addr_a => mem_addr_a,
      din_a  => mem_din_a,
      dout_a => mem_dout_a,
       wr_b   => mem_wr_b,
      addr_b => mem_addr_b,
      din_b  => mem_din_b,
      dout_b => mem_dout_b
    );

  u_compare_swap : entity work.compare_swap
    generic map (
      WORD_WIDTH => WORD_WIDTH,
      ADDR_WIDTH => ADDR_WIDTH
    )
    port map (
      clk                   => clk,
      rst                   => rst,
      sort_dir              => sort_dir,
      pair_idx              => ctrl_pair_idx,
      pair_valid            => ctrl_pair_valid,
      mem_dout_a            => mem_dout_a,
      mem_dout_b            => mem_dout_b,
      mem_wr_a              => cas_mem_wr_a,
      mem_addr_a            => cas_mem_addr_a,
      mem_din_a             => cas_mem_din_a,
      mem_wr_b              => cas_mem_wr_b,
      mem_addr_b            => cas_mem_addr_b,
      mem_din_b             => cas_mem_din_b,
      compare_and_swap_done => ctrl_cas_done,
      dup_found             => cas_dup_found
    );

  aout_tvalid <= aout_tvalid_i;
  aout_tdata  <= (mem_dout_b & mem_dout_a) when aout_tvalid_i = '1' 
                 else (others => '0');

end architecture;
