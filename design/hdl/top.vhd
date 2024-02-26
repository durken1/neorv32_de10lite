library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity top is
  port (
    clk       : in std_ulogic;
    rst_n     : in std_ulogic;
    uart0_tx  : out std_ulogic;
    uart0_rx  : in std_ulogic;
    disp0     : out std_ulogic_vector(7 downto 0);
    disp1     : out std_ulogic_vector(7 downto 0);
    disp2     : out std_ulogic_vector(7 downto 0);
    disp3     : out std_ulogic_vector(7 downto 0);
    disp4     : out std_ulogic_vector(7 downto 0);
    disp5     : out std_ulogic_vector(7 downto 0);
    gpio_o    : out std_ulogic_vector(9 downto 0);
    gpio_i    : in std_ulogic_vector(10 downto 0);
    jtag_trst : in std_ulogic  := 'X'; -- trst
    jtag_tck  : in std_ulogic  := 'X'; -- tck
    jtag_tdi  : in std_ulogic  := 'X'; -- tdi
    jtag_tdo  : out std_ulogic := 'X'; -- tdo
    jtag_tms  : in std_ulogic  := 'X'; -- tms
    spi_clk   : out std_ulogic;
    spi_cs_n  : out std_ulogic_vector(7 downto 0);
    spi_do    : out std_ulogic;
    spi_di    : in std_ulogic
  );
end entity top;

architecture rtl of top is

  signal con_gpio_o : std_ulogic_vector(63 downto 0);
  signal con_gpio_i : std_ulogic_vector(63 downto 0);

  signal wb_tag   : std_ulogic_vector(02 downto 0); -- request tag
  signal wb_adr   : std_ulogic_vector(31 downto 0); -- address
  signal wb_dat_i : std_ulogic_vector(31 downto 0); -- read data
  signal wb_dat_o : std_ulogic_vector(31 downto 0); -- write data
  signal wb_we    : std_ulogic; -- read/write
  signal wb_sel   : std_ulogic_vector(03 downto 0); -- byte enable
  signal wb_stb   : std_ulogic; -- strobe
  signal wb_cyc   : std_ulogic; -- valid cycle
  signal wb_ack   : std_ulogic := 'L'; -- transfer acknowledge
  signal wb_err   : std_ulogic := 'L'; -- transfer error

begin
  -- The Core Of The Problem ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_top_inst : neorv32_top
  generic map(
    -- General --
    CLOCK_FREQUENCY   => 50_000_000, -- clock frequency of clk_i in Hz
    INT_BOOTLOADER_EN => true, -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM
    -- On-Chip Debugger (OCD) --
    ON_CHIP_DEBUGGER_EN => true, -- implement on-chip debugger
    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_C      => true, -- implement compressed extension?
    CPU_EXTENSION_RISCV_M      => true, -- implement mul/div extension?
    CPU_EXTENSION_RISCV_U      => true, -- implement user mode extension?
    CPU_EXTENSION_RISCV_Zicntr => true, -- implement base counters?
    -- Internal Instruction memory --
    MEM_INT_IMEM_EN   => true, -- implement processor-internal instruction memory
    MEM_INT_IMEM_SIZE => 32 * 1024, -- size of processor-internal instruction memory in bytes
    -- Internal Data memory --
    MEM_INT_DMEM_EN   => true, -- implement processor-internal data memory
    MEM_INT_DMEM_SIZE => 16 * 1024, -- size of processor-internal data memory in bytes
    -- External memory interface (WISHBONE) --
    MEM_EXT_EN         => true, -- implement external memory bus interface?
    MEM_EXT_TIMEOUT    => 255, -- cycles after a pending bus access auto-terminates (0 = disabled)
    MEM_EXT_PIPE_MODE  => false, -- protocol: false=classic/standard wishbone mode, true=pipelined wishbone mode
    MEM_EXT_BIG_ENDIAN => false, -- byte order: true=big-endian, false=little-endian
    MEM_EXT_ASYNC_RX   => false, -- use register buffer for RX data when false
    MEM_EXT_ASYNC_TX   => false, -- use register buffer for TX data when false
    -- Processor peripherals --
    IO_GPIO_NUM => 11, -- number of GPIO input/output pairs (0..64)
    IO_MTIME_EN => true, -- implement machine system timer (MTIME)?
    IO_UART0_EN => true, -- implement primary universal asynchronous receiver/transmitter (UART0)?
    IO_SPI_EN   => true -- implement serial peripheral interface (SPI)?
  )
  port map(
    -- Global control --
    clk_i  => clk, -- global clock, rising edge
    rstn_i => rst_n, -- global reset, low-active, async
    -- JTAG on-chip debugger interface (available if ON_CHIP_DEBUGGER_EN = true) --
    jtag_trst_i => jtag_trst, -- low-active TAP reset (optional)
    jtag_tck_i  => jtag_tck, -- serial clock
    jtag_tdi_i  => jtag_tdi, -- serial data input
    jtag_tdo_o  => jtag_tdo, -- serial data output
    jtag_tms_i  => jtag_tms, -- mode select
    -- Wishbone bus interface (available if MEM_EXT_EN = true) --
    wb_tag_o => wb_tag, -- request tag
    wb_adr_o => wb_adr, -- address
    wb_dat_i => wb_dat_i, -- read data
    wb_dat_o => wb_dat_o, -- write data
    wb_we_o  => wb_we, -- read/write
    wb_sel_o => wb_sel, -- byte enable
    wb_stb_o => wb_stb, -- strobe
    wb_cyc_o => wb_cyc, -- valid cycle
    wb_ack_i => wb_ack, -- transfer acknowledge
    wb_err_i => wb_err, -- transfer error
    -- GPIO (available if IO_GPIO_NUM > 0) --
    gpio_o => con_gpio_o, -- parallel output
    gpio_i => con_gpio_i, -- parallel output
    -- primary UART0 (available if IO_UART0_EN = true) --
    uart0_txd_o => uart0_tx, -- UART0 send data
    uart0_rxd_i => uart0_rx, -- UART0 receive data
    -- SPI (available if IO_SPI_EN = true) --
    spi_clk_o => spi_clk, -- SPI serial clock
    spi_dat_o => spi_do, -- controller data out, peripheral data in
    spi_dat_i => spi_di, -- controller data in, peripheral data out
    spi_csn_o => spi_cs_n -- chip-select

  );

  wb_wrapper_inst : entity work.wb_wrapper
    generic map(
      WB_ADDR_BASE => X"90000000",
      WB_ADDR_SIZE => 16
    )
    port map(
      wb_clk_i  => clk,
      wb_rstn_i => rst_n,
      wb_adr_i  => wb_adr,
      wb_dat_i  => wb_dat_o,
      wb_dat_o  => wb_dat_i,
      wb_we_i   => wb_we,
      wb_sel_i  => wb_sel,
      wb_stb_i  => wb_stb,
      wb_cyc_i  => wb_cyc,
      wb_ack_o  => wb_ack,
      segled0_o => disp0,
      segled1_o => disp1,
      segled2_o => disp2,
      segled3_o => disp3,
      segled4_o => disp4,
      segled5_o => disp5
    );

  gpio_o                  <= con_gpio_o(9 downto 0);
  con_gpio_i(10 downto 0) <= gpio_i;

end architecture;