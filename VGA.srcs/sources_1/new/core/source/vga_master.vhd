library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity vga_master is
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
		CLK                      : in std_logic;  -- System clock
		RSTN                     : in std_logic;  -- Active low reset
		PIXEL_CLK                : in std_logic;  -- Input pixel clock

		X_POS                    : in natural range 0 to ACTIVE_WIDTH - 1; -- X position at which to draw
		Y_POS                    : in natural range 0 to ACTIVE_HEIGHT - 1; -- Y position at which to draw
		RGB_IN                   : in unsigned(R_BITS_PER_PIXEL + G_BITS_PER_PIXEL + B_BITS_PER_PIXEL - 1 downto 0);  -- Color of pixel to draw

		ENABLE                   : in std_logic; -- Enable signal; Writes RGB_IN at (X_POS, Y_POS) in memory

		-- Sync signals for VGA interface
		HSYNC                    : out std_logic;
		VSYNC                    : out std_logic;

		-- Parallel bus of RGB signals
		RGB_OUT                  : out unsigned(OUTPUT_BITS_PER_PIXEL - 1 downto 0)
	);
end vga_master;
 
architecture rtl of vga_master is
	------------------------------------ Constants ---------------------------------------
	constant TOTAL_WIDTH      : natural := ACTIVE_WIDTH + H_SYNC_PULSE + H_BACK_PORCH + H_FRONT_PORCH;
    constant TOTAL_HEIGHT     : natural := ACTIVE_HEIGHT + V_SYNC_PULSE + V_BACK_PORCH + V_FRONT_PORCH;

	------------------------------------- Signals ----------------------------------------
	signal x_index            : natural range 0 to TOTAL_WIDTH - 1; -- Current x index
	signal y_index            : natural range 0 to TOTAL_HEIGHT - 1; -- Current y index

	signal ram_x_index        : natural range 0 to ACTIVE_WIDTH - 1;
	signal ram_y_index        : natural range 0 to ACTIVE_HEIGHT - 1;

	signal pixel_data         : unsigned(R_BITS_PER_PIXEL + G_BITS_PER_PIXEL + B_BITS_PER_PIXEL - 1 downto 0);

	signal calc_addr_a        : natural range 0 to ACTIVE_WIDTH * ACTIVE_HEIGHT - 1;
	signal calc_addr_b        : natural range 0 to ACTIVE_WIDTH * ACTIVE_HEIGHT - 1;

	signal ram_rd_a           : unsigned(R_BITS_PER_PIXEL + G_BITS_PER_PIXEL + B_BITS_PER_PIXEL - 1 downto 0);
	signal ram_wr_en_b        : std_logic;
	signal ram_wr_data_b      : unsigned(R_BITS_PER_PIXEL + G_BITS_PER_PIXEL + B_BITS_PER_PIXEL - 1 downto 0);

	signal inActiveWidth      : std_logic;
	signal inActiveHeight     : std_logic;

	------------------------------------ Functions ---------------------------------------
	function replicate_bits (
		in_bits : unsigned(R_BITS_PER_PIXEL + G_BITS_PER_PIXEL + B_BITS_PER_PIXEL - 1 downto 0)
	) return unsigned is
		variable out_bits     : unsigned(OUTPUT_BITS_PER_PIXEL - 1 downto 0);
		constant NUM_BIT_REPS : natural := OUTPUT_BITS_PER_PIXEL / (R_BITS_PER_PIXEL + G_BITS_PER_PIXEL + B_BITS_PER_PIXEL);

		-- Split up input vector into individual RGB components
		constant rvec         : unsigned(R_BITS_PER_PIXEL - 1 downto 0) := in_bits(R_BITS_PER_PIXEL + G_BITS_PER_PIXEL + B_BITS_PER_PIXEL - 1 downto G_BITS_PER_PIXEL + B_BITS_PER_PIXEL);
		constant gvec         : unsigned(G_BITS_PER_PIXEL - 1 downto 0) := in_bits(G_BITS_PER_PIXEL + B_BITS_PER_PIXEL - 1 downto B_BITS_PER_PIXEL);
		constant bvec         : unsigned(B_BITS_PER_PIXEL - 1 downto 0) := in_bits(B_BITS_PER_PIXEL - 1 downto 0);

		-- Variables to store bit-repeated RGB components
		variable rvec_rep     : unsigned(R_BITS_PER_PIXEL * NUM_BIT_REPS - 1 downto 0);
		variable gvec_rep     : unsigned(G_BITS_PER_PIXEL * NUM_BIT_REPS - 1 downto 0);
		variable bvec_rep     : unsigned(B_BITS_PER_PIXEL * NUM_BIT_REPS - 1 downto 0);
	begin
		for ii in 0 to NUM_BIT_REPS - 1 loop
			rvec_rep((ii + 1) * rvec'length - 1 downto ii * rvec'length) := rvec;
			gvec_rep((ii + 1) * gvec'length - 1 downto ii * gvec'length) := gvec;
			bvec_rep((ii + 1) * bvec'length - 1 downto ii * bvec'length) := bvec;
		end loop;
		out_bits := rvec_rep & gvec_rep & bvec_rep;
		return out_bits;
	end function;
