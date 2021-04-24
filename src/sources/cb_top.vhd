----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
----------------------------------------------------------------------------------
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;
----------------------------------------------------------------------------------
entity cb_top is
  Port ( 
    i_frame                 : in  std_logic_vector(80-1 downto 0); -- input frame from GBT
    i_frame_en              : in  std_logic; -- input frame enable from GBT    
    o_frame                 : out std_logic_vector(80-1 downto 0); -- output frame to GBT
    o_frame_en              : out std_logic; -- output frame enable to GBT
    i_reset               : in    std_logic;
    o_fpb_cal               : out    std_logic;
  
  fpb_s_d_in : in std_logic_vector (8 downto 0); 
  fpb_s_d_out : out std_logic_vector (8 downto 0);     
  p_sda_in_to_feb_p         : OUT   std_logic;                      
--  p_sda_in_to_feb_n         : OUT   std_logic;                                          
  p_scl_in_to_feb_p         : OUT   std_logic;
--  p_scl_in_to_feb_n         : OUT   std_logic;   
  p_sda_out_from_feb_p      : IN    std_logic;                      
--  p_sda_out_from_feb_n      : IN    std_logic;   
  adg_mux_out               : out    STD_LOGIC_VECTOR(3 DOWNTO 0);
  adc_conv                  : OUT    STD_LOGIC;                                 
  adc_scl                   : INOUT  STD_LOGIC;                                 
  adc_sda                   : INOUT  STD_LOGIC; 
  o_clk_40                  : out    STD_LOGIC; 
  o_clk_160                 : out    STD_LOGIC; 
  o_clk_200                 : out    STD_LOGIC; 
  clk_in1_p                 : in     std_logic;
  clk_in1_n                 : in     std_logic
  );
end cb_top;
----------------------------------------------------------------------------------
architecture Behavioral of cb_top is
----------------------------------------------------------------------------------
component cb_mmcm is
  Port (
  clk_40            : out    std_logic;
  clk_160           : out    std_logic;
  clk_200           : out    std_logic;
  locked            : out    std_logic;
  clk_in1_p         : in     std_logic;
  clk_in1_n         : in     std_logic
   );
end component;
----------------------------------------------------------------------------------
component cb_sm is
generic(
    FRAMELENGTH : integer := 80;
    FPBLENGTH : integer := 80;
    INSTOPCODELENGTH : integer := 5; --*
    PACKETINDEXLENGTH : integer := 21
);
  Port (
    i_clk_40                : in  std_logic; -- LHC main clock
    i_reset                 : in  std_logic; -- not MMCM lock
    i_init_done             : in  std_logic; -- done from initialization state machine
    
    i_frame                 : in  std_logic_vector(FRAMELENGTH-1 downto 0); -- input frame from GBT
    i_frame_en              : in  std_logic; -- input frame enable from GBT
    
    o_frame                 : out std_logic_vector(FRAMELENGTH-1 downto 0); -- output frame to GBT
    o_frame_en              : out std_logic; -- output frame enable to GBT
    
    -- vahid's ports
    -- ADC controller ports
    i_adc_done              : in  std_logic; -- will be '1' when getting adc value correctly 
    i_adc_ack_error         : in  std_logic; -- i2c master error signal, when is '1' shows adc connection error
    o_adc_enable            : out std_logic; -- enables adc controller
    o_adc_adg_mux           : out std_logic_vector (3 downto 0); -- ADG706BRUZ selector signals
    o_adc_channel           : out std_logic_vector (2 downto 0); -- selects one of ADC four channels
    i_adc_data              : in  std_logic_vector (9 downto 0); -- ADC output data
    -- FEB controller ports
    o_ena_feb_controller    : out std_logic;                    
    o_feb_chip_selector     : out std_logic;                    
    o_db_output_selector    : out std_logic;                    
    o_db_selector           : out std_logic_vector (2 downto 0);                     
    o_feb_selector          : out std_logic_vector (1 downto 0);                     
    o_channel_selector      : out std_logic_vector (2 downto 0);                    
    o_feb_command           : out std_logic_vector (2 downto 0);                    
    i_feb_done              : in  std_logic;                    
    i_feb_connection_error  : in  std_logic;                    
    i_data_from_feb         : in  std_logic_vector (9 downto 0);                                        
    o_data_to_feb           : out std_logic_vector (9 downto 0);
    -- end of vahid's ports
        
    i_fpb_frame_0           : in  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB0
    i_fpb_frame_1           : in  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB1
    i_fpb_frame_2           : in  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB2
    i_fpb_frame_3           : in  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB3
    i_fpb_frame_4           : in  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB4
    i_fpb_frame_5           : in  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB5
    i_fpb_frame_6           : in  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB6
    i_fpb_frame_7           : in  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB7
    i_fpb_frame_8           : in  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB8
    i_fpb_frame_en          : in  std_logic_vector(8 downto 0); -- input frame enable from FPBi
    i_fpb_tx_ready          : in  std_logic_vector(8 downto 0); -- input frame  from FPBi
    i_fpb_calib_done        : in  std_logic_vector(8 downto 0); -- input frame  from FPBi
    i_fpb_crc_check         : in  std_logic_vector(8 downto 0); -- input frame  from FPBi
    
    o_fpb_frame_0           : out  std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB0
    o_fpb_frame_1           : out  std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB1
    o_fpb_frame_2           : out  std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB2
    o_fpb_frame_3           : out  std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB3
    o_fpb_frame_4           : out  std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB4
    o_fpb_frame_5           : out  std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB5
    o_fpb_frame_6           : out  std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB6
    o_fpb_frame_7           : out  std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB7
    o_fpb_frame_8           : out  std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB8
    o_fpb_frame_en          : out  std_logic_vector(8 downto 0) -- output frame enable to FPBi
   );
