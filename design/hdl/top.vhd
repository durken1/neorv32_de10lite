library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity top is
  generic (
    -- adapt these for your setup --
    CLOCK_FREQUENCY   : natural := 50_000_000; -- clock frequency of clk_i in Hz
    MEM_INT_IMEM_SIZE : natural := 16 * 1024;  -- size of processor-internal instruction memory in bytes
    MEM_INT_DMEM_SIZE : natural := 8 * 1024    -- size of processor-internal data memory in bytes
  );
  port (
    -- Global control --
    clk_i  : in std_ulogic; -- global clock, rising edge
    rstn_i : in std_ulogic; -- global reset, low-active, async
    -- GPIO --
    gpio_o : out std_ulogic_vector(7 downto 0); -- parallel output
    -- UART0 --
    uart0_txd_o : out std_ulogic; -- UART0 send data
    uart0_rxd_i : in std_ulogic;  -- UART0 receive data

    -- AvalonMM interface
    read_o        : out std_logic;
    write_o       : out std_logic;
    waitrequest_i : in std_logic := '0';
    byteenable_o  : out std_logic_vector(3 downto 0);
    address_o     : out std_logic_vector(31 downto 0);
    writedata_o   : out std_logic_vector(31 downto 0);
    readdata_i    : in std_logic_vector(31 downto 0) := (others => '0')
  );
end entity;

architecture rtl of top is

  signal con_gpio_o : std_ulogic_vector(63 downto 0);

  signal wb_tag_o : std_ulogic_vector(02 downto 0);                    -- request tag
  signal wb_adr_o : std_ulogic_vector(31 downto 0);                    -- address
  signal wb_dat_i : std_ulogic_vector(31 downto 0) := (others => 'U'); -- read data
  signal wb_dat_o : std_ulogic_vector(31 downto 0);                    -- write data
  signal wb_we_o  : std_ulogic;                                        -- read/write
  signal wb_sel_o : std_ulogic_vector(03 downto 0);                    -- byte enable
  signal wb_stb_o : std_ulogic;                                        -- strobe
  signal wb_cyc_o : std_ulogic;                                        -- valid cycle
  signal wb_ack_i : std_ulogic := 'L';                                 -- transfer acknowledge
  signal wb_err_i : std_ulogic := 'L';                                 -- transfer error
begin

  neorv32_top_inst : neorv32_top
  generic map(
    -- General --
    CLOCK_FREQUENCY   => CLOCK_FREQUENCY, -- clock frequency of clk_i in Hz
    INT_BOOTLOADER_EN => true,            -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM

    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_C      => true, -- implement compressed extension?
    CPU_EXTENSION_RISCV_M      => true, -- implement mul/div extension?
    CPU_EXTENSION_RISCV_Zicntr => true, -- implement base counters?

    -- Internal Instruction memory --
    MEM_INT_IMEM_EN   => true,              -- implement processor-internal instruction memory
    MEM_INT_IMEM_SIZE => MEM_INT_IMEM_SIZE, -- size of processor-internal instruction memory in bytes

    -- Internal Data memory --
    MEM_INT_DMEM_EN   => true,              -- implement processor-internal data memory
    MEM_INT_DMEM_SIZE => MEM_INT_DMEM_SIZE, -- size of processor-internal data memory in bytes

    -- Processor peripherals --
    IO_GPIO_NUM => 8,    -- number of GPIO input/output pairs (0..64)
    IO_MTIME_EN => true, -- implement machine system timer (MTIME)?
    IO_UART0_EN => true, -- implement primary universal asynchronous receiver/transmitter (UART0)?

    -- External memory interface (WISHBONE) --
    MEM_EXT_EN         => true,  -- implement external memory bus interface?
    MEM_EXT_TIMEOUT    => 255,   -- cycles after a pending bus access auto-terminates (0 = disabled)
    MEM_EXT_PIPE_MODE  => false, -- protocol: false=classic/standard wishbone mode, true=pipelined wishbone mode
    MEM_EXT_BIG_ENDIAN => false, -- byte order: true=big-endian, false=little-endian
    MEM_EXT_ASYNC_RX   => false, -- use register buffer for RX data when false
    MEM_EXT_ASYNC_TX   => false  -- use register buffer for TX data when false
  )
  port map(
    -- Global control --
    clk_i  => clk_i,  -- global clock, rising edge
    rstn_i => rstn_i, -- global reset, low-active, async

    -- GPIO (available if IO_GPIO_EN = true) --
    gpio_o => con_gpio_o, -- parallel output

    -- primary UART0 (available if IO_GPIO_NUM > 0) --
    uart0_txd_o => uart0_txd_o, -- UART0 send data
    uart0_rxd_i => uart0_rxd_i, -- UART0 receive data

    -- Wishbone bus interface (available if MEM_EXT_EN = true) --
    wb_tag_o => wb_tag_o, -- request tag
    wb_adr_o => wb_adr_o, -- address
    wb_dat_i => wb_dat_i, -- read data
    wb_dat_o => wb_dat_o, -- write data
    wb_we_o  => wb_we_o,  -- read/write
    wb_sel_o => wb_sel_o, -- byte enable
    wb_stb_o => wb_stb_o, -- strobe
    wb_cyc_o => wb_cyc_o, -- valid cycle
    wb_ack_i => wb_ack_i, -- transfer acknowledge
    wb_err_i => wb_err_i  -- transfer error

  );

  -- GPIO output --
  gpio_o <= con_gpio_o(7 downto 0);
  -- Wishbone to AvalonMM bridge
  read_o       <= '1' when (wb_stb_o = '1' and wb_we_o = '0') else '0';
  write_o      <= '1' when (wb_stb_o = '1' and wb_we_o = '1') else '0';
  address_o    <= std_logic_vector(wb_adr_o);
  writedata_o  <= std_logic_vector(wb_dat_o);
  byteenable_o <= std_logic_vector(wb_sel_o);

  wb_dat_i <= std_ulogic_vector(readdata_i);
  wb_ack_i <= not(waitrequest_i);
  wb_err_i <= '0';

end architecture;