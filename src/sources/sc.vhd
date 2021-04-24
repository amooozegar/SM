----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
----------------------------------------------------------------------------------
entity SC is
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
end SC;
----------------------------------------------------------------------------------
architecture Behavioral of SC is
----------------------------------------------------------------------------------
signal s_pc_to_card_fifo_dout   :  std_logic_vector(FRAMELENGTH-1 downto 0);
signal s_pc_to_card_fifo_rd_en  :  std_logic;
signal s_pc_to_card_fifo_empty  :  std_logic;
signal s_pc_to_card_fifo_valid  :  std_logic;
signal s_pc_to_card_fifo_full   :  std_logic;
signal s_card_to_pc_fifo_full   :  std_logic;
signal s_card_to_pc_fifo_wr_en  :  std_logic;
signal s_card_to_pc_fifo_din    :  std_logic_vector(FRAMELENGTH-1 downto 0);
----------------------------------------------------------------------------------
COMPONENT sc_sm 
generic(
    FRAMELENGTH : integer := 80;
    FPBLENGTH : integer := 80;
    INSTOPCODELENGTH : integer := 5;
    PACKETINDEXLENGTH : integer := 21;
    RPTIMEOUT : integer := 1000000000
);
  Port (
    i_clk_40                : in  std_logic; -- LHC main clock
    i_reset                 : in  std_logic; -- not MMCM lock
    i_init_done             : in  std_logic; -- done from initialization state machine
    
    i_frame                 : in  std_logic_vector(FRAMELENGTH-1 downto 0); -- input frame from GBT
    i_frame_en              : in  std_logic; -- input frame enable from GBT
    
    o_frame                 : out std_logic_vector(FRAMELENGTH-1 downto 0); -- output frame to GBT
    o_frame_en              : out std_logic; -- output frame enable to GBT
          
    ----------------------------Mohammad ports---------------------------------------
    i_bit_stream_data       : in  std_logic_vector(31 downto 0); -- 32 bit bitstream data
    i_bit_stream_data_valid : in  std_logic; -- bitstream data valid
    i_bitstream_data_fifo_prog_full : in  std_logic; -- empty flag indicating the bitstream fifo has sufficient data
    o_bitstream_data_fifo_rd_en      : out  std_logic; -- read enable for the bitstream fifo
    
    
    i_pc_to_card_fifo_dout : in std_logic_vector(FRAMELENGTH-1 downto 0); -- outpout of the PC-to-card fifo
    i_pc_to_card_fifo_empty : in  std_logic; -- empty flag of the PC-to-card fifo
    o_pc_to_card_fifo_rd_en : out  std_logic; -- read enable of the PC-to-card fifo

    i_card_to_pc_fifo_full : in  std_logic; -- full flag indicating the card-to-pc fifo is full
    o_card_to_pc_fifo_wr_en : out  std_logic; -- wr_en of card-to-pc fifo
    o_card_to_pc_fifo_din : out  std_logic_vector(FRAMELENGTH-1 downto 0) -- input of card-to-pc fifo
    ----------------------------Mohammad ports---------------------------------------
   );
END COMPONENT;
----------------------------------------------------------------------------------
COMPONENT pc_card_fifo
  PORT (
    srst     : IN STD_LOGIC;
    clk     : IN STD_LOGIC;
    din     : IN STD_LOGIC_VECTOR(79 DOWNTO 0);
    wr_en   : IN STD_LOGIC;
    rd_en   : IN STD_LOGIC;
    dout    : OUT STD_LOGIC_VECTOR(79 DOWNTO 0);
    full    : OUT STD_LOGIC;
    empty   : OUT STD_LOGIC;
    valid   : OUT STD_LOGIC
  );
END COMPONENT;
----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
sc_sm_inst : sc_sm
Port map (
i_clk_40                => i_clk_40,
i_reset                 => i_reset,
i_init_done             => '1',
						
i_frame                 => i_frame,
i_frame_en              => i_frame_en,
o_frame                 => o_frame,
o_frame_en              => o_frame_en,

----------------------------Mohammad ports---------------------------------------
i_bit_stream_data       			=> (others => '0'),
i_bit_stream_data_valid             => '0',
i_bitstream_data_fifo_prog_full     => '0',
o_bitstream_data_fifo_rd_en         => open,

i_pc_to_card_fifo_dout              => s_pc_to_card_fifo_dout,
i_pc_to_card_fifo_empty             => s_pc_to_card_fifo_empty,
o_pc_to_card_fifo_rd_en             => s_pc_to_card_fifo_rd_en,

i_card_to_pc_fifo_full              => s_card_to_pc_fifo_full,
o_card_to_pc_fifo_wr_en             => s_card_to_pc_fifo_wr_en,
o_card_to_pc_fifo_din               => s_card_to_pc_fifo_din
----------------------------Mohammad ports---------------------------------------
   );
----------------------------------------------------------------------------------   
pc_to_card_fifo_inst : pc_card_fifo
  PORT MAP (
    clk     => i_clk_40,
    srst    => i_reset,
    din     => i_instruction_from_pc,
    wr_en   => i_instruction_valid_from_pc,
    rd_en   => s_pc_to_card_fifo_rd_en,
    dout    => s_pc_to_card_fifo_dout,
    full    => s_pc_to_card_fifo_full,
    empty   => s_pc_to_card_fifo_empty,
    valid   => s_pc_to_card_fifo_valid
  );

card_to_pc_fifo_inst : pc_card_fifo
  PORT MAP (
    clk     => i_clk_40,
    srst    => i_reset,
    din     => s_card_to_pc_fifo_din,
    wr_en   => s_card_to_pc_fifo_wr_en,
    rd_en   => i_result_to_pc_rd_en,
    dout    => o_result_to_pc,
    full    => s_card_to_pc_fifo_full,
    empty => open
  );
----------------------------------------------------------------------------------           
end Behavioral;
