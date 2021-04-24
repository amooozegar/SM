----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
----------------------------------------------------------------------------------
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;
----------------------------------------------------------------------------------
entity lb_top is
  Port ( 
  adg_mux_out           : out   STD_LOGIC_VECTOR(3 DOWNTO 0);
  adc_conv              : OUT   STD_LOGIC;                                 
  adc_scl               : INOUT STD_LOGIC;                                 
  adc_sda               : INOUT STD_LOGIC;
  o_fpb_cal             : out   std_logic;
  i_reset               : in    std_logic;
  i_clk_40              : in    std_logic;
  i_clk_160             : in    std_logic;
  i_clk_200             : in    std_logic;
  i_fpb_s_d_in          : in    std_logic;
  o_fpb_s_d_out         : out   std_logic
  );  
end lb_top;
----------------------------------------------------------------------------------
architecture Behavioral of lb_top is

component lb_mmcm
port
 (
  clk_40        : out    std_logic;
  clk_160       : out    std_logic;
  clk_200       : out    std_logic;
  locked        : out    std_logic;
  clk_in1       : in     std_logic
 );
end component;
----------------------------------------------------------------------------------
component lb_sm is
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
    
    i_fpb_frame             : in  std_logic_vector(FRAMELENGTH-1 downto 0); -- input frame from FPB
    i_fpb_frame_en          : in  std_logic; -- input frame enable from FPB
    
    o_fpb_frame             : out std_logic_vector(FRAMELENGTH-1 downto 0); -- output frame to FPB
    o_fpb_frame_en          : out std_logic; -- output frame enable to FPB
    i_fpb_tx_ready          : in  std_logic; -- input frame  from FPB
    i_fpb_calib_done        : in  std_logic; -- input frame  from FPB
    i_fpb_crc_check         : in  std_logic; -- input frame  from FPB
    -- vahid's ports
    -- DIAG controller ports
    i_diag_done             : in  std_logic;  
    o_diag_enable           : out std_logic; 
    o_diag_rd_en            : out std_logic; 
    o_diag_type             : out std_logic_vector (3 downto 0); 
    o_diag_packet_length    : out std_logic_vector (20 downto 0); 
    i_diag_packet_length    : in  std_logic_vector (20 downto 0); 
    i_diag_data             : in  std_logic_vector (47 downto 0);     
    -- ADC controller ports
    i_adc_done              : in  std_logic; -- will be '1' when getting adc value correctly 
    i_adc_ack_error         : in  std_logic; -- i2c master error signal, when is '1' shows adc connection error
    o_adc_enable            : out std_logic; -- enables adc controller
    o_adc_adg_mux           : out std_logic_vector (3 downto 0); -- ADG706BRUZ selector signals
    o_adc_channel           : out std_logic_vector (2 downto 0); -- selects one of ADC four channels
    i_adc_data              : in  std_logic_vector (9 downto 0) -- ADC output data  
  );
end component;
----------------------------------------------------------------------------------
component lb_fpb is
  Port (  
    reset               :     in  std_logic;
    clk_40              :     in  std_logic;
    clk_160             :     in  std_logic;
    clk_200             :     in  std_logic;
    fpb_s_d_in          :     in  std_logic;
    tx_ena              :     in  std_logic;
    fpb_s_d_out         :     out std_logic;
    tx_ready            :     out std_logic;
    new_frame           :     out std_logic;
    fpb_ready           :     out std_logic;
    crc_check           :     out std_logic;
    frame_out           :     out std_logic_vector (79 downto 0);
    frame_in            :     in  std_logic_vector (79 downto 0)
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
    adc_conv    : out   STD_LOGIC;                                 
    ch_sel      : IN    STD_LOGIC_VECTOR(2 DOWNTO 0);
    adg_mux_in  : IN    STD_LOGIC_VECTOR(3 DOWNTO 0);
    adg_mux_out : out   STD_LOGIC_VECTOR(3 DOWNTO 0);
    adc_data    : OUT   STD_LOGIC_VECTOR(9 DOWNTO 0)   
    ); 
END component;
----------------------------------------------------------------------------------
component diag_controller is
  Port (
  i_clk_40                : in   std_logic;  
  i_reset                 : in   std_logic;  
  o_diag_done             : out  std_logic;
  i_diag_rd_en            : in   std_logic; 
  i_diag_enable           : in   std_logic; 
  i_diag_type             : in   std_logic_vector (3 downto 0); 
  i_diag_packet_length    : in   std_logic_vector (20 downto 0); 
  o_diag_packet_length    : out  std_logic_vector (20 downto 0); 
  o_diag_data             : out  std_logic_vector (47 downto 0)
   );
