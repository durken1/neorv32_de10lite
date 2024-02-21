library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity dipslay_7seg is
  port (
    clk_i     : in std_ulogic;
    rstn_i    : in std_ulogic;
    data_i    : in std_ulogic_vector(31 downto 0);
    setup_i   : in std_ulogic_vector(31 downto 0);
    segled0_o : out std_ulogic_vector(7 downto 0);
    segled1_o : out std_ulogic_vector(7 downto 0);
    segled2_o : out std_ulogic_vector(7 downto 0);
    segled3_o : out std_ulogic_vector(7 downto 0);
    segled4_o : out std_ulogic_vector(7 downto 0);
    segled5_o : out std_ulogic_vector(7 downto 0)
  );
end entity;

architecture rtl of dipslay_7seg is

  type segled_t is array (0 to 5) of std_ulogic_vector(7 downto 0);
  type display_t is array(0 to 15) of std_ulogic_vector(7 downto 0);

  -- internal constants --
  constant off_c : std_ulogic_vector(7 downto 0) := (others => '1');

  constant loading_frames_c : segled_t := (
  "11011111",
  "11101111",
  "11110111",
  "11111011",
  "11111101",
  "11111110");

  constant digits_c : display_t := (
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

  -- internal signals --
  signal segled_int   : segled_t;
  signal signed_int   : std_ulogic;
  signal dec_int      : std_ulogic;
  signal enablen_int  : std_ulogic;
  signal loading_int  : std_ulogic;
  signal loading_cnt  : unsigned(21 downto 0);
  signal loading_ind  : integer range 0 to 5;
  signal data_neg     : std_ulogic_vector(31 downto 0);
  signal bcd_unsigned : std_ulogic_vector(23 downto 0);
  signal bcd_signed   : std_ulogic_vector(19 downto 0);

begin

  data_neg    <= std_ulogic_vector( - (signed(data_i)));
  signed_int  <= setup_i(0);
  dec_int     <= setup_i(1);
  loading_int <= setup_i(2);
  enablen_int <= setup_i(3);

  -- counter for loading animation
  process (clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      loading_cnt <= (others => '0');
      loading_ind <= 0;
    elsif rising_edge(clk_i) then
      loading_cnt <= loading_cnt + 1;
      if (loading_cnt = 0) then
        if (loading_ind = 5) then
          loading_ind <= 0;
        else
          loading_ind <= loading_ind + 1;
        end if;
      end if;
    end if;
  end process;

  -- Split up data into seperate 7seg display values
  -- Output data
  process (clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      segled0_o <= off_c;
      segled1_o <= off_c;
      segled2_o <= off_c;
      segled3_o <= off_c;
      segled4_o <= off_c;
      segled5_o <= off_c;

    elsif rising_edge(clk_i) then
      if (enablen_int = '1') then
        segled0_o <= off_c;
        segled1_o <= off_c;
        segled2_o <= off_c;
        segled3_o <= off_c;
        segled4_o <= off_c;
        segled5_o <= off_c;

      elsif (loading_int = '1') then -- Display loading animation
        segled0_o <= loading_frames_c(loading_ind);
        segled1_o <= loading_frames_c(loading_ind);
        segled2_o <= loading_frames_c(loading_ind);
        segled3_o <= loading_frames_c(loading_ind);
        segled4_o <= loading_frames_c(loading_ind);
        segled5_o <= loading_frames_c(loading_ind);

      else -- Display digits
        segled0_o <= segled_int(0);
        segled1_o <= segled_int(1);
        segled2_o <= segled_int(2);
        segled3_o <= segled_int(3);
        segled4_o <= segled_int(4);
        segled5_o <= segled_int(5);
      end if;

      if (signed_int = '1' and data_i(31) = '1') then
        segled5_o <= "10111111"; -- minus sign
        if (dec_int = '1') then -- Display decimal digits
          segled_int(0) <= digits_c(to_integer(unsigned(bcd_signed(3 downto 0))));
          segled_int(1) <= digits_c(to_integer(unsigned(bcd_signed(7 downto 4))));
          segled_int(2) <= digits_c(to_integer(unsigned(bcd_signed(11 downto 8))));
          segled_int(3) <= digits_c(to_integer(unsigned(bcd_signed(15 downto 12))));
          segled_int(4) <= digits_c(to_integer(unsigned(bcd_signed(19 downto 16))));

        else -- Display hex ditigs
          segled_int(0) <= digits_c(to_integer(unsigned(data_neg(3 downto 0))));
          segled_int(1) <= digits_c(to_integer(unsigned(data_neg(7 downto 4))));
          segled_int(2) <= digits_c(to_integer(unsigned(data_neg(11 downto 8))));
          segled_int(3) <= digits_c(to_integer(unsigned(data_neg(15 downto 12))));
          segled_int(4) <= digits_c(to_integer(unsigned(data_neg(19 downto 16))));
        end if;

      else
        if (dec_int = '1') then -- Display decimal digits
          segled_int(0) <= digits_c(to_integer(unsigned(bcd_unsigned(3 downto 0))));
          segled_int(1) <= digits_c(to_integer(unsigned(bcd_unsigned(7 downto 4))));
          segled_int(2) <= digits_c(to_integer(unsigned(bcd_unsigned(11 downto 8))));
          segled_int(3) <= digits_c(to_integer(unsigned(bcd_unsigned(15 downto 12))));
          segled_int(4) <= digits_c(to_integer(unsigned(bcd_unsigned(19 downto 16))));
          segled_int(5) <= digits_c(to_integer(unsigned(bcd_unsigned(23 downto 20))));

        else -- Display hex digits
          segled_int(0) <= digits_c(to_integer(unsigned(data_i(3 downto 0))));
          segled_int(1) <= digits_c(to_integer(unsigned(data_i(7 downto 4))));
          segled_int(2) <= digits_c(to_integer(unsigned(data_i(11 downto 8))));
          segled_int(3) <= digits_c(to_integer(unsigned(data_i(15 downto 12))));
          segled_int(4) <= digits_c(to_integer(unsigned(data_i(19 downto 16))));
          segled_int(5) <= digits_c(to_integer(unsigned(data_i(23 downto 20))));
        end if;
      end if;
    end if;
  end process;

  bin2bcd_unsigned : entity work.bin2bcd
    generic
    map (
    bin_width_g => 20,
    dec_width_g => 6
    )
    port map(
      clk_50_i  => clk_i,
      reset_n_i => rstn_i,
      num_bin_i => data_i(19 downto 0),
      num_bcd_o => bcd_unsigned
    );

  bin2bcd_signed : entity work.bin2bcd
    generic
    map (
    bin_width_g => 17,
    dec_width_g => 5
    )
    port map(
      clk_50_i  => clk_i,
      reset_n_i => rstn_i,
      num_bin_i => data_neg(16 downto 0),
      num_bcd_o => bcd_signed
    );

end architecture;