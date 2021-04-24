----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;
----------------------------------------------------------------------------------
entity isds_dly is
  Port ( 
  clk_200           :   in  std_logic;
  clk               :   in  std_logic;
  clk_div           :   in  std_logic;
  rst               :   in  std_logic;
  isds_s_in         :   in  std_logic;
--  ld_dly            :   in  std_logic;
  bitslip           :   in  std_logic;  
--  dly_val_out       :   out std_logic_vector (4 downto 0);  -- 
  p_d_out           :   out std_logic_vector (7 downto 0)  
  );
end isds_dly;
----------------------------------------------------------------------------------
architecture Behavioral of isds_dly is
----------------------------------------------------------------------------------
constant  delay_step            :   std_logic_vector (4 downto 0) := "01110"; -- every delay step is 78ps for 200MHz ref clock,
-- we need at least 720ps delay so we add 11*78ps = 858ps delay to make sure that we have passed iserdes setup time and hold time   
--signal  ip_bitslip              :   std_logic_vector (0 downto 0) := (others => '0');
--signal  data_in_from_pins       :   std_logic_vector (0 downto 0) := (others => '0');
--signal  data_in_to_device       :   std_logic_vector (7 downto 0) := (others => '0');
signal  isds_data               :   std_logic_vector (7 downto 0) := (others => '0');
signal  clkb                    :   std_logic;
signal  s_clk                   :   std_logic;
signal  r_rst                   :   std_logic;
signal  dly_out                 :   std_logic;
--signal  r_ld_dly                :   std_logic;
----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
clkb <= not s_clk;
----------------------------------------------------------------------------------
p_d_out <= isds_data;
----------------------------------------------------------------------------------
   IDELAYCTRL_inst : IDELAYCTRL
port map (
RDY => open,       -- 1-bit output: Ready output
REFCLK => clk_200, -- 1-bit input: Reference clock input
RST => '0'        -- 1-bit input: Active high reset input
);
----------------------------------------------------------------------------------
   IDELAYE2_inst : IDELAYE2
generic map (
CINVCTRL_SEL => "FALSE",          -- Enable dynamic clock inversion (FALSE, TRUE)
DELAY_SRC => "IDATAIN",           -- Delay input (IDATAIN, DATAIN)
HIGH_PERFORMANCE_MODE => "FALSE", -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
IDELAY_TYPE => "VARIABLE",           -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
IDELAY_VALUE => 0,                -- Input delay tap setting (0-31)
PIPE_SEL => "FALSE",              -- Select pipelined mode, FALSE, TRUE
REFCLK_FREQUENCY => 200.0,        -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
SIGNAL_PATTERN => "DATA"          -- DATA, CLOCK input signal
)
port map (
CNTVALUEOUT => open, -- 5-bit output: Counter value output
DATAOUT => dly_out,         -- 1-bit output: Delayed data output
C => clk_div,                     -- 1-bit input: Clock input
CE => '0',                   -- 1-bit input: Active high enable increment/decrement input
CINVCTRL => '0',       -- 1-bit input: Dynamic clock inversion input
CNTVALUEIN => "00000",   -- 5-bit input: Counter value input
DATAIN => '0',           -- 1-bit input: Internal delay data input
IDATAIN => isds_s_in,         -- 1-bit input: Data input from the I/O
INC => '1',                 -- 1-bit input: Increment / Decrement tap delay input
LD => '0',                   -- 1-bit input: Load IDELAY_VALUE input
LDPIPEEN => '0',       -- 1-bit input: Enable PIPELINE register to load data input
REGRST => '0'            -- 1-bit input: Active-high reset tap-delay input
);
----------------------------------------------------------------------------------
   ISERDESE2_inst : ISERDESE2