begin
	ram_wr_en_b <= '0';

	inActiveWidth <= '1' when x_index > H_SYNC_PULSE + H_BACK_PORCH - 1 and x_index < H_SYNC_PULSE + H_BACK_PORCH + ACTIVE_WIDTH - 1 else '0';
	inActiveHeight <= '1' when y_index > V_SYNC_PULSE + V_BACK_PORCH - 1 and y_index < V_SYNC_PULSE + V_BACK_PORCH + ACTIVE_HEIGHT - 1 else '0';

	----------------------------------- Components ---------------------------------------
	framebuffer_ram : entity work.true_dp_ram
		generic map (
			gMEM_DEPTH       => ACTIVE_WIDTH * ACTIVE_HEIGHT,
			gDATA_WIDTH      => R_BITS_PER_PIXEL + G_BITS_PER_PIXEL + B_BITS_PER_PIXEL,
			gNUM_PIPE_STAGES => 2
		)
		port map (
			CLOCK_A          => CLK,
			WR_EN_A          => ENABLE,
			ADDR_A           => calc_addr_a,
			WR_DATA_A        => RGB_IN,
			RD_DATA_A        => ram_rd_a,

			CLOCK_B          => PIXEL_CLK,
			WR_EN_B          => ram_wr_en_b,
			ADDR_B           => calc_addr_b,
			WR_DATA_B        => ram_wr_data_b,
			RD_DATA_B        => pixel_data
		);

	----------------------------------- Processes ----------------------------------------
	AddressCalculator_p : process(PIXEL_CLK)
	begin
		if rising_edge(PIXEL_CLK) then
			if (RSTN = '0') then
				calc_addr_a <= 0;
				calc_addr_b <= 0;
			else
				calc_addr_a <= Y_POS * ACTIVE_WIDTH + X_POS;
				calc_addr_b <= ram_y_index * ACTIVE_WIDTH + ram_x_index;
			end if;
		end if;
	end process;

	IndexManager_p : process(PIXEL_CLK)
	begin
		if rising_edge(PIXEL_CLK) then
			if (RSTN = '0') then
				-- We start counting at the beginning of the front porches
				x_index <= H_SYNC_PULSE + H_BACK_PORCH + ACTIVE_WIDTH;
				y_index <= V_SYNC_PULSE + V_BACK_PORCH + ACTIVE_HEIGHT;

				ram_x_index <= 0;
				ram_y_index <= 0;
			else
				-- Increment or reset x_index
				if (x_index < TOTAL_WIDTH - 1) then
					x_index <= x_index + 1;
				else
					x_index <= 0;
					-- Increment or reset y_index
					if (y_index < TOTAL_HEIGHT - 1) then
						y_index <= y_index + 1;
					else
						y_index <= 0;
					end if;
				end if;
				
				-- Set ram indices corresponding to window indices
				if (inActiveWidth = '1' and inActiveHeight = '1') then
					ram_x_index <= ram_x_index + 1;
				else
					ram_x_index <= 0;
					if (inActiveHeight = '1' and x_index = H_SYNC_PULSE + H_BACK_PORCH + ACTIVE_WIDTH - 1) then
						ram_y_index <= ram_y_index + 1;
					elsif (y_index = V_SYNC_PULSE + V_BACK_PORCH + ACTIVE_HEIGHT - 1) then
						ram_y_index <= 0;
					end if;
				end if;
			end if;
		end if;
	end process;

	SyncPulseManager_p : process(PIXEL_CLK)
	begin
		if rising_edge(PIXEL_CLK) then
			if (RSTN = '0') then
				HSYNC <= not H_SYNC_POLARITY;
				VSYNC <= not V_SYNC_POLARITY;
			else
				-- Set HSYNC in horizontal sync pulse region
				if (x_index >= 0 and x_index < H_SYNC_PULSE) then
					HSYNC <= H_SYNC_POLARITY;
				else
					HSYNC <= not H_SYNC_POLARITY;
				end if;
				-- Set VSYNC in vertical sync pulse region
				if (y_index >= 0 and y_index < V_SYNC_PULSE) then
					VSYNC <= V_SYNC_POLARITY;
				else
					VSYNC <= not V_SYNC_POLARITY;
				end if;
			end if;
		end if;
	end process;

	RGBOutputManager_p : process(PIXEL_CLK)
	begin
		if rising_edge(PIXEL_CLK) then
			if (RSTN = '0') then
				RGB_OUT <= (others => '0');
			else
				-- Bit replication method
				if (COLOR_MAPPING_METHOD = '0') then
					RGB_OUT <= replicate_bits(pixel_data);
				end if;
			end if;
		end if;
	end process;
end rtl;
