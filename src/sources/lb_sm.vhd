----------------------------------------------------------------------------------
Library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;
----------------------------------------------------------------------------------
entity lb_sm is
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
--    i_diag_valid            : in  std_logic; 
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
end lb_sm;
----------------------------------------------------------------------------------
architecture Behavioral of lb_sm is
----------------------------------------------------------------------------------
type lb_state_machine is (
st_idle,                            -- wait for initiallization compelete
st_fetch,                           -- fetching the incoming istruction
st_decode,                          -- decoding the incoming istruction for link board
st_fail,                            -- instruction failed

st_adc_get_lb,                      -- st_diag_get_lb
st_adc_wait_lb,                     -- waiting for done signal of adc controller
st_adc_send_result_lb,              -- sending adc results to FPB 

st_diag_get_lb,                      -- 
st_diag_wait_lb,                     -- 
st_diag_read_result_lb,              --  
st_diag_wait_fpb_lb,                 --  
st_diag_send_result_lb,              --  
st_diag_wait_send_fpb_lb,              --  

st_firmware_id_get,                 -- reading firmware ID from corresponding register 
st_firmware_id_send_result          -- sending firmware ID to FPB

);
---------------------------------------------------------------------------------- 
signal s_state : lb_state_machine       := st_idle;
signal r_input_fpb_frame                : std_logic_vector(FRAMELENGTH-1 downto 0);
signal r_output_fpb_frame               : std_logic_vector(FRAMELENGTH-1 downto 0);
signal r_inst_opcode                    : std_logic_vector(INSTOPCODELENGTH-1 downto 0);
signal r_packet_index                   : std_logic_vector(PACKETINDEXLENGTH-1 downto 0);
signal r_timeout_counter                : integer := 0;
signal r_timeout_counter_reset          : std_logic := '1';
signal r_fpb_frame_en          : std_logic := '1';
signal r_adc_adg_mux                    : std_logic_vector (3 downto 0) := (others => '0');
signal r_adc_channel                    : std_logic_vector (2 downto 0) := (others => '0');
signal r_diag_packet_length             : std_logic_vector (20 downto 0)  := (others => '0');
constant c_diag_packet_length             : std_logic_vector (20 downto 0)  := (others => '0');
----------------------------------------------------------------------------------
constant c_adc_get_lb                   : std_logic_vector(INSTOPCODELENGTH-1 downto 0):= "00001";
constant c_diag_get_lb                  : std_logic_vector(INSTOPCODELENGTH-1 downto 0):= "00010";
constant c_firmware_id_get_lb           : std_logic_vector(INSTOPCODELENGTH-1 downto 0):= "00011";
--constant c_28b_zeros                    : std_logic_vector(28-1 downto 0):= (others => '0');
--constant c_13b_zeros                    : std_logic_vector(12 downto 0):= (others => '0');
constant c_timeout                      : integer := 1000000000;
constant c_cblb_index                   : integer := 77;
constant c_opcode_upper_index           : integer := 76;
constant c_opcode_lower_index           : integer := 72;
constant c_packet_length_upper_index    : integer := 69;
constant c_packet_length_lower_index    : integer := 49;
constant c_diag_type_upper_index        : integer := 48;
constant c_diag_type_lower_index        : integer := 45;
constant c_diag_data_upper_index        : integer := 44;
constant c_diag_data_lower_index        : integer := 13;
constant c_adg_mux_upper_index          : integer := 44;
constant c_adg_mux_lower_index          : integer := 41;
constant c_adc_channel_upper_index      : integer := 40;
constant c_adc_channel_lower_index      : integer := 38;
constant c_adc_data_upper_index         : integer := 37;
constant c_adc_data_lower_index         : integer := 28;
constant c_status_reg_upper_index       : integer := 33;
constant c_status_reg_lower_index       : integer := 2;
constant c_timeout_index                : integer := 0;
constant c_firmware_id                  : std_logic_vector (31 downto 0) := "00000000000000000000000000001111";
----------------------------------------------------------------------------------
signal lb_state_number  :STD_LOGIC_VECTOR(3 DOWNTO 0);
COMPONENT ila_lb_sm
PORT (
	clk : IN STD_LOGIC;
	probe0 : IN STD_LOGIC_VECTOR(3 DOWNTO 0)
);
END COMPONENT  ;
----------------------------------------------------------------------------------
begin
---------------------------------------------------------------------------------- 
--with s_state select lb_state_number <= 
--"0001" when st_idle,                            -- wait for initiallization compelete
--"0010" when st_fetch,                           -- fetching the incoming istruction
--"0011" when st_decode,                          -- decoding the incoming istruction for link board
--"0100" when st_fail,                            -- instruction failed
--"0101" when st_adc_get_lb,                      -- st_diag_get_lb
--"0110" when st_adc_wait_lb,                     -- waiting for done signal of adc controller
--"0111" when st_adc_send_result_lb,              -- sending adc results to FPB 
--"1000" when st_diag_get_lb,                      -- 
--"1001" when st_diag_wait_lb,                     -- 
--"1010" when st_diag_read_result_lb,              --  
--"1011" when st_diag_wait_fpb_lb,                 --  
--"1100" when st_diag_send_result_lb,              --  
--"1101" when st_diag_wait_send_fpb_lb,              --      
--"1111" when others;  
------------------------------------------------------------------------------------
--lb_sm_ila : ila_lb_sm
--PORT MAP (
--	clk => i_clk_40,
--	probe0 => lb_state_number
--);
----------------------------------------------------------------------------------
o_fpb_frame <= r_output_fpb_frame;
----------------------------------------------------------------------------------
r_inst_opcode <= r_input_fpb_frame(c_opcode_upper_index downto c_opcode_lower_index);
----------------------------------------------------------------------------------
process(i_clk_40)
begin
    if(i_clk_40'event and i_clk_40 = '1')then
        if(i_reset = '1' )then
            s_state <= st_idle;
            o_diag_rd_en <= '0';
        else
            if(i_init_done = '0')then
                s_state <= st_idle;
            else
case (s_state) is
when st_idle =>
    s_state <= st_fetch;
    o_diag_rd_en <= '0';
    r_fpb_frame_en <= '0';
    r_output_fpb_frame <= ( others =>'0');

when st_fetch =>
    r_fpb_frame_en <= '0';
    r_input_fpb_frame <= i_fpb_frame;
    r_timeout_counter_reset <= '1';
    if(i_fpb_frame_en = '1')then
        s_state <= st_decode;
    else
        s_state <= st_fetch;
    end if;

when st_decode =>
    case (r_inst_opcode) is
        when c_adc_get_lb =>
            s_state <= st_adc_get_lb;
        when c_diag_get_lb =>
            s_state <= st_diag_get_lb;
        when c_firmware_id_get_lb =>
            s_state <= st_firmware_id_get;
        when others =>
            s_state <= st_fetch;
    end case;
--LB ADC ------------------------------------------
when st_adc_get_lb =>
    r_timeout_counter_reset <= '1';
    s_state <= st_adc_wait_lb;
        
when st_adc_wait_lb =>
    r_timeout_counter_reset <= '0';
    if r_timeout_counter >= c_timeout then
        s_state <= st_fail;
    elsif i_adc_done = '1' then 
        s_state <= st_adc_send_result_lb;
    elsif i_adc_ack_error = '1' then
        s_state <= st_fail;
    else
        s_state <= st_adc_wait_lb;
    end if;

when st_adc_send_result_lb =>
    r_fpb_frame_en <= '1';
    r_output_fpb_frame <= 
    r_input_fpb_frame (FRAMELENGTH-1 downto c_adc_data_upper_index+1) & 
    i_adc_data & 
    r_input_fpb_frame (c_adc_data_lower_index-1 downto 0);
    r_timeout_counter_reset <= '1';
    s_state <= st_fetch;       
--diag ------------------------------------------
when st_diag_get_lb =>
    r_timeout_counter_reset <= '1';
    s_state <= st_diag_wait_lb;
        
when st_diag_wait_lb =>
    r_timeout_counter_reset <= '0';
    if r_timeout_counter >= c_timeout then
        s_state <= st_fail;
    elsif i_diag_done = '1' then 
        s_state <= st_diag_read_result_lb;
        r_diag_packet_length <= i_diag_packet_length;
    else
        s_state <= st_diag_wait_lb;
    end if;

when st_diag_read_result_lb =>
    r_timeout_counter_reset <= '1';
    r_fpb_frame_en <= '0';
    r_diag_packet_length <= r_diag_packet_length - '1';
    o_diag_rd_en <= '1';
    s_state <= st_diag_send_result_lb;



when st_diag_send_result_lb =>
    r_fpb_frame_en <= '1';
    o_diag_rd_en <= '0';
    r_timeout_counter_reset <= '1';    
    r_output_fpb_frame <= 
        r_input_fpb_frame (FRAMELENGTH-1 downto c_packet_length_upper_index+1) & 
        r_diag_packet_length & 
        i_diag_data & 
        r_input_fpb_frame (0);    
    s_state <= st_diag_wait_send_fpb_lb;

when st_diag_wait_send_fpb_lb =>
r_fpb_frame_en <= '0';
s_state <= st_diag_wait_fpb_lb;

when st_diag_wait_fpb_lb =>
    o_diag_rd_en <= '0';
    if i_fpb_tx_ready = '1' then    
        if r_diag_packet_length = c_diag_packet_length then
            s_state <= st_fetch;
        else  
            s_state <= st_diag_read_result_lb;     
        end if; 
    else  
        s_state <= st_diag_wait_fpb_lb;     
    end if; 
          
--firmware_id ------------------------------------------
when st_firmware_id_get => 
s_state <= st_firmware_id_send_result;

when st_firmware_id_send_result =>
    r_fpb_frame_en <= '1';    
    r_output_fpb_frame <= 
        r_input_fpb_frame (FRAMELENGTH-1 downto c_status_reg_upper_index+1) & 
        c_firmware_id & 
        "00";    -- first 2 bit reserves
    s_state <= st_fetch;
--instruction failed ------------------------------------------
when st_fail =>
r_fpb_frame_en <= '1';
s_state <= st_fetch;
r_output_fpb_frame <= r_input_fpb_frame (FRAMELENGTH-1 downto 1) & (c_timeout_index=> '1');        
--when others------------------------------------------
when others =>
s_state <= st_fetch;
end case;
end if;
end if;
end if;
end process;
--timeout_counter--------------------------------------------------------------------------------
process (i_clk_40)
begin
    if rising_edge (i_clk_40) then
        if r_timeout_counter_reset = '1' then
            r_timeout_counter <= 0;
        else
            r_timeout_counter <= r_timeout_counter + 1;
        end if;
    end if;
end process;        
--st_adc_get_cb--------------------------------------------------------------------------------
o_adc_enable <= '1' when s_state = st_adc_get_lb else '0';
process (i_clk_40)
begin
    if rising_edge (i_clk_40) then
		if s_state = st_adc_get_lb then
			r_adc_adg_mux <= r_input_fpb_frame(c_adg_mux_upper_index downto c_adg_mux_lower_index);
			r_adc_channel <= r_input_fpb_frame(c_adc_channel_upper_index downto c_adc_channel_lower_index);
		end if;
    end if;
end process;
o_adc_adg_mux <= r_adc_adg_mux;
o_adc_channel <= r_adc_channel;
----------------------------------------------------------------------------------
o_fpb_frame_en <= r_fpb_frame_en;
----------------------------------------------------------------------------------
o_diag_enable <= '1' when s_state = st_diag_get_lb else '0';
o_diag_type <= r_input_fpb_frame(c_diag_type_upper_index downto c_diag_type_lower_index);
o_diag_packet_length <= r_input_fpb_frame(c_packet_length_upper_index downto c_packet_length_lower_index);
----------------------------------------------------------------------------------
end Behavioral;
----------------------------------------------------------------------------------