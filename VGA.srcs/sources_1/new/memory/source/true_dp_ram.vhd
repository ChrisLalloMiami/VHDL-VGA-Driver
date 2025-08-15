library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

------------------------------------------------------------------------------------------------------------------------
entity true_dp_ram is
------------------------------------------------------------------------------------------------------------------------
  generic (
    gMEM_DEPTH           : natural;
    -- Memory depth of RAM

    gDATA_WIDTH          : natural;
    -- Bit width of RAM

    gNUM_PIPE_STAGES     : natural
    -- Number of clocks to pipeline read data
  );
  port (
    CLOCK_A              : in  std_logic;
    -- Clock for port A

    WR_EN_A              : in  std_logic;
    -- Specifies valid incoming write data for port A

    ADDR_A               : in  natural range 0 to gMEM_DEPTH - 1;
    -- Read/Write address for port A

    WR_DATA_A            : in  unsigned(gDATA_WIDTH - 1 downto 0);
    -- Write data for port A

    RD_DATA_A            : out unsigned(gDATA_WIDTH - 1 downto 0);
    -- Read data for port A

    CLOCK_B              : in  std_logic;
    -- Clock for port B

    WR_EN_B              : in  std_logic;
    -- Specifies valid incoming write data for port B

    ADDR_B               : in  natural range 0 to gMEM_DEPTH - 1;
    -- Read/Write address for port B

    WR_DATA_B            : in  unsigned(gDATA_WIDTH - 1 downto 0);
    -- Write data for port B

    RD_DATA_B            : out unsigned(gDATA_WIDTH - 1 downto 0)
    -- Read data for port B
  );
end true_dp_ram;

------------------------------------------------------------------------------------------------------------------------
architecture rtl of true_dp_ram is
------------------------------------------------------------------------------------------------------------------------

  type memory_t is array (integer range <>) of unsigned(gDATA_WIDTH - 1 downto 0);
  -- Type definition to hold memory

  shared variable ram_z : memory_t(0 to gMEM_DEPTH - 1);

------------------------------------------------------------------------------------------------------------------------
begin

------------------------------------------------------------------------------------------------------------------------
-- Generate access based on number of pipeline stages.
------------------------------------------------------------------------------------------------------------------------
  Gen0Stages: if (gNUM_PIPE_STAGES = 0) generate
  begin
  --------------------------------------------------------------------------------------------------
  -- Port A process.
  --------------------------------------------------------------------------------------------------
    PortA: process(CLOCK_A)
    begin
      if rising_edge(CLOCK_A) then
        if (WR_EN_A = '1') then
          ram_z(ADDR_A) := WR_DATA_A;
        end if;
        RD_DATA_A <= ram_z(ADDR_A);
      end if;
    end process PortA;

  --------------------------------------------------------------------------------------------------
  -- Port B process.
  --------------------------------------------------------------------------------------------------
    PortB: process(CLOCK_B)
    begin
      if rising_edge(CLOCK_B) then
        if (WR_EN_B = '1') then
          ram_z(ADDR_B) := WR_DATA_B;
        end if;
        RD_DATA_B <= ram_z(ADDR_B);
      end if;
    end process PortB;
  end generate;

  Gen1Stages: if (gNUM_PIPE_STAGES = 1) generate
    signal rd_data_a_z : unsigned(gDATA_WIDTH - 1 downto 0);
    signal rd_data_b_z : unsigned(gDATA_WIDTH - 1 downto 0);
  begin
  --------------------------------------------------------------------------------------------------
  -- Port A process.
  --------------------------------------------------------------------------------------------------
    PortA: process(CLOCK_A)
    begin
      if rising_edge(CLOCK_A) then
        if (WR_EN_A = '1') then
          ram_z(ADDR_A) := WR_DATA_A;
        end if;
        rd_data_a_z <= ram_z(ADDR_A);
        RD_DATA_A <= rd_data_a_z;
      end if;
    end process PortA;

  --------------------------------------------------------------------------------------------------
  -- Port B process.
  --------------------------------------------------------------------------------------------------
    PortB: process(CLOCK_B)
    begin
      if rising_edge(CLOCK_B) then
        if (WR_EN_B = '1') then
          ram_z(ADDR_B) := WR_DATA_B;
        end if;
        rd_data_b_z <= ram_z(ADDR_B);
        RD_DATA_B <= rd_data_b_z;
      end if;
    end process PortB;
  end generate;

  Gen2orMoreStages: if (gNUM_PIPE_STAGES >= 2) generate
    signal rd_data_a_zz : memory_t(gNUM_PIPE_STAGES - 1 downto 0);
    signal rd_data_b_zz : memory_t(gNUM_PIPE_STAGES - 1 downto 0);
  begin
  --------------------------------------------------------------------------------------------------
  -- Port A process.
  --------------------------------------------------------------------------------------------------
    PortA: process(CLOCK_A)
    begin
      if rising_edge(CLOCK_A) then
        if (WR_EN_A = '1') then
          ram_z(ADDR_A) := WR_DATA_A;
        end if;
        rd_data_a_zz(0) <= ram_z(ADDR_A);
        rd_data_a_zz(gNUM_PIPE_STAGES - 1 downto 1) <= rd_data_a_zz(gNUM_PIPE_STAGES - 2 downto 0);
        RD_DATA_A <= rd_data_a_zz(gNUM_PIPE_STAGES - 1);
      end if;
    end process PortA;

  --------------------------------------------------------------------------------------------------
  -- Port B process.
  --------------------------------------------------------------------------------------------------
    PortB: process(CLOCK_B)
    begin
      if rising_edge(CLOCK_B) then
        if (WR_EN_B = '1') then
          ram_z(ADDR_B) := WR_DATA_B;
        end if;
        rd_data_b_zz(0) <= ram_z(ADDR_B);
        rd_data_b_zz(gNUM_PIPE_STAGES - 1 downto 1) <= rd_data_b_zz(gNUM_PIPE_STAGES - 2 downto 0);
        RD_DATA_B <= rd_data_b_zz(gNUM_PIPE_STAGES - 1);
      end if;
    end process PortB;
  end generate;

end rtl;