end component;
----------------------------------------------------------------------------------
component adc_controller IS
  GENERIC(
    sys_clk_freq     : INTEGER := 40_000_000;                     
    ADC_ADDRESS      : STD_LOGIC_VECTOR(6 DOWNTO 0) := "0101001"); 
  PORT(
    clk         : IN    STD_LOGIC;                                 
    reset       : IN    STD_LOGIC;                                
    scl         : INOUT STD_LOGIC;                                 
    sda         : INOUT STD_LOGIC;                               
    adc_ack_err : OUT   STD_LOGIC;                              
    adc_done    : OUT   STD_LOGIC;                              
    adc_ena     : IN    STD_LOGIC;                                 
    adc_conv    : out    STD_LOGIC;                                 
    ch_sel      : IN    STD_LOGIC_VECTOR(2 DOWNTO 0);
    adg_mux_in  : IN    STD_LOGIC_VECTOR(3 DOWNTO 0);
    adg_mux_out : out   STD_LOGIC_VECTOR(3 DOWNTO 0);
    adc_data    : OUT   STD_LOGIC_VECTOR(9 DOWNTO 0)   
    ); 
END component;
----------------------------------------------------------------------------------
component feb_controller is
  Port (     
  clk_40                : in    std_logic;                    
  rst                   : in    std_logic;                    
  ena_feb_controller    : in    std_logic;                    
  feb_chip_selector     : in    std_logic;                    
  db_output_selector    : in    std_logic;                    
  db_selector           : in    std_logic_vector (2 downto 0);                     
  feb_selector          : in    std_logic_vector (1 downto 0);                     
  channel_selector      : in    std_logic_vector (2 downto 0);                    
  command               : in    std_logic_vector (2 downto 0);                    
  cmd_done              : out   std_logic;                    
  feb_connection_error  : out   std_logic;                    
  data_from_feb         : out   std_logic_vector (9 downto 0);                                       
  data_to_feb           : in    std_logic_vector (9 downto 0);                      
  sda_in_to_feb_p       : OUT   std_logic_vector (7 downto 0);                      
  sda_in_to_feb_n       : OUT   std_logic_vector (7 downto 0);                                          
  scl_in_to_feb_p       : OUT   std_logic_vector (7 downto 0);
  scl_in_to_feb_n       : OUT   std_logic_vector (7 downto 0);   
  sda_out_from_feb_p    : IN    std_logic_vector (7 downto 0);                      
  sda_out_from_feb_n    : IN    std_logic_vector (7 downto 0)
  );
end component;
----------------------------------------------------------------------------------
component cb_fpb is
  Port (  
  crc_check           :     out std_logic;
  reset               :     in  std_logic;
  fpb_ready           :     out std_logic;
  fpb_s_d_in          :     in  std_logic;
  tx_ena              :     in  std_logic;
  fpb_s_d_out         :     out std_logic;
  tx_ready            :     out std_logic;
  new_frame           :     out std_logic;
  frame_out           :     out std_logic_vector (79 downto 0);
  frame_in            :     in  std_logic_vector (79 downto 0);
  clk_40              :     in  std_logic;
  clk_160             :     in  std_logic;
  clk_200             :     in  std_logic
   );