generic map (
DATA_RATE => "DDR",           -- DDR, SDR
DATA_WIDTH => 8,              -- Parallel data width (2-8,10,14)
DYN_CLKDIV_INV_EN => "FALSE", -- Enable DYNCLKDIVINVSEL inversion (FALSE, TRUE)
DYN_CLK_INV_EN => "FALSE",    -- Enable DYNCLKINVSEL inversion (FALSE, TRUE)
-- INIT_Q1 - INIT_Q4: Initial value on the Q outputs (0/1)
INIT_Q1 => '0',
INIT_Q2 => '0',
INIT_Q3 => '0',
INIT_Q4 => '0',
INTERFACE_TYPE => "NETWORKING",   -- MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
IOBDELAY => "IFD",           -- NONE, BOTH, IBUF, IFD
NUM_CE => 1,                  -- Number of clock enables (1,2)
OFB_USED => "FALSE",          -- Select OFB path (FALSE, TRUE)
SERDES_MODE => "MASTER",      -- MASTER, SLAVE
-- SRVAL_Q1 - SRVAL_Q4: Q output values when SR is used (0/1)
SRVAL_Q1 => '0',
SRVAL_Q2 => '0',
SRVAL_Q3 => '0',
SRVAL_Q4 => '0'
)
port map (
O => Open,                       -- 1-bit output: Combinatorial output
-- Q1 - Q8: 1-bit (each) output: Registered data outputs
Q1 => isds_data(7),
Q2 => isds_data(6),
Q3 => isds_data(5),
Q4 => isds_data(4),
Q5 => isds_data(3),
Q6 => isds_data(2),
Q7 => isds_data(1),
Q8 => isds_data(0),   
-- SHIFTOUT1, SHIFTOUT2: 1-bit (each) output: Data width expansion output ports
SHIFTOUT1 => Open,
SHIFTOUT2 => Open,
BITSLIP => bitslip,           -- 1-bit input: The BITSLIP pin performs a Bitslip operation synchronous to
--   BITSLIP => '0',           -- 1-bit input: The BITSLIP pin performs a Bitslip operation synchronous to
                              -- CLKDIV when asserted (active High). Subsequently, the data seen on the
                              -- Q1 to Q8 output ports will shift, as in a barrel-shifter operation, one
                              -- position every time Bitslip is invoked (DDR operation is different from
                              -- SDR).

-- CE1, CE2: 1-bit (each) input: Data register clock enable inputs
CE1 => '1',
CE2 => '0',
CLKDIVP => '0',           -- 1-bit input: TBD
-- Clocks: 1-bit (each) input: ISERDESE2 clock input ports
CLK => CLK,                   -- 1-bit input: High-speed clock
CLKB => CLKB,                 -- 1-bit input: High-speed secondary clock
CLKDIV => CLK_DIV,             -- 1-bit input: Divided clock
OCLK => '0',                 -- 1-bit input: High speed output clock used when INTERFACE_TYPE="MEMORY" 
-- Dynamic Clock Inversions: 1-bit (each) input: Dynamic clock inversion pins to switch clock polarity
DYNCLKDIVSEL => '0', -- 1-bit input: Dynamic CLKDIV inversion
DYNCLKSEL => '0',       -- 1-bit input: Dynamic CLK/CLKB inversion
-- Input Data: 1-bit (each) input: ISERDESE2 data input ports
D => '0',                       -- 1-bit input: Data input
--D => dly_out,                       -- 1-bit input: Data input
DDLY => dly_out,                 -- 1-bit input: Serial data from IDELAYE2
OFB => '0',                   -- 1-bit input: Data feedback from OSERDESE2
OCLKB => '0',               -- 1-bit input: High speed negative edge output clock
RST => r_rst,                   -- 1-bit input: Active high asynchronous reset
-- SHIFTIN1, SHIFTIN2: 1-bit (each) input: Data width expansion input ports
SHIFTIN1 => '0',
SHIFTIN2 => '0'
);
----------------------------------------------------------------------------------
s_clk <= clk;
----------------------------------------------------------------------------------
process (clk_div)
begin
if rising_edge (clk_div) then
--r_ld_dly <= ld_dly;
r_rst <= rst;
end if;
end process;
----------------------------------------------------------------------------------

end Behavioral;
----------------------------------------------------------------------------------