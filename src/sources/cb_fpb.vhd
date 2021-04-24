----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

----------------------------------------------------------------------------------
entity cb_fpb is
  Port (  
--  cb_bitslip_and      :     in  std_logic; --
  reset               :     in  std_logic;
  fpb_ready           :     out std_logic;
  fpb_s_d_in          :     in  std_logic;
  tx_ena              :     in  std_logic;
  fpb_s_d_out         :     out std_logic;
  tx_ready            :     out std_logic;
  new_frame           :     out std_logic;
  crc_check           :     out std_logic;
  frame_out           :     out std_logic_vector (79 downto 0);
  frame_in            :     in  std_logic_vector (79 downto 0);
--  isds_out            :     out std_logic_vector (7 downto 0); --
--  osds_out            :     out std_logic_vector (7 downto 0); --
  clk_40              :     in  std_logic;
  clk_160             :     in  std_logic;
  clk_200             :     in  std_logic
   );
end cb_fpb;
----------------------------------------------------------------------------------
architecture Behavioral of cb_fpb is
----------------------------------------------------------------------------------
component cb_fpb_calibrator is
  Port ( 
--    cb_state_number   :   out std_logic_vector (3 downto 0); --
    clk_div           :   in  std_logic;
    rst               :   in  std_logic;
    fpb_calib_done    :   out std_logic;
    isds_bitslip      :   out std_logic;
--    ld_dly            :   out std_logic;
    isds_p_d_in       :   in  std_logic_vector (7 downto 0);
    osds_p_d_out      :   out std_logic_vector (7 downto 0)
  );
end component;
----------------------------------------------------------------------------------
component fpb_rx is
generic (
frame_width :   integer :=  80
);
  Port (
  clk_div           :   in  std_logic;
  rst               :   in  std_logic;
  calib_done        :   in  std_logic;
  new_frame         :   out std_logic;
  crc_check         :   out std_logic;
  isds_p_data       :   in  std_logic_vector (7 downto 0);  
  frame_out         :   out std_logic_vector (frame_width-1 downto 0)
   );
end component;
----------------------------------------------------------------------------------
component fpb_tx is
generic (
frame_width :   integer :=  80
);
  Port (
  clk_div               :   in  std_logic;
  rst                   :   in  std_logic;
  calib_done            :   in  std_logic;
  ena                   :   in  std_logic;
  frame_in              :   in  std_logic_vector (frame_width-1 downto 0); 
  osds_p_data           :   out std_logic_vector (7 downto 0); 
  ready                 :   out std_logic  
   );
end component;
----------------------------------------------------------------------------------
--component isds_cb is
--component isds is
--  Port ( 
--  clk               :   in  std_logic;
--  clk_div           :   in  std_logic;
--  rst               :   in  std_logic;
--  isds_s_in         :   in  std_logic;  
--  bitslip           :   in  std_logic;
----  ld_dly            :   in  std_logic;
--  p_d_out           :   out std_logic_vector (7 downto 0)  
--  );
--end component;

component isds_dly is
  Port ( 
--  dly_val_out       :   out std_logic_vector (4 downto 0);  -- 
  clk_200           :   in  std_logic;
  clk               :   in  std_logic;
  clk_div           :   in  std_logic;
  rst               :   in  std_logic;
  isds_s_in         :   in  std_logic;
--  ld_dly            :   in  std_logic;
  bitslip           :   in  std_logic;  
  p_d_out           :   out std_logic_vector (7 downto 0)  
  );
end component;
----------------------------------------------------------------------------------
component osds is
  Port ( 
  clk               :   in  std_logic;
  clk_div           :   in  std_logic;
  rst               :   in  std_logic;
  p_data_in         :   in  std_logic_vector (7 downto 0);
  osds_s_out        :   out std_logic  
  );