end component;
----------------------------------------------------------------------------------
--COMPONENT vio
--  PORT (
--    clk : IN STD_LOGIC;  
--    probe_out0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
--    probe_out1 : OUT STD_LOGIC_VECTOR(79 DOWNTO 0)
--  );
--END COMPONENT;
----------------------------------------------------------------------------------
--COMPONENT ila

--PORT (
--	clk : IN STD_LOGIC;
--	probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--	probe1 : IN STD_LOGIC_VECTOR(79 DOWNTO 0);
--	probe2 : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
--	probe3 : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
--	probe4 : IN STD_LOGIC_VECTOR(9 DOWNTO 0)
--);
--END COMPONENT  ;
----------------------------------------------------------------------------------
constant  FRAMELENGTH             : integer := 80;
signal    clk_40                  : std_logic := '0';
signal    locked                  : std_logic := '0';
signal    reset                   : std_logic := '0';
--signal    i_frame                 : std_logic_vector(FRAMELENGTH-1 downto 0); -- input frame from GBT
--signal    i_frame_en              : std_logic; -- input frame enable from GBT   
--signal    o_frame                 : std_logic_vector(FRAMELENGTH-1 downto 0); -- output frame to GBT
--signal    o_frame_en              : std_logic_vector (0 downto 0); -- output frame enable to GBT
signal    i_adc_done              : std_logic; -- will be '1' when getting adc value correctly 
signal    i_adc_ack_error         : std_logic; -- i2c master error signal, when is '1' shows adc connection error
signal    o_adc_enable            : std_logic; -- enables adc controller
signal    o_adc_adg_mux           : std_logic_vector (3 downto 0); -- ADG706BRUZ selector signals
signal    o_adc_channel           : std_logic_vector (2 downto 0); -- selects one of ADC four channels
signal    i_adc_data              : std_logic_vector (9 downto 0); -- ADC output data
signal    o_ena_feb_controller    : std_logic;                    
signal    o_feb_chip_selector     : std_logic;                    
signal    o_db_output_selector    : std_logic;                    
signal    o_db_selector           : std_logic_vector (2 downto 0);                     
signal    o_feb_selector          : std_logic_vector (1 downto 0);                     
signal    o_channel_selector      : std_logic_vector (2 downto 0);                    
signal    o_feb_command           : std_logic_vector (2 downto 0);                    
signal    i_feb_done              : std_logic;                    
signal    i_feb_connection_error  : std_logic;                    
signal    i_data_from_feb         : std_logic_vector (9 downto 0);                                        
signal    o_data_to_feb           : std_logic_vector (9 downto 0);
signal    sda_in_to_feb_p         : std_logic_vector (7 downto 0);                      
signal    sda_in_to_feb_n         : std_logic_vector (7 downto 0);                                          
signal    scl_in_to_feb_p         : std_logic_vector (7 downto 0);
signal    scl_in_to_feb_n         : std_logic_vector (7 downto 0);   
signal    sda_out_from_feb_p      : std_logic_vector (7 downto 0);                      
signal    sda_out_from_feb_n      : std_logic_vector (7 downto 0);
signal    enable_probe            : std_logic_vector (0 downto 0);
signal    data_probe              : std_logic_vector (9 downto 0);
signal    r_enable_1              : std_logic;
signal    r_enable_2              : std_logic;
----------------------------------------------------------------------------------
signal clk_160 : std_logic;  
signal clk_200 : std_logic;  
constant FPBLENGTH : integer := 80;  
signal    i_fpb_frame_0           :  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB0
signal    i_fpb_frame_1           :  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB1
signal    i_fpb_frame_2           :  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB2
signal    i_fpb_frame_3           :  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB3
signal    i_fpb_frame_4           :  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB4
signal    i_fpb_frame_5           :  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB5
signal    i_fpb_frame_6           :  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB6
signal    i_fpb_frame_7           :  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB7
signal    i_fpb_frame_8           :  std_logic_vector(FPBLENGTH-1 downto 0); -- input frame from FPB8
signal    i_fpb_frame_en          :  std_logic_vector(8 downto 0) := (others => '0'); -- input frame enable from FPBi
signal    s_fpb_tx_ready          :  std_logic_vector(8 downto 0); -- input frame  from FPBi
signal    s_fpb_calib_done        :  std_logic_vector(8 downto 0); -- input frame  from FPBi
signal    s_fpb_crc_check         :  std_logic_vector(8 downto 0); -- input frame  from FPBi    
signal    o_fpb_frame_0           :   std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB0
signal    o_fpb_frame_1           :   std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB1
signal    o_fpb_frame_2           :   std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB2
signal    o_fpb_frame_3           :   std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB3
signal    o_fpb_frame_4           :   std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB4
signal    o_fpb_frame_5           :   std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB5
signal    o_fpb_frame_6           :   std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB6
signal    o_fpb_frame_7           :   std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB7
signal    o_fpb_frame_8           :   std_logic_vector(FPBLENGTH-1 downto 0); -- output frame to FPB8
signal    o_fpb_frame_en          :   std_logic_vector(8 downto 0); -- output frame enable to FPBi 
----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
o_fpb_cal <= s_fpb_calib_done(0);
----------------------------------------------------------------------------------
reset <= not locked OR i_reset;
----------------------------------------------------------------------------------
o_clk_40 <= clk_40;
o_clk_200 <= clk_200;
o_clk_160 <= clk_160;
----------------------------------------------------------------------------------
--mmcm_ins : cb_mmcm
--   port map ( 
--  -- Clock out ports  
--   clk_40 => clk_40,
--   clk_160 => clk_160,
--   clk_200 => clk_200,
--  -- Status and control signals                
--   locked => locked,
--   -- Clock in ports
--   clk_in1 => clk_in1_p
----   clk_in1_p => clk_in1_p,
----   clk_in1_n => clk_in1_n
-- );
 
 mmcm_ins : cb_mmcm
    port map ( 
   -- Clock out ports  
    clk_40 => clk_40,
    clk_160 => clk_160,
    clk_200 => clk_200,
   -- Status and control signals                
    locked => locked,
    -- Clock in ports
    clk_in1_p => clk_in1_p,
    clk_in1_n => clk_in1_n
  );