end component;
----------------------------------------------------------------------------------
constant FRAMELENGTH        : integer := 80;
signal i_init_done          : std_logic := '1';
signal locked               : std_logic := '1';
signal lb_reset             : std_logic;
signal clk_40               : std_logic;
signal clk_160              : std_logic;
signal i_adc_done           : std_logic; -- will be '1' when getting adc value correctly 
signal i_adc_ack_error      : std_logic; -- i2c master error signal, when is '1' shows adc connection error
signal o_adc_enable         : std_logic; -- enables adc controller
signal o_adc_adg_mux        : std_logic_vector (3 downto 0); -- ADG706BRUZ selector signals
signal o_adc_channel        : std_logic_vector (2 downto 0); -- selects one of ADC four channels
signal i_adc_data           : std_logic_vector (9 downto 0); -- ADC output data
signal i_fpb_frame          : std_logic_vector (FRAMELENGTH-1 downto 0); 
signal o_fpb_frame          : std_logic_vector (FRAMELENGTH-1 downto 0); 
signal i_fpb_frame_en       : std_logic;
signal o_fpb_frame_en       : std_logic;
signal i_fpb_tx_ready       : std_logic;
signal i_fpb_calib_done     : std_logic;
signal i_fpb_crc_check      : std_logic;
signal diag_done            : std_logic; 
signal diag_enable          : std_logic;
signal diag_rd_en           : std_logic;
signal diag_type            : std_logic_vector (3 downto 0);
signal diag_packet_length_in: std_logic_vector (20 downto 0);-- := "000000000000000001000";
signal diag_packet_length   : std_logic_vector (20 downto 0);
signal diag_data            : std_logic_vector (47 downto 0);
----------------------------------------------------------------------------------
--COMPONENT vio_pack
--  PORT (
--    clk : IN STD_LOGIC;
--    probe_out0 : OUT STD_LOGIC_VECTOR(20 DOWNTO 0)
--  );
--END COMPONENT;
----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
--vio_pack_ins : vio_pack
--  PORT MAP (
--    clk => clk_40,
--    probe_out0 => diag_packet_length_in
--  );
----------------------------------------------------------------------------------
--lb_reset <= not locked or i_reset;
lb_reset <=  i_reset;
o_fpb_cal <=  i_fpb_calib_done;
----------------------------------------------------------------------------------
lb_mmcm_ins : lb_mmcm
   port map (  
   clk_40   => clk_40,
   clk_160  => clk_160,
   clk_200  => open,              
   locked   => locked,
   clk_in1  => i_clk_40
 );   
 
--clk_40 <= i_clk_40; 
--clk_160 <= i_clk_160; 
----------------------------------------------------------------------------------
lb_sm_ins : lb_sm
  Port map( 
  i_clk_40                => clk_40             ,
  i_reset                 => lb_reset           ,
  i_init_done             => i_init_done        ,

  i_fpb_frame             => i_fpb_frame        ,
  i_fpb_frame_en          => i_fpb_frame_en     ,

  o_fpb_frame             => o_fpb_frame        ,
  o_fpb_frame_en          => o_fpb_frame_en     ,
  i_fpb_tx_ready          => i_fpb_tx_ready     ,
  i_fpb_calib_done        => i_fpb_calib_done   ,
  i_fpb_crc_check         => i_fpb_crc_check    ,
  i_diag_done             => diag_done,
  o_diag_enable           => diag_enable,
  o_diag_rd_en            => diag_rd_en,
  o_diag_type             => diag_type,
  o_diag_packet_length    => diag_packet_length_in,
--  o_diag_packet_length    => open,
  i_diag_packet_length    => diag_packet_length,
  i_diag_data             => diag_data, 

  i_adc_done              => i_adc_done         ,
  i_adc_ack_error         => i_adc_ack_error    ,
  o_adc_enable            => o_adc_enable       ,
  o_adc_adg_mux           => o_adc_adg_mux      ,
  o_adc_channel           => o_adc_channel      ,
  i_adc_data              => i_adc_data         
  );  
----------------------------------------------------------------------------------
lb_fpb_ins : lb_fpb
  Port map( 
    crc_check           => i_fpb_crc_check,
    reset               => lb_reset,
    clk_40              => clk_40,
    clk_160             => clk_160,
    clk_200             => i_clk_200,
    fpb_ready           => i_fpb_calib_done,
    fpb_s_d_in          => i_fpb_s_d_in,
    tx_ena              => o_fpb_frame_en,
    fpb_s_d_out         => o_fpb_s_d_out,
    tx_ready            => i_fpb_tx_ready,
    new_frame           => i_fpb_frame_en,
    frame_out           => i_fpb_frame,
    frame_in            => o_fpb_frame
  );
----------------------------------------------------------------------------------
lb_adc_controller_ins : adc_controller
port map (
    clk         => clk_40,           
    reset       => lb_reset,          
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
diag_controller_ins : diag_controller
  Port map(
  i_clk_40                => clk_40,
  i_reset                 => lb_reset,
  o_diag_done             => diag_done,
  i_diag_rd_en            => diag_rd_en,
  i_diag_enable           => diag_enable,
  i_diag_type             => diag_type,
  i_diag_packet_length    => diag_packet_length_in,
  o_diag_packet_length    => diag_packet_length,
  o_diag_data             => diag_data
   );
----------------------------------------------------------------------------------
end Behavioral;
----------------------------------------------------------------------------------