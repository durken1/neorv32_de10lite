library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity matrix_ram is
  port (
    clk_i     : in std_ulogic;
    ram_a_in  : in std_ulogic_vector(15 downto 0);
    ram_d_in  : in std_ulogic;
    ram_we_in : in std_ulogic;
    ram_q_out : out std_ulogic
  );
end entity;

architecture rtl of matrix_ram is
  type ram_t is array (0 to 65535) of std_ulogic;
  signal mem_ram : ram_t := (others => '0');

begin
  ram : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if (ram_we_in = '1') then
        mem_ram(to_integer(unsigned(ram_a_in))) <= ram_d_in;
      end if;
      ram_q_out <= mem_ram(to_integer(unsigned(ram_a_in)));
    end if;
  end process;

end architecture rtl;