----------------------------------------------------------------------------------
cb_sm_ins : cb_sm 
port map (

    i_clk_40                => clk_40         ,
    i_reset                 => reset          ,
    i_init_done             => '1'      ,
							
    i_frame                 => i_frame          ,
    i_frame_en              => i_frame_en       ,
							
    o_frame                 => o_frame          ,
    o_frame_en              => o_frame_en       ,
							   
    i_adc_done              => i_adc_done       ,
    i_adc_ack_error         => i_adc_ack_error  ,
    o_adc_enable            => o_adc_enable     ,
    o_adc_adg_mux           => o_adc_adg_mux    ,
    o_adc_channel           => o_adc_channel    ,
    i_adc_data              => i_adc_data       ,
    
    o_ena_feb_controller    => o_ena_feb_controller   ,
    o_feb_chip_selector     => o_feb_chip_selector    ,
    o_db_output_selector    => o_db_output_selector   ,
    o_db_selector           => o_db_selector          ,                    
    o_feb_selector          => o_feb_selector         ,                    
    o_channel_selector      => o_channel_selector     ,                   
    o_feb_command           => o_feb_command          ,                   
    i_feb_done              => i_feb_done             ,
    i_feb_connection_error  => i_feb_connection_error ,
    i_data_from_feb         => i_data_from_feb        ,                                       
    o_data_to_feb           => o_data_to_feb          ,
						
    i_fpb_frame_0           => i_fpb_frame_0    ,
    i_fpb_frame_1           => ( others =>'0')    ,
    i_fpb_frame_2           => ( others =>'0')    ,
    i_fpb_frame_3           => ( others =>'0')    ,
    i_fpb_frame_4           => ( others =>'0')    ,
    i_fpb_frame_5           => ( others =>'0')    ,
    i_fpb_frame_6           => ( others =>'0')    ,
    i_fpb_frame_7           => ( others =>'0')    ,
    i_fpb_frame_8           => ( others =>'0')    ,
    i_fpb_frame_en          => i_fpb_frame_en   ,
    i_fpb_tx_ready          => s_fpb_tx_ready   ,
    i_fpb_calib_done        => s_fpb_calib_done   ,
    i_fpb_crc_check         => s_fpb_crc_check   ,
    
    o_fpb_frame_0           => o_fpb_frame_0    ,
    o_fpb_frame_1           => open    ,
    o_fpb_frame_2           => open    ,
    o_fpb_frame_3           => open    ,
    o_fpb_frame_4           => open    ,
    o_fpb_frame_5           => open    ,
    o_fpb_frame_6           => open    ,
    o_fpb_frame_7           => open    ,
    o_fpb_frame_8           => open    ,
    o_fpb_frame_en          => o_fpb_frame_en   
);
----------------------------------------------------------------------------------
adc_controller_ins : adc_controller
port map (
    clk         => clk_40,           
    reset       => reset,          
    scl         => adc_scl,           
    sda         => adc_sda,         
    adc_conv    => adc_conv,         
    adc_ack_err => i_adc_ack_error,        
    adc_done    => i_adc_done,        
    adc_ena     => o_adc_enable,           
    ch_sel      => o_adc_channel,
    adg_mux_in  => o_adc_adg_mux,
    adg_mux_out => adg_mux_out,
    adc_data    => i_adc_data 
);
----------------------------------------------------------------------------------
feb_controller_ins : feb_controller
port map
(
  clk_40                => clk_40,
  rst                   => reset,
  ena_feb_controller    => o_ena_feb_controller,
  feb_chip_selector     => o_feb_chip_selector,
  db_output_selector    => o_db_output_selector,
  db_selector           => o_db_selector,                     
  feb_selector          => o_feb_selector,                     
  channel_selector      => o_channel_selector,                    
  command               => o_feb_command,                    
  cmd_done              => i_feb_done,
  feb_connection_error  => i_feb_connection_error,
  data_from_feb         => i_data_from_feb,                                       
  data_to_feb           => o_data_to_feb,                      
  sda_in_to_feb_p       => sda_in_to_feb_p,                      
  sda_in_to_feb_n       => sda_in_to_feb_n,                                          
  scl_in_to_feb_p       => scl_in_to_feb_p,
  scl_in_to_feb_n       => scl_in_to_feb_n,   
  sda_out_from_feb_p    => sda_out_from_feb_p,                      
  sda_out_from_feb_n    => sda_out_from_feb_n
);

  p_sda_in_to_feb_p       <= sda_in_to_feb_p    (0);                    
