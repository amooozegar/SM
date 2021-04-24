----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;
----------------------------------------------------------------------------------
entity link_box is
  Port (   
--  i_frame                   : in     std_logic_vector(80-1 downto 0); 
--  i_frame_en                : in     std_logic;    
--  o_frame                   : out    std_logic_vector(80-1 downto 0);
--  o_frame_en                : out    std_logic; 
--  i_final_fifo_rd_en        : in     std_logic; 
--  i_reset                   : in     std_logic; 
  i_lb_fpb_s_d_in           : in     std_logic; 
  i_cb_fpb_s_d_in           : in     std_logic; 
  o_cb_fpb_s_d_out          : out    std_logic;
  o_lb_fpb_s_d_out          : out    std_logic;
--  adg_mux_out               : out    STD_LOGIC_VECTOR(3 DOWNTO 0);
--  adc_conv                  : OUT    STD_LOGIC;                                 
--  adc_scl                   : INOUT  STD_LOGIC;                                 
--  adc_sda                   : INOUT  STD_LOGIC;
  clk_in1_p                 : in     std_logic;
  clk_in1_n                 : in     std_logic
  );
end link_box;
----------------------------------------------------------------------------------
architecture Behavioral of link_box is
----------------------------------------------------------------------------------
component SC is
generic(
    FRAMELENGTH : integer := 80;
    FPBLENGTH : integer := 80;
    INSTOPCODELENGTH : integer := 5;
    PACKETINDEXLENGTH : integer := 21;
    RPTIMEOUT : integer := 1000000000
);
  Port ( 
    i_clk_40                        : in  std_logic; -- LHC main clock
    i_reset                         : in  std_logic; -- not MMCM lock
    i_instruction_from_pc           : in  std_logic_vector(FRAMELENGTH-1 downto 0);
    i_instruction_valid_from_pc     : in  std_logic;
    i_result_to_pc_rd_en            : in  std_logic;    
    o_result_to_pc_valid            : out std_logic; 
    o_result_to_pc                  : out std_logic_vector(FRAMELENGTH-1 downto 0); 
    i_frame                         : in  std_logic_vector(FRAMELENGTH-1 downto 0); -- input frame from GBT
    i_frame_en                      : in  std_logic; -- input frame enable from GBT    
    o_frame                         : out std_logic_vector(FRAMELENGTH-1 downto 0); -- output frame to GBT
    o_frame_en                      : out std_logic -- output frame enable to GBT
  );
end component;
----------------------------------------------------------------------------------
component cb_top is
  Port ( 
  i_frame                   : in     std_logic_vector(80-1 downto 0); 
  i_frame_en                : in     std_logic;   
  o_frame                   : out    std_logic_vector(80-1 downto 0); 
  o_frame_en                : out    std_logic; 
  fpb_s_d_in                : in     std_logic_vector (8 downto 0); 
  fpb_s_d_out               : out    std_logic_vector (8 downto 0);     
  p_sda_in_to_feb_p         : OUT    std_logic;                                                             
  p_scl_in_to_feb_p         : OUT    std_logic;  
  p_sda_out_from_feb_p      : IN     std_logic;                       
  adg_mux_out               : out    STD_LOGIC_VECTOR(3 DOWNTO 0);
  adc_conv                  : OUT    STD_LOGIC;                                 
  adc_scl                   : INOUT  STD_LOGIC;                                 
  adc_sda                   : INOUT  STD_LOGIC; 
  o_clk_40                  : out    STD_LOGIC; 
  o_clk_160                 : out    STD_LOGIC; 
  o_clk_200                 : out    STD_LOGIC; 
  i_reset                   : in     std_logic;
  o_fpb_cal                 : out    std_logic;
  clk_in1_p                 : in     std_logic;
  clk_in1_n                 : in     std_logic
  );
end component;
----------------------------------------------------------------------------------
component lb_top is
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
end component;
----------------------------------------------------------------------------------
COMPONENT vio
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
--    probe_in1 : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    probe_out0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out1 : OUT STD_LOGIC_VECTOR(79 DOWNTO 0);
    probe_out2 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out3 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;
----------------------------------------------------------------------------------
COMPONENT final_fifo
  PORT (
    clk     : IN STD_LOGIC;
    srst    : IN STD_LOGIC;
    din     : IN STD_LOGIC_VECTOR(79 DOWNTO 0);
    wr_en   : IN STD_LOGIC;
    rd_en   : IN STD_LOGIC;
    dout    : OUT STD_LOGIC_VECTOR(79 DOWNTO 0);
    full    : OUT STD_LOGIC;
    empty   : OUT STD_LOGIC
  );
