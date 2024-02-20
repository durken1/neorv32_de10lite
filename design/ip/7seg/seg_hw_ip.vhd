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
    enable_i  : in std_ulogic;
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

  type mm_reg_t is array (0 to (WB_ADDR_SIZE/4) - 1) of std_ulogic_vector(31 downto 0);
  type segled_t is array (0 to 5) of std_ulogic_vector(7 downto 0);
  type segval_t is array (0 to 5) of std_ulogic_vector(3 downto 0);

  -- internal constants --
  constant addr_mask_c    : std_ulogic_vector(31 downto 0) := std_ulogic_vector(to_unsigned(WB_ADDR_SIZE - 1, 32));
  constant all_zero_c     : std_ulogic_vector(31 downto 0) := (others => '0');
  constant loading_frames : segled_t                       := (
  "11011111",
  "11101111",
  "11110111",
  "11111011",
  "11111101",
  "11111110");

  -- address match --
  signal access_req : std_ulogic;

  signal segled_int   : segled_t;
  signal segval_int   : segval_t;
  signal signed_int   : std_ulogic;
  signal dec_int      : std_ulogic;
  signal loading_int  : std_ulogic;
  signal loading_cnt  : unsigned(21 downto 0);
  signal loading_ind  : integer range 0 to 5;
  signal mm_reg       : mm_reg_t;
  signal mm_reg_neg   : std_ulogic_vector(31 downto 0);
  signal bcd_unsigned : std_ulogic_vector(23 downto 0);
  signal bcd_signed   : std_ulogic_vector(19 downto 0);

  signal hex0 : natural range 0 to 15;
  signal hex1 : natural range 0 to 15;
  signal hex2 : natural range 0 to 15;
  signal hex3 : natural range 0 to 15;
  signal hex4 : natural range 0 to 15;
  signal hex5 : natural range 0 to 15;

  component seg
    port (
      enable : in std_ulogic;
      din    : in std_ulogic_vector(3 downto 0);
      led    : out std_ulogic_vector(7 downto 0)
    );
  end component;

begin

  mm_reg_neg  <= std_ulogic_vector( - (signed(mm_reg(0))));
  signed_int  <= mm_reg(1)(0);
  dec_int     <= mm_reg(1)(1);
  loading_int <= mm_reg(1)(2);

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

  -- counter for loading animation
  process (wb_clk_i, wb_rstn_i)
  begin
    if wb_rstn_i = '0' then
      loading_cnt <= (others => '0');
      loading_ind <= 0;
    elsif rising_edge(wb_clk_i) then
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
  process (wb_clk_i, wb_rstn_i)
  begin
    if wb_rstn_i = '0' then
      segled0_o <= (others => '1');
      segled1_o <= (others => '1');
      segled2_o <= (others => '1');
      segled3_o <= (others => '1');
      segled4_o <= (others => '1');
      segled5_o <= (others => '1');
    elsif rising_edge(wb_clk_i) then
      if (loading_int = '1') then
        segled0_o <= loading_frames(loading_ind);
        segled1_o <= loading_frames(loading_ind);
        segled2_o <= loading_frames(loading_ind);
        segled3_o <= loading_frames(loading_ind);
        segled4_o <= loading_frames(loading_ind);
        segled5_o <= loading_frames(loading_ind);
      else
        segled0_o <= segled_int(0);
        segled1_o <= segled_int(1);
        segled2_o <= segled_int(2);
        segled3_o <= segled_int(3);
        segled4_o <= segled_int(4);
        segled5_o <= segled_int(5);
      end if;

      if (signed_int = '1' and mm_reg(0)(31) = '1') then
        segled5_o <= "10111111"; -- minus sign
        if (dec_int = '1') then
          segval_int(0) <= bcd_signed(3 downto 0);
          segval_int(1) <= bcd_signed(7 downto 4);
          segval_int(2) <= bcd_signed(11 downto 8);
          segval_int(3) <= bcd_signed(15 downto 12);
          segval_int(4) <= bcd_signed(19 downto 16);

        else
          segval_int(0) <= mm_reg_neg(3 downto 0);
          segval_int(1) <= mm_reg_neg(7 downto 4);
          segval_int(2) <= mm_reg_neg(11 downto 8);
          segval_int(3) <= mm_reg_neg(15 downto 12);
          segval_int(4) <= mm_reg_neg(19 downto 16);
        end if;

      else
        if (dec_int = '1') then
          segval_int(0) <= bcd_unsigned(3 downto 0);
          segval_int(1) <= bcd_unsigned(7 downto 4);
          segval_int(2) <= bcd_unsigned(11 downto 8);
          segval_int(3) <= bcd_unsigned(15 downto 12);
          segval_int(4) <= bcd_unsigned(19 downto 16);
          segval_int(5) <= bcd_unsigned(23 downto 20);
        else
          segval_int(0) <= mm_reg(0)(3 downto 0);
          segval_int(1) <= mm_reg(0)(7 downto 4);
          segval_int(2) <= mm_reg(0)(11 downto 8);
          segval_int(3) <= mm_reg(0)(15 downto 12);
          segval_int(4) <= mm_reg(0)(19 downto 16);
          segval_int(5) <= mm_reg(0)(23 downto 20);
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
      clk_50_i  => wb_clk_i,
      reset_n_i => wb_rstn_i,
      num_bin_i => mm_reg(0)(19 downto 0),
      num_bcd_o => bcd_unsigned
    );

  bin2bcd_signed : entity work.bin2bcd
    generic
    map (
    bin_width_g => 17,
    dec_width_g => 5
    )
    port map(
      clk_50_i  => wb_clk_i,
      reset_n_i => wb_rstn_i,
      num_bin_i => mm_reg_neg(16 downto 0),
      num_bcd_o => bcd_signed
    );

  seg_gen : for i in 0 to 5 generate
    seg_inst : seg
    port map
    (
      enable => enable_i,
      din    => segval_int(i),
      led    => segled_int(i)
    );
  end generate;

end architecture;