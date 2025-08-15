library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity my_vga_project is
    generic (
        -- Method used for color mapping (0 for bit replication, 1 for linear scaling)
		COLOR_MAPPING_METHOD     : std_logic := '0';

		-- Horizontal timing parameters in pixels
		H_SYNC_PULSE             : natural   := 96;
		H_BACK_PORCH             : natural   := 48;
		ACTIVE_WIDTH             : natural   := 640;
		H_FRONT_PORCH            : natural   := 16;
		H_SYNC_POLARITY          : std_logic := '0'; -- '0' for active low, '1' for active high

		-- Vertical timing parameters in lines
		V_SYNC_PULSE             : natural   := 2;
		V_BACK_PORCH             : natural   := 31;
		ACTIVE_HEIGHT            : natural   := 480;
		V_FRONT_PORCH            : natural   := 11;
		V_SYNC_POLARITY          : std_logic := '0'; -- '0' for active low, '1' for active high

		-- Color format
		-- NOTE: Zybo Z7-10 has 240KB of BRAM. 640x480x6 = 1,843,200 bits / 8 = 230.4KB
		R_BITS_PER_PIXEL         : natural   := 1;
		G_BITS_PER_PIXEL         : natural   := 1;
		B_BITS_PER_PIXEL         : natural   := 1;
		OUTPUT_BITS_PER_PIXEL    : natural   := 12 -- PMOD VGA uses RGB444. Use LUT to map input bits to ouput format
    );
    port (
        CLK            : in std_logic;
        RSTN           : in std_logic;

        PIXEL_CLK      : in std_logic;
        PIXEL_CLK_RSTN : in std_logic;

        HSYNC          : out std_logic;
        VSYNC          : out std_logic;
        RGB_OUT        : out unsigned(OUTPUT_BITS_PER_PIXEL - 1 downto 0)
    );
end my_vga_project;

architecture rtl of my_vga_project is
    signal temp_hsync   : std_logic;
    signal temp_vsync   : std_logic;
    signal temp_rgb_out : unsigned(OUTPUT_BITS_PER_PIXEL - 1 downto 0);

    signal ENABLE       : std_logic;
    signal RGB_IN       : unsigned(R_BITS_PER_PIXEL + G_BITS_PER_PIXEL + B_BITS_PER_PIXEL - 1 downto 0);
    signal X_POS        : natural range 0 to ACTIVE_WIDTH - 1; 
    signal Y_POS        : natural range 0 to ACTIVE_HEIGHT - 1;
begin
    HSYNC   <= temp_hsync;
    VSYNC   <= temp_vsync;
    RGB_OUT <= temp_rgb_out;

    vga_core: entity work.vga_master
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
            RSTN      => PIXEL_CLK_RSTN,
            PIXEL_CLK => PIXEL_CLK,

            X_POS     => X_POS,
            Y_POS     => Y_POS,
            RGB_IN    => RGB_IN,

            ENABLE    => ENABLE,

            HSYNC     => temp_hsync,
            VSYNC     => temp_vsync,

            RGB_OUT   => temp_rgb_out
        );

    DrawingManager_p: process(CLK)
    begin
        if rising_edge(CLK) then
            if (RSTN = '0') then
                ENABLE <= '0';
                RGB_IN <= to_unsigned(0, R_BITS_PER_PIXEL + G_BITS_PER_PIXEL + B_BITS_PER_PIXEL);
                X_POS  <= 0;
                Y_POS  <= 0;
            else
                RGB_IN <= to_unsigned(3, R_BITS_PER_PIXEL + G_BITS_PER_PIXEL + B_BITS_PER_PIXEL);
                ENABLE <= '1';
                if (X_POS < ACTIVE_WIDTH - 1) then
                    X_POS <= X_POS + 1;
                else
                    X_POS <= 0;
                    if (Y_POS < ACTIVE_HEIGHT - 1) then
                        Y_POS <= Y_POS + 1;
                    else
                        Y_POS <= 0;
                    end if;
                end if;
            end if;
        end if;
    end process;

end rtl;