END COMPONENT;
----------------------------------------------------------------------------------
COMPONENT ila
PORT (
	clk    : IN STD_LOGIC;
	probe0 : IN STD_LOGIC_VECTOR(79 DOWNTO 0);
	probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
);
END COMPONENT  ;
----------------------------------------------------------------------------------
signal  lb_fpb_s_d_in       :      std_logic_vector (8 downto 0); 
signal  cb_fpb_s_d_in       :      std_logic_vector (8 downto 0); 
signal  cb_fpb_s_d_out      :      std_logic_vector (8 downto 0);
signal  lb_fpb_s_d_out      :      std_logic_vector (8 downto 0);
signal  clk_40              :      std_logic;
signal  clk_200             :      std_logic;
signal  clk_160             :      std_logic;
----------------------------------------------------------------------------------
signal data_probe                :     std_logic_vector (9 downto 0);    
signal i_frame_en_probe          :     std_logic_vector (0 downto 0);    
signal p_reset                   :     std_logic_vector (0 downto 0);    
signal fifo_read                 :     std_logic_vector (0 downto 0);    
signal final_fifo_data           :     std_logic_vector(80-1 downto 0); 
signal r1_frame_en               :     std_logic;    
signal r2_frame_en               :     std_logic;    
signal i_vio_frame_en            :     std_logic;  
signal i_vio_frame               :     std_logic_vector(80-1 downto 0);   
--signal s_o_frame                   :     std_logic_vector(80-1 downto 0);
--signal s_o_frame_en                :     std_logic; 
signal reset                     :     std_logic; 
signal r_reset                   :     std_logic; 
signal s_lb_fpb_cal              :     std_logic; 
signal s_cb_fpb_cal              :     std_logic; 
signal s_fpb_cal                 :     std_logic_vector(1 downto 0);
signal s_sc_to_cb_frame          :     std_logic_vector(80-1 downto 0);
signal s_cb_to_sc_frame          :     std_logic_vector(80-1 downto 0);
signal s_cb_to_sc_frame_en       :     std_logic; 
signal s_sc_to_cb_frame_en       :     std_logic; 
----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
o_cb_fpb_s_d_out <= cb_fpb_s_d_out(0);
o_lb_fpb_s_d_out <= lb_fpb_s_d_out(0);
cb_fpb_s_d_in(0) <= i_cb_fpb_s_d_in;
lb_fpb_s_d_in(0) <= i_lb_fpb_s_d_in;
----------------------------------------------------------------------------------
sc_inst : SC 
  Port map( 
    i_clk_40                       => clk_40,    -- LHC main clock
    i_reset                        => reset,       -- reset from user
    i_instruction_from_pc          => i_vio_frame,
--    i_instruction_from_pc          => i_frame,
    i_instruction_valid_from_pc    => i_vio_frame_en,
--    i_instruction_valid_from_pc    => i_frame_en,
    i_result_to_pc_rd_en           => fifo_read(0),
--    i_result_to_pc_rd_en           => i_final_fifo_rd_en,
    o_result_to_pc_valid           => open,
--    o_result_to_pc_valid           => o_frame_en,
    o_result_to_pc                 => final_fifo_data,
--    o_result_to_pc                 => o_frame,
    i_frame                        => s_cb_to_sc_frame,       -- input frame from GBT
    i_frame_en                     => s_cb_to_sc_frame_en,    -- input frame enable from GBT    
    o_frame                        => s_sc_to_cb_frame,       -- output frame to GBT
    o_frame_en                     => s_sc_to_cb_frame_en     -- output frame enable to GBT
--    o_frame_en                     => open     -- output frame enable to GBT
  );
----------------------------------------------------------------------------------
cb_ins : cb_top
  Port map( 
  i_frame                   => s_sc_to_cb_frame ,
  i_frame_en                => s_sc_to_cb_frame_en ,
  o_frame                   => s_cb_to_sc_frame ,
  o_frame_en                => s_cb_to_sc_frame_en ,
--  o_frame_en                => open ,
  fpb_s_d_in                => cb_fpb_s_d_in ,
  fpb_s_d_out               => cb_fpb_s_d_out,    
  p_sda_in_to_feb_p         => open,                                        
  p_scl_in_to_feb_p         => open,
  p_sda_out_from_feb_p      => '0',   
  adg_mux_out               => open,
  adc_conv                  => open,             
  adc_scl                   => open,             
  adc_sda                   => open,
  o_fpb_cal                 => s_cb_fpb_cal,
  i_reset                   => reset,
  o_clk_40                  => clk_40,
  o_clk_160                 => clk_160,
  o_clk_200                 => clk_200,
  clk_in1_p                 => clk_in1_p,
  clk_in1_n                 => clk_in1_n           
  );
----------------------------------------------------------------------------------
lb_ins : lb_top 
    port map
    (
    adg_mux_out           => open ,
    adc_conv              => open    ,          
    adc_scl               => open     ,          
    adc_sda               => open     ,
    i_clk_40              => clk_40,
    i_clk_160             => clk_160,
    i_clk_200             => clk_200,
    o_fpb_cal             => s_lb_fpb_cal,
    i_reset               => reset,
    i_fpb_s_d_in          => lb_fpb_s_d_in(0),
    o_fpb_s_d_out         => lb_fpb_s_d_out(0)
--    o_fpb_s_d_out         => open
    );
----------------------------------------------------------------------------------
s_fpb_cal <= s_cb_fpb_cal & s_lb_fpb_cal;
vio_ins : vio
  PORT MAP (
    clk => clk_40,
    probe_in0 => s_fpb_cal,
--    probe_in1 => data_probe,
    probe_out0 => i_frame_en_probe,
    probe_out1 => i_vio_frame,
    probe_out2 => p_reset,
    probe_out3 => fifo_read
  );
 
process (clk_40)
begin
if rising_edge (clk_40) then
r1_frame_en <= i_frame_en_probe(0);
r2_frame_en <= r1_frame_en;
r_reset <= p_reset(0);
end if;
end process;   
i_vio_frame_en <= r1_frame_en AND NOT r2_frame_en; 
reset <= r_reset;
--reset <= i_reset;
----------------------------------------------------------------------------------
ila_ins : ila
PORT MAP (
	clk    => clk_40,
	probe0 => final_fifo_data,
	probe1 => fifo_read
);
----------------------------------------------------------------------------------
end Behavioral;
----------------------------------------------------------------------------------