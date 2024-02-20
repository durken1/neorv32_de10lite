library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity seg is
  port (
    enable : in std_ulogic;
    din    : in std_ulogic_vector(3 downto 0);
    led    : out std_ulogic_vector(7 downto 0)
  );
end entity seg;

architecture rtl of seg is

  type display_t is array(0 to 15) of std_ulogic_vector(7 downto 0);

  constant display_c : display_t := (
  "11000000",
  "11111001",
  "10100100",
  "10110000",
  "10011001",
  "10010010",
  "10000010",
  "11111000",
  "10000000",
  "10011000",
  "10001000",
  "10000011",
  "10100111",
  "10100001",
  "10000110",
  "10001110");

begin

  led <= display_c(to_integer(unsigned(din))) when enable = '1' else (others => '1');

end architecture;