end component;
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
--signal  bitslip_and_result  :   std_logic := '0';
signal  clk                 :   std_logic := '0';
signal  clk_div             :   std_logic := '0';
signal  isds_bitslip        :   std_logic := '0';
--signal  ld_dly              :   std_logic := '0';
signal  fpb_calib_done      :   std_logic := '0';
signal  r_rst               :   std_logic := '0';
signal  r_rst_1             :   std_logic := '0';
signal  isds_calib_rst      :   std_logic := '0';
signal  s_cb_bitslip_and    :   std_logic := '0';
signal  isds_p_data         :   std_logic_vector (7 downto 0) := (others => '0');
signal  osds_p_data         :   std_logic_vector (7 downto 0) := (others => '0');
signal  osds_p_data_tx      :   std_logic_vector (7 downto 0) := (others => '0');
signal  osds_p_data_calib   :   std_logic_vector (7 downto 0) := (others => '0');
----------------------------------------------------------------------------------
COMPONENT ila_sd
PORT (
	clk : IN STD_LOGIC;
	probe0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	probe1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
);
END COMPONENT  ;
----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
--ila_sd_cb : ila_sd
--PORT MAP (
--	clk => clk_40,
--	probe0 => osds_p_data,
--	probe1 => isds_p_data
--);
----------------------------------------------------------------------------------
clk <= clk_160;
clk_div <= clk_40;
----------------------------------------------------------------------------------
cb_fpb_calibrator_ins : cb_fpb_calibrator
  Port map( 
--    cb_state_number   => open,
    clk_div           => clk_div,
    rst               => r_rst,
--    ld_dly            => open,
    fpb_calib_done    => fpb_calib_done,
    isds_bitslip      => isds_bitslip,
    isds_p_d_in       => isds_p_data,
    osds_p_d_out      => osds_p_data_calib
  );
----------------------------------------------------------------------------------
--isds_ins : isds
--  Port map( 
--  clk               => clk,  
--  clk_div           => clk_div,
--  rst               => r_rst,
--  isds_s_in         => fpb_s_d_in,   
--  bitslip           => isds_bitslip,  
--  p_d_out           => isds_p_data 
--  );
--isds_out <= isds_p_data;

isds_ins : isds_dly
  Port map( 
  clk               => clk,  
  clk_div           => clk_div,
  clk_200           => clk_200,
  rst               => r_rst,
  isds_s_in         => fpb_s_d_in,  
  bitslip           => isds_bitslip,  
  p_d_out           => isds_p_data 
  );
----------------------------------------------------------------------------------
osds_ins : osds
  Port map( 
  clk               => clk,
  clk_div           => clk_div,  
  rst               => r_rst,
  p_data_in         => osds_p_data,
  osds_s_out        => fpb_s_d_out  
  );
osds_p_data <= osds_p_data_calib when fpb_calib_done = '0' else osds_p_data_tx;
--osds_out <= osds_p_data;
----------------------------------------------------------------------------------
fpb_rx_ins : fpb_rx
  Port map(
  clk_div           => clk_div,
  rst               => r_rst,
  calib_done        => fpb_calib_done,
  new_frame         => new_frame,
  crc_check         => crc_check,
  isds_p_data       => isds_p_data,  
  frame_out         => frame_out
   );
----------------------------------------------------------------------------------
fpb_tx_ins : fpb_tx
  Port map(
  clk_div               => clk_div,
  rst                   => r_rst,
  calib_done            => fpb_calib_done,
  ena                   => tx_ena,
  frame_in              => frame_in,   
  osds_p_data           => osds_p_data_tx,  
  ready                 => tx_ready  
   );
----------------------------------------------------------------------------------
process (clk_div)
variable reset_counter : integer := 0;
begin
if rising_edge (clk_div) then
    if reset = '1' then 
        reset_counter := 0;
        r_rst   <= '1';
    else 
        if reset_counter >= 15 then
            r_rst   <= '0';
            reset_counter   := reset_counter;
        else
            reset_counter := reset_counter + 1;
            r_rst   <= '1';
        end if;
    end if;
end if;
end process;
----------------------------------------------------------------------------------
fpb_ready <= fpb_calib_done;
----------------------------------------------------------------------------------
end Behavioral;
----------------------------------------------------------------------------------