--  p_sda_in_to_feb_n       <= sda_in_to_feb_n    (0);                                        
  p_scl_in_to_feb_p       <= scl_in_to_feb_p    (0);
--  p_scl_in_to_feb_n       <= scl_in_to_feb_n    (0); 
  sda_out_from_feb_p (0)  <= p_sda_out_from_feb_p;                    
--  sda_out_from_feb_n (0)  <= p_sda_out_from_feb_n;
----------------------------------------------------------------------------------
cb_fpb_ins_1 : cb_fpb
  Port map(  
  reset               => reset,
  crc_check           => s_fpb_crc_check(0),
  fpb_ready           => s_fpb_calib_done(0),
  fpb_s_d_in          => fpb_s_d_in(0),
  tx_ena              => o_fpb_frame_en(0),
  fpb_s_d_out         => fpb_s_d_out(0),
  tx_ready            => s_fpb_tx_ready(0),
  new_frame           => i_fpb_frame_en(0),
  frame_out           => i_fpb_frame_0,
  frame_in            => o_fpb_frame_0,
  clk_40              => clk_40,
  clk_160             => clk_160, 
  clk_200             => clk_200 
   );
 
 s_fpb_crc_check (8 downto 1) <= (others => '0');
 s_fpb_calib_done (8 downto 1) <= (others => '0');
 s_fpb_tx_ready (8 downto 1) <= (others => '0');
 i_fpb_frame_en (8 downto 1) <= (others => '0');
-- o_fpb_frame_en (8 downto 1) <= (others => '0');
----------------------------------------------------------------------------------
--vio_ins : vio
--  PORT MAP (
--    clk => clk_40,
--    probe_out0 => enable_probe,
--    probe_out1 => i_frame
--  );

--process (clk_40)
--begin
--    if rising_edge (clk_40) then
--        r_enable_1 <= enable_probe(0);
--        r_enable_2 <= r_enable_1;
--    end if;
--end process;  
--i_frame_en <= r_enable_1 AND NOT r_enable_2;
----------------------------------------------------------------------------------
--ila_ins : ila
--PORT MAP (
--	clk => clk_40,
--	probe0 => o_frame_en,
--	probe1 => o_frame,
--	probe2 => i_adc_data,
--	probe3 => i_data_from_feb,
--	probe4 => o_data_to_feb
--);

----------------------------------------------------------------------------------
end Behavioral;
----------------------------------------------------------------------------------