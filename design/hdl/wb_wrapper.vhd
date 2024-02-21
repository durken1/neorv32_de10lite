-- #################################################################################################
-- # << wb_stub - Wishbone Dummy Device with Internal Handling of Address Mapping >>               #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity wb_wrapper is
  generic (
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
end wb_wrapper;

architecture rtl of wb_wrapper is

  -- internal constants --
  constant addr_mask_c : std_ulogic_vector(31 downto 0) := std_ulogic_vector(to_unsigned(WB_ADDR_SIZE - 1, 32));
  constant all_zero_c  : std_ulogic_vector(31 downto 0) := (others => '0');

  -- address match --
  signal access_req : std_ulogic;

  -- dummy registers --
  type mm_reg_t is array (0 to (WB_ADDR_SIZE/4) - 1) of std_ulogic_vector(31 downto 0);
  signal mm_reg_in  : mm_reg_t;
  signal mm_reg_out : mm_reg_t;

  signal move_int : std_ulogic;

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
      wb_dat_o  <= (others => '-'); -- no reset
      wb_ack_o  <= '0';
      mm_reg_in <= (others => (others => '-')); -- no reset
    elsif rising_edge(wb_clk_i) then
      -- defaults --
      wb_dat_o <= (others => '0');
      wb_ack_o <= '0';

      -- access --
      if (wb_cyc_i = '1') and (wb_stb_i = '1') and (access_req = '1') then -- classic-mode Wishbone protocol
        if (wb_we_i = '1') then -- write access
          if (wb_sel_i = "1111") then -- only full-word accesses, no ACK otherwise
            mm_reg_in(to_integer(unsigned(wb_adr_i(index_size_f(WB_ADDR_SIZE) - 1 downto 2)))) <= wb_dat_i;
            wb_ack_o                                                                           <= '1';
          end if;
        else -- sync read access
          wb_dat_o <= mm_reg_out(to_integer(unsigned(wb_adr_i(index_size_f(WB_ADDR_SIZE) - 1 downto 2))));
          wb_ack_o <= '1';
        end if;
      end if;
    end if;
  end process rw_access;

  dipslay_7seg_inst : entity work.dipslay_7seg
    port map(
      clk_i     => wb_clk_i,
      rstn_i    => wb_rstn_i,
      data_i    => mm_reg_in(0),
      setup_i   => mm_reg_in(1),
      segled0_o => segled0_o,
      segled1_o => segled1_o,
      segled2_o => segled2_o,
      segled3_o => segled3_o,
      segled4_o => segled4_o,
      segled5_o => segled5_o
    );

  aoc_d3_inst : entity work.aoc_d3
    port map(
      clk_i       => wb_clk_i,
      rstn_i      => wb_rstn_i,
      direction_i => mm_reg_in(2)(1 downto 0),
      move_i      => mm_reg_in(2)(2),
      sum_o       => mm_reg_out(0)
    );

end rtl;