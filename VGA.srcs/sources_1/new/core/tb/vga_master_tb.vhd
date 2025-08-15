library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity vga_master_tb is
end vga_master_tb;

architecture behavior of vga_master_tb is
    -- Constants
    constant CLK_PERIOD            : time := 10 ns;
    constant PIXEL_CLK_PERIOD      : time := 39.722 ns;

    constant COLOR_MAPPING_METHOD  : std_logic := '0';

    constant H_SYNC_PULSE          : natural := 96;
    constant H_BACK_PORCH          : natural := 48;
    constant ACTIVE_WIDTH          : natural := 640;
    constant H_FRONT_PORCH         : natural := 16;
    constant H_SYNC_POLARITY       : std_logic := '0';

    constant V_SYNC_PULSE          : natural := 2;
    constant V_BACK_PORCH          : natural := 31;
    constant ACTIVE_HEIGHT         : natural := 480;
    constant V_FRONT_PORCH         : natural := 11;
    constant V_SYNC_POLARITY       : std_logic := '0';

    constant R_BITS_PER_PIXEL      : natural := 1;
    constant G_BITS_PER_PIXEL      : natural := 1;
    constant B_BITS_PER_PIXEL      : natural := 1;
    constant OUTPUT_BITS_PER_PIXEL : natural := 12;

    -- Signals
    signal CLK       : std_logic := '0';
    signal PIXEL_CLK : std_logic := '0';
    signal RSTN      : std_logic := '0';

    signal X_POS     : natural range 0 to ACTIVE_WIDTH - 1 := 0;
    signal Y_POS     : natural range 0 to ACTIVE_HEIGHT - 1 := 0;
    signal RGB_IN    : unsigned(R_BITS_PER_PIXEL + G_BITS_PER_PIXEL + B_BITS_PER_PIXEL - 1 downto 0);

    signal ENABLE    : std_logic := '0';

    signal HSYNC     : std_logic;
    signal VSYNC     : std_logic;
    
    signal RGB_OUT : unsigned(OUTPUT_BITS_PER_PIXEL - 1 downto 0);

begin
    dut: entity work.vga_master
        generic map (
            COLOR_MAPPING_METHOD  => COLOR_MAPPING_METHOD,
            H_SYNC_PULSE          => H_SYNC_PULSE,
            H_BACK_PORCH          => H_BACK_PORCH,
            ACTIVE_WIDTH          => ACTIVE_WIDTH,
            H_FRONT_PORCH         => H_FRONT_PORCH,
            H_SYNC_POLARITY       => H_SYNC_POLARITY,

            V_SYNC_PULSE          => V_SYNC_PULSE,
            V_BACK_PORCH          => V_BACK_PORCH,
            ACTIVE_HEIGHT         => ACTIVE_HEIGHT,
            V_FRONT_PORCH         => V_FRONT_PORCH,
            V_SYNC_POLARITY       => V_SYNC_POLARITY,

            R_BITS_PER_PIXEL      => R_BITS_PER_PIXEL,
            G_BITS_PER_PIXEL      => G_BITS_PER_PIXEL,
            B_BITS_PER_PIXEL      => B_BITS_PER_PIXEL,
            OUTPUT_BITS_PER_PIXEL => OUTPUT_BITS_PER_PIXEL
        )
        port map (
            CLK       => CLK,
            RSTN      => RSTN,
            PIXEL_CLK => PIXEL_CLK,

            X_POS     => X_POS,
            Y_POS     => Y_POS,
            RGB_IN    => RGB_IN,

            ENABLE    => ENABLE,

            HSYNC     => HSYNC,
            VSYNC     => VSYNC,

            RGB_OUT   => RGB_OUT
        );

    -- Clock generation
    clk_process: process
    begin
        CLK <= '0';
        wait for CLK_PERIOD/2;
        CLK <= '1';
        wait for CLK_PERIOD/2;
    end process;

    pixel_clk_process: process
    begin
        PIXEL_CLK <= '0';
        wait for PIXEL_CLK_PERIOD/2;
        PIXEL_CLK <= '1';
        wait for PIXEL_CLK_PERIOD/2;
    end process;

    -- Test sequence
    stim_proc: process
    begin
        wait for 20 ns;
        RSTN   <= '1';
        wait for 20 ns;

        X_POS  <= 2;
        Y_POS  <= 4;
        RGB_IN <= to_unsigned(2, R_BITS_PER_PIXEL + G_BITS_PER_PIXEL + B_BITS_PER_PIXEL);

        ENABLE <= '1';
        wait for CLK_PERIOD;
        ENABLE <= '0';
        wait for CLK_PERIOD;


        wait;
    end process;
end behavior;
