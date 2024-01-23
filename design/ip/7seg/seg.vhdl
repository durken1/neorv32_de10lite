library ieee;
context ieee.ieee_std_context;
use ieee.math_real.all;

entity seg is
    port (
        din : in natural range 0 to 15;
        led : out std_logic_vector(7 downto 0)
    );
end entity seg;

architecture rtl of seg is

    constant display_zero  : std_logic_vector(6 downto 0) := "1000000"; -- 0x40
    constant display_one   : std_logic_vector(6 downto 0) := "1111001"; -- 0x79
    constant display_two   : std_logic_vector(6 downto 0) := "0100100"; -- 0x24
    constant display_three : std_logic_vector(6 downto 0) := "0110000"; -- 0x30
    constant display_four  : std_logic_vector(6 downto 0) := "0011001"; -- 0x19
    constant display_five  : std_logic_vector(6 downto 0) := "0010010"; -- 0x12
    constant display_six   : std_logic_vector(6 downto 0) := "0000010"; -- 0x02
    constant display_seven : std_logic_vector(6 downto 0) := "1111000"; -- 0x38
    constant display_eight : std_logic_vector(6 downto 0) := "0000000"; -- 0x00
    constant display_nine  : std_logic_vector(6 downto 0) := "0011000"; -- 0x18
    constant display_a     : std_logic_vector(6 downto 0) := "0001000"; -- 0x08
    constant display_b     : std_logic_vector(6 downto 0) := "0000011"; -- 0x03
    constant display_c     : std_logic_vector(6 downto 0) := "1000110"; -- 0x46
    constant display_d     : std_logic_vector(6 downto 0) := "0100001"; -- 0x21
    constant display_e     : std_logic_vector(6 downto 0) := "0000110"; -- 0x06
    constant display_f     : std_logic_vector(6 downto 0) := "0000111"; -- 0x07	

begin

    with din select
        led <=
        display_zero when 0,
        display_one when 1,
        display_two when 2,
        display_three when 3,
        display_four when 4,
        display_five when 5,
        display_six when 6,
        display_seven when 7,
        display_eight when 8,
        display_nine when 9,
        display_a when 10,
        display_b when 11,
        display_c when 12,
        display_d when 13,
        display_e when 14,
        display_f when others;

end architecture;