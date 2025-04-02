----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/02/2025 03:57:49 PM
-- Design Name: 
-- Module Name: vga_master - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vga_master is
	generic (
		-- Rate at which pixels are drawn in Hz
		PIXEL_CLOCK_FREQ   : natural := 25175000;

		-- Horizontal timing parameters in pixels
		ACTIVE_WIDTH       : natural := 640;
		H_FRONT_PORCH      : natural := 16;
		H_BACK_PORCH       : natural := 48;
		H_SYNC_PULSE       : natural := 96;

		-- Vertical timing parameters in lines
		ACTIVE_HEIGHT      : natural := 480;
		V_FRONT_PORCH      : natural := 11;
		V_BACK_PORCH       : natural := 31;
		V_SYNC_PULSE       : natural := 2
	);
	port (
		pixel_clk     : in std_logic;  -- Input pixel clock

		hsync         : out std_logic;
		vsync         : out std_logic;

		video_display : out std_logic; -- High when display on

		h_count       : out std_logic_vector(9 downto 0);
		v_count       : out std_logic_vector(9 downto 0)
	);
end vga_master;
 
architecture rtl of vga_master is
	constant TOTAL_H_WIDTH : integer := ACTIVE_WIDTH + H_SYNC_PULSE + H_BACK_PORCH + H_FRONT_PORCH;
    constant TOTAL_V_HEIGHT  : integer := ACTIVE_HEIGHT + V_SYNC_PULSE + V_BACK_PORCH + V_FRONT_PORCH;
begin
--   and_gate   <= input_1 and input_2;
--   and_result <= and_gate;
	hsync <= '0';
	vsync <= '0';
	video_display <= '0';
	h_count <= (others => '0');
	v_count <= (others => '0');
end rtl;