library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity aoc_d3 is
  port (
    clk_i       : in std_logic;
    rstn_i      : in std_logic;
    direction_i : in std_ulogic_vector(1 downto 0);
    move_i      : in std_ulogic;
    sum_o       : out std_ulogic_vector(31 downto 0)

  );
end entity aoc_d3;

architecture rtl of aoc_d3 is

  type state_t is (idle, move, calc_sum);

  signal x_int        : integer range 0 to 256;
  signal y_int        : integer range 0 to 256;
  signal sum_int      : integer range 0 to 65535;
  signal state_int    : state_t;
  signal move_old_int : std_ulogic;
  signal move_int     : boolean;

  signal ram_a_int  : std_ulogic_vector(15 downto 0);
  signal ram_d_int  : std_ulogic;
  signal ram_we_int : std_ulogic;
  signal ram_q_int  : std_ulogic;

begin

  sum_o     <= std_ulogic_vector(to_unsigned(sum_int, 32));
  ram_a_int <= std_ulogic_vector(to_unsigned(x_int + 256 * y_int, 16));

  process (clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      move_old_int <= '0';
    elsif rising_edge(clk_i) then
      move_old_int <= move_i;
      move_int     <= false;
      if (move_old_int /= move_i) then
        move_int <= true;
      end if;
    end if;
  end process;

  move_santa : process (clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      x_int     <= 80;
      y_int     <= 48;
      state_int <= move;
      sum_int   <= 0;
    elsif rising_edge(clk_i) then
      ram_we_int <= '0';

      case state_int is
        when idle =>
          if (move_int) then
            state_int <= move;
          end if;

        when move =>
          if (move_int) then
            case direction_i is
              when "00" => -- move right
                x_int <= x_int + 1;

              when "01" => -- move left
                x_int <= x_int - 1;

              when "10" => -- move up
                y_int <= y_int + 1;

              when others => -- move down
                y_int <= y_int - 1;
            end case;
          end if;
          state_int <= calc_sum;

        when calc_sum =>
          if (ram_q_int = '0') then
            sum_int <= sum_int + 1;
          end if;
          ram_we_int <= '1';
          state_int  <= idle;
      end case;
    end if;
  end process;

  matrix_ram_inst : entity work.matrix_ram
    port map(
      clk_i     => clk_i,
      rstn_i    => rstn_i,
      ram_a_in  => ram_a_int,
      ram_d_in  => ram_d_int,
      ram_we_in => ram_we_int,
      ram_q_out => ram_q_int
    );
end architecture;