----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
----------------------------------------------------------------------------------
library UNISIM;
use UNISIM.VComponents.all;
----------------------------------------------------------------------------------
entity osds is
  Port ( 
  clk               :   in  std_logic;
  clk_div           :   in  std_logic;
  rst               :   in  std_logic;
  p_data_in         :   in  std_logic_vector (7 downto 0);
  osds_s_out        :   out std_logic  
  );
end osds;
----------------------------------------------------------------------------------
architecture Behavioral of osds is
----------------------------------------------------------------------------------
signal  r_rst : std_logic;
----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
   OSERDESE2_inst : OSERDESE2
generic map (
DATA_RATE_OQ => "DDR",   -- DDR, SDR
DATA_RATE_TQ => "DDR",   -- DDR, BUF, SDR
DATA_WIDTH => 8,         -- Parallel data width (2-8,10,14)
INIT_OQ => '0',          -- Initial value of OQ output (1'b0,1'b1)
INIT_TQ => '0',          -- Initial value of TQ output (1'b0,1'b1)
SERDES_MODE => "MASTER", -- MASTER, SLAVE
SRVAL_OQ => '0',         -- OQ output value when SR is used (1'b0,1'b1)
SRVAL_TQ => '0',         -- TQ output value when SR is used (1'b0,1'b1)
TBYTE_CTL => "FALSE",    -- Enable tristate byte operation (FALSE, TRUE)
TBYTE_SRC => "FALSE",    -- Tristate byte source (FALSE, TRUE)
TRISTATE_WIDTH => 1      -- 3-state converter width (1,4)
)
port map (
OFB => open,             -- 1-bit output: Feedback path for data
OQ => osds_s_out,               -- 1-bit output: Data path output
-- SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
SHIFTOUT1 => open,
SHIFTOUT2 => open,
TBYTEOUT => open,   -- 1-bit output: Byte group tristate
TFB => open,             -- 1-bit output: 3-state control
TQ => open,               -- 1-bit output: 3-state control
CLK => CLK,             -- 1-bit input: High speed clock
CLKDIV => CLK_DIV,       -- 1-bit input: Divided clock
-- D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
D1 => p_data_in(0),
D2 => p_data_in(1),
D3 => p_data_in(2),
D4 => p_data_in(3),
D5 => p_data_in(4),
D6 => p_data_in(5),
D7 => p_data_in(6),
D8 => p_data_in(7),
OCE => '1',             -- 1-bit input: Output data clock enable
RST => rst,             -- 1-bit input: Reset
-- SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
SHIFTIN1 => '0',
SHIFTIN2 => '0',
-- T1 - T4: 1-bit (each) input: Parallel 3-state inputs
T1 => '0',
T2 => '0',
T3 => '0',
T4 => '0',
TBYTEIN => '0',     -- 1-bit input: Byte group tristate
TCE => '0'              -- 1-bit input: 3-state clock enable
);
----------------------------------------------------------------------------------
--process (clk_div)
--variable reset_counter : integer := 0;
--begin
--if rising_edge (clk_div) then
--    if rst = '1' then 
--        reset_counter := 0;
--        r_rst   <= '1';
--    else 
--        if reset_counter >= 15 then
--            r_rst   <= '0';
--            reset_counter   := reset_counter;
--        else
--            reset_counter := reset_counter + 1;
--            r_rst   <= '1';
--        end if;
--    end if;
--end if;
--end process;
----------------------------------------------------------------------------------
end Behavioral;
----------------------------------------------------------------------------------