library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; -- Use NUMERIC_STD for address conversions

entity dual_port_bram is
    generic (
        g_DATA_WIDTH : integer := 16; -- Width of data bus
        g_ADDR_WIDTH : integer := 8    -- Width of address bus (2^8 = 256 words deep)
    );
    Port (

--FV deo-izmena
	rst:  in STD_LOGIC;
        -- Port A
        clk   : in STD_LOGIC;
        we_a    : in STD_LOGIC; -- Write enable A (active high)
        addr_a  : in STD_LOGIC_VECTOR(g_ADDR_WIDTH-1 downto 0);
        di_a    : in STD_LOGIC_VECTOR(g_DATA_WIDTH-1 downto 0); -- Data in A
        do_a    : out STD_LOGIC_VECTOR(g_DATA_WIDTH-1 downto 0); -- Data out A
        -- Port B
        --clk_b   : in STD_LOGIC;
        we_b    : in STD_LOGIC; -- Write enable B (active high)
        addr_b  : in STD_LOGIC_VECTOR(g_ADDR_WIDTH-1 downto 0);
        di_b    : in STD_LOGIC_VECTOR(g_DATA_WIDTH-1 downto 0); -- Data in B
        do_b    : out STD_LOGIC_VECTOR(g_DATA_WIDTH-1 downto 0)  -- Data out B
    );
end dual_port_bram;

architecture rtl of dual_port_bram is
    type ram_type is array (0 to (2**g_ADDR_WIDTH)-1)
        of std_logic_vector(g_DATA_WIDTH-1 downto 0);

    signal RAM : ram_type := (others => (others => '0'));
begin

    process(clk)
    begin
        if rising_edge(clk) then
	if(rst = '1')then	--dodato
	--when reset
        -- Zero entire RAM
            for i in 0 to (2**g_ADDR_WIDTH)-1 loop
                RAM(i) <= (others => '0');
            end loop;

	else	
            -- PORT A
            if we_a = '1' then
                RAM(to_integer(unsigned(addr_a))) <= di_a;
            end if;
            do_a <= RAM(to_integer(unsigned(addr_a)));

            -- PORT B
            if we_b = '1' then
                RAM(to_integer(unsigned(addr_b))) <= di_b;
            end if;
            do_b <= RAM(to_integer(unsigned(addr_b)));
	end if;
        end if;
    end process;

end rtl;
