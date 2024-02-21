library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bin2bcd is
  generic
  (
    bin_width_g : in positive := 4;
    dec_width_g : in positive := 2
  );
  port (
    clk_50_i  : in std_ulogic;
    reset_n_i : in std_ulogic;
    num_bin_i : in std_ulogic_vector(bin_width_g - 1 downto 0);
    num_bcd_o : out std_ulogic_vector(dec_width_g * 4 - 1 downto 0)
  );
end entity;

architecture rtl of bin2bcd is

begin

  doubledabble : process (clk_50_i, reset_n_i)
    variable scratch_v : unsigned(dec_width_g * 4 + bin_width_g - 1 downto 0);
  begin
    if reset_n_i = '0' then
      scratch_v := (others => '0');
      num_bcd_o <= (others => '0');

    elsif rising_edge(clk_50_i) then
      scratch_v := (scratch_v'left downto bin_width_g => '0') & unsigned(num_bin_i);

      for i in 0 to (bin_width_g - 1) loop
        for j in 0 to (dec_width_g - 1) loop
          if ((scratch_v(bin_width_g + 3 + 4 * j downto bin_width_g + 4 * j)) > 4) then
            scratch_v(bin_width_g + 3 + 4 * j downto bin_width_g + 4 * j) := scratch_v(bin_width_g + 3 + 4 * j downto bin_width_g + 4 * j) + 3;
          end if;
        end loop;
        scratch_v(scratch_v'left downto 1) := scratch_v(scratch_v'left - 1 downto 0);
      end loop;

      num_bcd_o <= std_ulogic_vector(scratch_v(scratch_v'left downto bin_width_g));
    end if;

  end process;
end architecture;