library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;
----------------------------------------------------------------------------------
entity cb_sm is
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
end cb_sm;
----------------------------------------------------------------------------------
architecture Behavioral of cb_sm is
----------------------------------------------------------------------------------
type cb_state_machine is (
st_idle,                        -- wait for initiallization compelete
st_fetch,                       -- fetching the incoming istruction
st_decode_cb_lb,                -- choose if the instruction is for control board or link board
st_decode_cb,                   -- decoding the incoming istruction for control board
st_decode_lb,                   -- decoding the incoming istruction for link board
st_fail,                        -- instruction failed

st_adc_get_cb,                  -- enable adc controller for reading cb parameters voltage, current, temperature
st_adc_wait_cb,                 -- waiting for done signal of adc controller
st_adc_send_result_cb,          -- sending adc results to GBT

st_feb_en,                      -- enable feb controller for get/set the feb configuration
st_feb_wait,                    -- waiting for done signal of feb controller
st_feb_send_result,             -- sending feb results to GBT

-- vahid's states
st_lb_check_ready,
st_lb_send_frame,
st_lb_wait_result,
st_lb_send_result,
-- end of vahid's states

st_firmware_id_get, -- reading firmware ID from corresponding register 
st_firmware_id_send_result -- sending firmware ID to GBT

);
----------------------------------------------------------------------------------
signal s_state : cb_state_machine               := st_idle;
signal r_input_gbt_frame                        : std_logic_vector(FRAMELENGTH-1 downto 0);
signal r_output_gbt_frame                       : std_logic_vector(FRAMELENGTH-1 downto 0);
signal r_inst_opcode                            : std_logic_vector(INSTOPCODELENGTH-1 downto 0);
signal r_packet_index                           : std_logic_vector(PACKETINDEXLENGTH-1 downto 0);
-- vahid's signals
signal r_timeout_counter                        : integer := 0;
signal r_timeout_counter_reset                  : std_logic := '1';
signal s_fpb_frame_en                           : std_logic_vector(8 downto 0);
signal s_lb_number                              : std_logic_vector(3 downto 0);
signal r_lb_number                              : std_logic_vector(3 downto 0);
signal s_fpb_selector                           : std_logic_vector(8 downto 0);
signal s_input_fpb_frame                        : std_logic_vector(FRAMELENGTH-1 downto 0);
signal r_input_fpb_frame                        : std_logic_vector(FRAMELENGTH-1 downto 0);
signal r_adc_adg_mux                            : std_logic_vector (3 downto 0) := (others => '0');
signal r_adc_channel                            : std_logic_vector (2 downto 0) := (others => '0');
signal r_fpb_frame_en                           : std_logic_vector (8 downto 0) := (others => '0');
signal s_type_b_packet_length                   : std_logic_vector (20 downto 0) := (others => '0');
constant c_type_b_packet_length                   : std_logic_vector (20 downto 0) := (others => '0');
----------------------------------------------------------------------------------
constant c_adc_get_cb                   : std_logic_vector(INSTOPCODELENGTH-1 downto 0):= "00001";
constant c_feb                          : std_logic_vector(INSTOPCODELENGTH-1 downto 0):= "00010";
constant c_firmware_id_get_cb           : std_logic_vector(INSTOPCODELENGTH-1 downto 0):= "00011";
-- vahid's constants
constant c_28b_zeros                    : std_logic_vector(28-1 downto 0):= (others => '0');
constant c_timeout                      : integer := 1000000000;
constant c_cblb_index                   : integer := 77;
constant c_opcode_upper_index           : integer := 76;
constant c_opcode_lower_index           : integer := 72;
constant c_packet_length_upper_index    : integer := 69;
constant c_packet_length_lower_index    : integer := 49;
constant c_adg_mux_upper_index          : integer := 44;
constant c_adg_mux_lower_index          : integer := 41;
constant c_adc_channel_upper_index      : integer := 40;
constant c_adc_channel_lower_index      : integer := 38;
constant c_adc_data_upper_index         : integer := 37;
constant c_adc_data_lower_index         : integer := 28;
constant c_timeout_index                : integer := 0;
constant c_feb_command_upper_index      : integer := 48;
constant c_feb_command_lower_index      : integer := 46;
constant c_db_selector_upper_index      : integer := 45;
constant c_db_selector_lower_index      : integer := 43;
constant c_db_output_selector_index     : integer := 42;
constant c_feb_selector_upper_index     : integer := 41;
constant c_feb_selector_lower_index     : integer := 40;
constant c_feb_chip_selector_index      : integer := 39;
constant c_channel_selector_upper_index : integer := 38;
constant c_channel_selector_lower_index : integer := 36;
constant c_feb_data_upper_index         : integer := 35;
constant c_feb_data_lower_index         : integer := 26;
constant c_lb_number_upper_index        : integer := 48;
constant c_lb_number_lower_index        : integer := 45;
constant c_status_reg_upper_index       : integer := 33;
constant c_status_reg_lower_index       : integer := 2;
constant c_firmware_id                  : std_logic_vector (31 downto 0) := "00000000000000000000000000001111";
----------------------------------------------------------------------------------
signal state_number  :STD_LOGIC_VECTOR(3 DOWNTO 0);
signal p_state_number  :STD_LOGIC_VECTOR(8 DOWNTO 0);
COMPONENT ila_cb_sm
PORT (
	clk : IN STD_LOGIC;
	probe0 : IN STD_LOGIC_VECTOR(3 DOWNTO 0)
);
END COMPONENT  ;
----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
--with s_state select state_number <= 
----"0000" when st_idle,
--"0001" when st_fetch,        
--"0010" when st_decode_cb_lb, 
--"0011" when st_decode_cb,    
--"0100" when st_decode_lb,    
--"0101" when st_fail,      
--"0110" when st_adc_get_cb,         
--"0111" when st_adc_wait_cb,        
--"1000" when st_adc_send_result_cb,                        
--"1001" when st_feb_en,             
--"1010" when st_feb_wait,           
--"1011" when st_feb_send_result,         
--"1100" when st_lb_check_ready,     
--"1101" when st_lb_send_frame,      
--"1110" when st_lb_wait_result,     
--"1111" when st_lb_send_result,        
--"0000" when others;        
------------------------------------------------------------------------------------
--cb_sm_ila : ila_cb_sm
--PORT MAP (
--	clk => i_clk_40,
--	probe0 => state_number
--);
----------------------------------------------------------------------------------
o_frame <= r_output_gbt_frame;
----------------------------------------------------------------------------------
r_inst_opcode <= r_input_gbt_frame(c_opcode_upper_index downto c_opcode_lower_index);
s_lb_number <= r_input_gbt_frame(c_lb_number_upper_index downto c_lb_number_lower_index);
----------------------------------------------------------------------------------
process(i_clk_40)
begin
    if(i_clk_40'event and i_clk_40 = '1')then
        if(i_reset = '1' )then
            s_state <= st_idle;
        else
            if(i_init_done = '0')then
                s_state <= st_idle;
            else
case (s_state) is
when st_idle =>
    s_state <= st_fetch;
    o_frame_en <= '0';
    r_output_gbt_frame <= ( others =>'0');
    r_fpb_frame_en     <= ( others =>'0');

when st_fetch =>
    o_frame_en <= '0';
    r_input_gbt_frame <= i_frame;
    r_timeout_counter_reset <= '1';
    if(i_frame_en = '1')then
        s_state <= st_decode_cb_lb;
    else
        s_state <= st_fetch;
    end if;
    
-- vahid's code
when st_decode_cb_lb =>    
    if(r_input_gbt_frame(c_cblb_index) = '0')then
        s_state <= st_decode_cb;
    else
        s_state <= st_decode_lb;
    end if;
-- end of vahid's code    

when st_decode_cb =>
    case (r_inst_opcode) is
        when c_adc_get_cb =>
            s_state <= st_adc_get_cb;
        when c_feb =>
            s_state <= st_feb_en;
        when c_firmware_id_get_cb =>
            s_state <= st_firmware_id_get;
        when others =>
            s_state <= st_fetch;
    end case;
--CB ADC ------------------------------------------
when st_adc_get_cb =>
    r_timeout_counter_reset <= '1';
    s_state <= st_adc_wait_cb;
        
when st_adc_wait_cb =>
    r_timeout_counter_reset <= '0';
    if r_timeout_counter >= c_timeout then
        s_state <= st_fail;
        r_timeout_counter_reset <= '1';
    elsif i_adc_done = '1' then 
        s_state <= st_adc_send_result_cb;
        r_timeout_counter_reset <= '1';
    elsif i_adc_ack_error = '1' then
        s_state <= st_fail;
        r_timeout_counter_reset <= '1';
    else
        s_state <= st_adc_wait_cb;
    end if;

when st_adc_send_result_cb =>
    o_frame_en <= '1';
    r_output_gbt_frame <= r_input_gbt_frame (FRAMELENGTH-1 downto c_adc_data_upper_index+1) & i_adc_data & c_28b_zeros;
    r_timeout_counter_reset <= '1';
    s_state <= st_fetch;
    
--CB FEB ------------------------------------------    
when st_feb_en =>
    r_timeout_counter_reset <= '1';
    s_state <= st_feb_wait;
    
when st_feb_wait =>
    r_timeout_counter_reset <= '0';
    if r_timeout_counter >= c_timeout then
        s_state <= st_fail;
    elsif i_feb_done = '1' then 
        s_state <= st_feb_send_result;
    elsif i_feb_connection_error = '1' then
        s_state <= st_fail;
    else
        s_state <= st_feb_wait;
    end if;
    
when st_feb_send_result =>
    o_frame_en <= '1';
    r_timeout_counter_reset <= '1';
    s_state <= st_fetch;
    r_output_gbt_frame <= r_input_gbt_frame (FRAMELENGTH-1 downto c_feb_data_upper_index+1) & i_data_from_feb & (c_feb_data_lower_index-1 downto 0 => '0');

--send frame to link board ------------------------------------------   
when st_decode_lb => -- edcode for command type A B C
    s_state <= st_lb_check_ready;

when st_lb_check_ready =>
    r_timeout_counter_reset <= '0';
    if (s_fpb_selector AND i_fpb_calib_done) = s_fpb_selector then
        if r_timeout_counter >= c_timeout then
            s_state <= st_fail;
        elsif (s_fpb_selector AND i_fpb_tx_ready) = s_fpb_selector then
            
            s_state <= st_lb_send_frame;

        else
            s_state <= st_fail;
        end if;
    else
        s_state <= st_fail;
    end if;
    
when st_lb_send_frame =>
    r_timeout_counter_reset <= '1';
    s_state <= st_lb_wait_result;
    r_fpb_frame_en <= s_fpb_selector;

when st_lb_wait_result =>
    r_fpb_frame_en <= (others => '0');
    r_timeout_counter_reset <= '0';
    o_frame_en <= '0';
    if r_timeout_counter >= c_timeout then
        s_state <= st_fail;
    elsif (s_fpb_selector AND i_fpb_frame_en) = s_fpb_selector then
        if (s_fpb_selector AND i_fpb_crc_check ) = s_fpb_selector then 
            s_state <= st_lb_send_result;
        else
            s_state <= st_fail;
        end if;
    else
        s_state <= st_lb_wait_result;
    end if;
    
when st_lb_send_result =>
    o_frame_en <= '1';
    r_timeout_counter_reset <= '1';
    r_output_gbt_frame <= r_input_fpb_frame;
    if s_type_b_packet_length = c_type_b_packet_length then
        s_state <= st_fetch;
    else  
        s_state <= st_lb_wait_result;
    end if;     
--CB firmware_id ------------------------------------------   
when st_firmware_id_get =>
s_state <= st_firmware_id_send_result;
when st_firmware_id_send_result =>
    o_frame_en <= '1';    
    r_output_gbt_frame <= 
    i_frame (FRAMELENGTH-1 downto c_status_reg_upper_index+1) & 
    c_firmware_id & 
    "00";    -- first 2 bit reserves
s_state <= st_fetch;
   
--instruction failed ------------------------------------------
when st_fail =>
o_frame_en <= '1';
s_state <= st_fetch;
r_output_gbt_frame <= r_input_gbt_frame (FRAMELENGTH-1 downto 1) & (c_timeout_index=> '1');

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
o_adc_enable <= '1' when s_state = st_adc_get_cb else '0';
process (i_clk_40)
begin
    if rising_edge (i_clk_40) then
		if s_state = st_adc_get_cb then
			r_adc_adg_mux <= r_input_gbt_frame(c_adg_mux_upper_index downto c_adg_mux_lower_index);
        r_adc_channel <= r_input_gbt_frame(c_adc_channel_upper_index downto c_adc_channel_lower_index);
    end if;
end if;
end process;
o_adc_adg_mux <= r_adc_adg_mux;
o_adc_channel <= r_adc_channel;
--st_feb_en--------------------------------------------------------------------------------
o_ena_feb_controller    <= '1' when s_state = st_feb_en else '0';
process (i_clk_40)
begin
    if rising_edge (i_clk_40) then
		if s_state = st_feb_en then
            o_feb_command           <= r_input_gbt_frame(c_feb_command_upper_index downto c_feb_command_lower_index);
            o_db_selector           <= r_input_gbt_frame(c_db_selector_upper_index downto c_db_selector_lower_index);
            o_db_output_selector    <= r_input_gbt_frame(c_db_output_selector_index);
            o_feb_selector          <= r_input_gbt_frame(c_feb_selector_upper_index downto c_feb_selector_lower_index);
            o_feb_chip_selector     <= r_input_gbt_frame(c_feb_chip_selector_index);
            o_channel_selector      <= r_input_gbt_frame(c_channel_selector_upper_index downto c_channel_selector_lower_index);
            o_data_to_feb           <= r_input_gbt_frame(c_feb_data_upper_index downto c_feb_data_lower_index);
		end if;
    end if;
end process;
----------------------------------------------------------------------------------
--with r_input_gbt_frame (c_lb_number_upper_index downto c_lb_number_lower_index) select s_fpb_frame_en <=
--"000000001" when "0001" ,
--"000000010" when "0010" ,
--"000000100" when "0011" ,
--"000001000" when "0100" ,
--"000010000" when "0101" ,
--"000100000" when "0110" ,
--"001000000" when "0111" ,
--"010000000" when "1000" ,
--"100000000" when "1001" ,
--"111111111" when "1111" ,
--"000000000" when others ;

--process (i_clk_40)
--begin
--    if rising_edge (i_clk_40) then
--		if s_state = st_lb_send_frame then
--            o_fpb_frame_en <= s_fpb_frame_en;
--		end if;
--    end if;
--end process;
----------------------------------------------------------------------------------
process (i_clk_40)
begin
    if rising_edge (i_clk_40) then
		if s_state = st_decode_lb then
            r_lb_number <= s_lb_number;
		end if;
    end if;
end process;
----------------------------------------------------------------------------------
with r_lb_number select s_fpb_selector <=
"000000001" when "0001", 
"000000010" when "0010",
"000000100" when "0011",
"000001000" when "0100",
"000010000" when "0101",
"000100000" when "0110",
"001000000" when "0111",
"010000000" when "1000",
"100000000" when "1001",
--"000000000" when "1111", -- all link boards (broadcast command)
"000000000" when others;
----------------------------------------------------------------------------------
o_fpb_frame_0 <= r_input_gbt_frame when r_lb_number = "0001" else (others =>'0');
o_fpb_frame_1 <= r_input_gbt_frame when r_lb_number = "0010" else (others =>'0');
o_fpb_frame_2 <= r_input_gbt_frame when r_lb_number = "0011" else (others =>'0');
o_fpb_frame_3 <= r_input_gbt_frame when r_lb_number = "0100" else (others =>'0');
o_fpb_frame_4 <= r_input_gbt_frame when r_lb_number = "0101" else (others =>'0');
o_fpb_frame_5 <= r_input_gbt_frame when r_lb_number = "0110" else (others =>'0');
o_fpb_frame_6 <= r_input_gbt_frame when r_lb_number = "0111" else (others =>'0');
o_fpb_frame_7 <= r_input_gbt_frame when r_lb_number = "1000" else (others =>'0');
o_fpb_frame_8 <= r_input_gbt_frame when r_lb_number = "1001" else (others =>'0');
----------------------------------------------------------------------------------
with r_lb_number select s_input_fpb_frame <=
i_fpb_frame_0 when "0001", 
i_fpb_frame_1 when "0010",
i_fpb_frame_2 when "0011",
i_fpb_frame_3 when "0100",
i_fpb_frame_4 when "0101",
i_fpb_frame_5 when "0110",
i_fpb_frame_6 when "0111",
i_fpb_frame_7 when "1000",
i_fpb_frame_8 when "1001",
(0=>'1',others =>'0') when others;
----------------------------------------------------------------------------------
process (i_clk_40)
begin
    if rising_edge (i_clk_40) then
--		if (s_fpb_selector AND i_fpb_frame_en) /= "000000000" then
        if i_reset = '1' then
            r_input_fpb_frame <= (others => '0');
		elsif (s_fpb_selector AND i_fpb_frame_en) = s_fpb_selector then
            r_input_fpb_frame <= s_input_fpb_frame;
		end if;
    end if;
end process;
----------------------------------------------------------------------------------
o_fpb_frame_en <= r_fpb_frame_en;
----------------------------------------------------------------------------------
s_type_b_packet_length <= r_input_fpb_frame (c_packet_length_upper_index downto c_packet_length_lower_index); 
----------------------------------------------------------------------------------
end Behavioral;
----------------------------------------------------------------------------------
