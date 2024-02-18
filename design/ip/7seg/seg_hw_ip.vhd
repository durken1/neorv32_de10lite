library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity seg_hw_ip is
  generic
  (
    WB_ADDR_BASE : std_ulogic_vector(31 downto 0); -- module base address, size-aligned
    WB_ADDR_SIZE : positive -- module address space in bytes, has to be a power of two, min 4
  );
  port (
    -- wishbone host interface --
    wb_clk_i  : in std_ulogic; -- clock
    wb_rstn_i : in std_ulogic; -- reset, async, low-active
    wb_adr_i  : in std_ulogic_vector(31 downto 0); -- address
    wb_dat_i  : in std_ulogic_vector(31 downto 0); -- read data
    wb_dat_o  : out std_ulogic_vector(31 downto 0); -- write data
    wb_we_i   : in std_ulogic; -- read/write
    wb_sel_i  : in std_ulogic_vector(03 downto 0); -- byte enable
    wb_stb_i  : in std_ulogic; -- strobe
    wb_cyc_i  : in std_ulogic; -- valid cycle
    wb_ack_o  : out std_ulogic; -- transfer acknowledge
    segled0_o : out std_ulogic_vector(7 downto 0);
    segled1_o : out std_ulogic_vector(7 downto 0);
    segled2_o : out std_ulogic_vector(7 downto 0);
    segled3_o : out std_ulogic_vector(7 downto 0);
    segled4_o : out std_ulogic_vector(7 downto 0);
    segled5_o : out std_ulogic_vector(7 downto 0)
  );
end entity;

architecture seg_hw_ip_rtl of seg_hw_ip is

  -- internal constants --
  constant addr_mask_c : std_ulogic_vector(31 downto 0) := std_ulogic_vector(to_unsigned(WB_ADDR_SIZE - 1, 32));
  constant all_zero_c  : std_ulogic_vector(31 downto 0) := (others => '0');

  -- address match --
  signal access_req : std_ulogic;

  -- dummy registers --
  type mm_reg_t is array (0 to (WB_ADDR_SIZE/4) - 1) of std_ulogic_vector(31 downto 0);
  signal mm_reg : mm_reg_t;

  signal hex0 : natural range 0 to 15;
  signal hex1 : natural range 0 to 15;
  signal hex2 : natural range 0 to 15;
  signal hex3 : natural range 0 to 15;
  signal hex4 : natural range 0 to 15;
  signal hex5 : natural range 0 to 15;

  component seg
    port (
      din : in natural range 0 to 15;
      led : out std_ulogic_vector(7 downto 0)
    );
  end component;

begin

  -- Sanity Checks --------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  assert not (WB_ADDR_SIZE < 4) report "wb_stub config ERROR: Address space <WB_ADDR_SIZE> has to be at least 4 bytes." severity error;
  assert not (is_power_of_two_f(WB_ADDR_SIZE) = false) report "wb_stub config ERROR: Address space <WB_ADDR_SIZE> has to be a power of two." severity error;
  assert not ((WB_ADDR_BASE and addr_mask_c) /= all_zero_c) report "wb_stub config ERROR: Module base address <WB_ADDR_BASE> has to be aligned to it's address space <WB_ADDR_SIZE>." severity error;

  -- Device Access? -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  access_req <= '1' when ((wb_adr_i and (not addr_mask_c)) = (WB_ADDR_BASE and (not addr_mask_c))) else
    '0';
  -- Bus R/W Access -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  rw_access : process (wb_rstn_i, wb_clk_i)
  begin
    if (wb_rstn_i = '0') then
      wb_dat_o <= (others => '0'); -- no reset
      wb_ack_o <= '0';
      mm_reg   <= (others => (others => '0')); -- no reset
    elsif rising_edge(wb_clk_i) then
      -- defaults --
      wb_dat_o <= (others => '0');
      wb_ack_o <= '0';

      -- access --
      if (wb_cyc_i = '1') and (wb_stb_i = '1') and (access_req = '1') then -- classic-mode Wishbone protocol
        if (wb_we_i = '1') then -- write access
          if (wb_sel_i = "1111") then -- only full-word accesses, no ACK otherwise
            mm_reg(to_integer(unsigned(wb_adr_i(index_size_f(WB_ADDR_SIZE) - 1 downto 2)))) <= wb_dat_i;
            wb_ack_o                                                                        <= '1';
          end if;
        else -- sync read access
          wb_dat_o <= mm_reg(to_integer(unsigned(wb_adr_i(index_size_f(WB_ADDR_SIZE) - 1 downto 2))));
          wb_ack_o <= '1';
        end if;
      end if;
    end if;
  end process rw_access;

  hex0 <= to_integer(unsigned(mm_reg(0)(3 downto 0)));
  hex1 <= to_integer(unsigned(mm_reg(0)(7 downto 4)));
  hex2 <= to_integer(unsigned(mm_reg(0)(11 downto 8)));
  hex3 <= to_integer(unsigned(mm_reg(0)(15 downto 12)));
  hex4 <= to_integer(unsigned(mm_reg(0)(19 downto 16)));
  hex5 <= to_integer(unsigned(mm_reg(0)(23 downto 20)));

  seg_inst_0 : seg
  port map
  (
    din => hex0,
    led => segled0_o
  );

  seg_inst_1 : seg
  port map
  (
    din => hex1,
    led => segled1_o
  );

  seg_inst_2 : seg
  port map
  (
    din => hex2,
    led => segled2_o
  );

  seg_inst_3 : seg
  port map
  (
    din => hex3,
    led => segled3_o
  );

  seg_inst_4 : seg
  port map
  (
    din => hex4,
    led => segled4_o
  );

  seg_inst_5 : seg
  port map
  (
    din => hex5,
    led => segled5_o
  );
end architecture;