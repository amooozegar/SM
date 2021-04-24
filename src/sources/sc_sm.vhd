library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;
----------------------------------------------------------------------------------
entity sc_sm is
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
    i_bit_stream_data               : in   std_logic_vector(31 downto 0); -- 32 bit bitstream data
    i_bit_stream_data_valid         : in   std_logic; -- bitstream data valid
    i_bitstream_data_fifo_prog_full : in   std_logic; -- empty flag indicating the bitstream fifo has sufficient data
    o_bitstream_data_fifo_rd_en     : out  std_logic; -- read enable for the bitstream fifo
    
    i_pc_to_card_fifo_dout          : in   std_logic_vector(FRAMELENGTH-1 downto 0); -- outpout of the PC-to-card fifo
    i_pc_to_card_fifo_empty         : in   std_logic; -- empty flag of the PC-to-card fifo
    o_pc_to_card_fifo_rd_en         : out  std_logic; -- read enable of the PC-to-card fifo

    i_card_to_pc_fifo_full          : in   std_logic; -- full flag indicating the card-to-pc fifo is full
    o_card_to_pc_fifo_wr_en         : out  std_logic; -- wr_en of card-to-pc fifo
    o_card_to_pc_fifo_din           : out  std_logic_vector(FRAMELENGTH-1 downto 0) -- input of card-to-pc fifo
    ----------------------------Mohammad ports--------------------------------------- 
   );
end sc_sm;

----------------------------------------------------------------------------------
architecture Behavioral of sc_sm is
attribute MARK_DEBUG : string;
----------------------------------------------------------------------------------
type sc_state_machine is (
st_idle, -- wait for initiallization compelete 00000
st_fetch, -- fetching the incoming istruction 00001
st_decode, -- decoding the incoming istruction 00010

----------------------------Mohammad states---------------------------------------
st_fetch_read_fifo, -- one cycle after fetch to read instruction from fifo 00011

st_send_type_a, -- sending type a instruction 00100
st_send_type_b, -- sending type b instruction 00101
st_send_type_c, -- sending type c instruction 00110

st_type_a_wait, -- wait on reply for type a instructions 00111
st_type_b_wait, -- wait on reply for type b instructions 01000
st_type_c_wait, -- wait on reply for type a instructions 01001

st_type_a_write_result, -- write instruction result for type a instruction 01010
st_type_b_write_result, -- write instruction result for type b instruction 01011
st_type_c_write_result, -- write instruction result for type c instruction 01100

st_type_a_faulty_result, -- indicationg results for type a instructions from CB are incorrect 01101
st_type_b_faulty_result, -- indicationg results for type b instructions from CB are incorrect 01110
st_type_c_faulty_result, -- indicationg results for type c instructions from CB are incorrect 01111

st_timeout_a, -- indicationg type a timeout 10000
st_timeout_b, -- indicationg type b timeout 10001
st_timeout_c, -- indicationg type c timeout 10010

st_RP_send_first_frame, -- sending the first frame 10011
st_RP_wait_for_first_frame_reply, -- wait for the first frame reply 10100
st_RP_wait_for_bitstream_fifo, -- wait for sending fifo have sufficient data 10101
st_RP_wait_for_bitstream_fifo_read, -- 10110
st_RP_send_bunch_frame, -- sending a bunch of bitstream 10111
st_RP_wait_for_next_bunch_request, --waiting for the next bunch request 11000
st_RP_wait_for_completion, --waiting for remote programming to be complteted on the CB side 11001

----------------------------Vahid states---------------------------------------
st_type_a_check_result
);
----------------------------------------------------------------------------------
signal test_flag                                : std_logic:='0';
signal s_state_binary                           : std_logic_vector(4 downto 0);
signal s_state : sc_state_machine               := st_idle;
signal r_input_gbt_frame                        : std_logic_vector(FRAMELENGTH-1 downto 0);
signal r_output_gbt_frame                       : std_logic_vector(FRAMELENGTH-1 downto 0);
signal r_inst_opcode                            : std_logic_vector(INSTOPCODELENGTH-1 downto 0);
signal r_packet_index                           : std_logic_vector(PACKETINDEXLENGTH-1 downto 0);
----------------------------------------------------------------------------------
constant c_adc_get_cb                   : std_logic_vector(INSTOPCODELENGTH-1 downto 0):= "00001";
constant c_feb                          : std_logic_vector(INSTOPCODELENGTH-1 downto 0):= "00010";
constant c_firmware_id_get_cb           : std_logic_vector(INSTOPCODELENGTH-1 downto 0):= "00011";
constant c_opcode_upper_index           : integer:= 76;
constant c_opcode_lower_index           : integer:= 72;
constant c_packet_upper_index           : integer:= 69;
constant c_packet_lower_index           : integer:= 49;
constant c_payload_lower_index          : integer:= 2;
constant c_payload_upper_index          : integer:= 48;
constant bunch_size                     : integer:= 1024;
----------------------------------------------------------------------------------
----------------------------Mohammad signals--------------------------------------
--signal s_enable_RP                       : std_logic;
--signal s_erase_ok                        : std_logic;
--signal s_RP_RX_FIFO_wr_en                : std_logic;
--signal s_RP_RX_FIFO_prog_empty           : std_logic;
--signal s_RP_RX_FIFO_reset                : std_logic;
--signal s_RP_spi_done                     : std_logic;
--signal s_RP_spi_error                     : std_logic;
--signal s_RP_RX_FIFO_din                  : std_logic_vector(31 downto 0);
signal s_RP_bunch_counter                : integer:= 0;
signal r_RP_time_out                     : integer:= 0;
signal r_inst_type                       : std_logic_vector(2 downto 0);
signal r_RP_time_out_counter             : integer:= 3;

constant c_inst_type_a                   : std_logic_vector(2 downto 0):= "001";
constant c_inst_type_b                   : std_logic_vector(2 downto 0):= "010";
constant c_inst_type_c                   : std_logic_vector(2 downto 0):= "011";
constant c_RP_opcode                     : std_logic_vector(INSTOPCODELENGTH-1 downto 0):= "00100";
constant c_packet_zero                   : std_logic_vector(PACKETINDEXLENGTH-1-9 downto 0):= (others => '0');
--signal c_RP_cb                         : std_logic_vector(INSTOPCODELENGTH-1 downto 0):= "00000";
--constant c_RP_time_out           : std_logic_vector(RPTIMEOUT-1 downto 0):= "00000";
attribute MARK_DEBUG of s_state_binary	   	: signal is "TRUE";
attribute MARK_DEBUG of r_packet_index	   	: signal is "TRUE";
attribute MARK_DEBUG of r_input_gbt_frame	   	: signal is "TRUE";
----------------------------Vahid's signals--------------------------------------
constant c_packet_length_upper_index    : integer := 69;
constant c_packet_length_lower_index    : integer := 49;
constant c_21_bit_zero                  : std_logic_vector(20 downto 0):= (others => '0' );

constant c_timeout_type_a                       : integer := 10000;
--constant c_timeout_type_a                       : integer := 100;
constant c_max_timeout_event_type_a             : integer := 3;
constant c_max_faulty_result_event_type_a       : integer := 3;
signal r_timeout_counter                        : integer := 0;
signal r_timeout_event_counter                  : integer := 0;
signal r_faulty_result_counter                  : integer := 0;
signal r_timeout_counter_reset                  : std_logic := '1';
begin
---------------------------------------------------------------------------------- 
--r_inst_opcode <= r_input_gbt_frame(c_opcode_upper_index downto c_opcode_lower_index);
--r_inst_type <= r_input_gbt_frame(c_payload_lower_index+2 downto c_payload_lower_index);
----------------------------------------------------------------------------------


process(i_clk_40)
begin
    if(i_clk_40'event and i_clk_40 = '1')then
        if(i_reset = '1' )then
            s_state <= st_idle;
            s_state_binary <= "00000";
            r_RP_time_out <= 0;
        else
            if(i_init_done = '0')then
                s_state <= st_idle;
                s_state_binary <= "00000";
            else
case (s_state) is
when st_idle =>
    s_state <= st_fetch;
    s_state_binary <= "00001";

when st_fetch =>
    o_card_to_pc_fifo_wr_en <= '0';
    r_timeout_event_counter <= 0; -- vahid
    o_frame <= ( others =>'0'); -- vahid
    o_frame_en <= '0'; -- vahid
    if(i_pc_to_card_fifo_empty = '0')then
        o_pc_to_card_fifo_rd_en <= '1';
        s_state <= st_fetch_read_fifo;
        s_state_binary <= "00011";
    else
        s_state <= st_fetch;
        s_state_binary <= "00001";
    end if;

when st_fetch_read_fifo =>
    o_pc_to_card_fifo_rd_en <= '0';
    s_state <= st_decode;
    s_state_binary <= "00010";
    
when st_decode =>
r_input_gbt_frame <= i_pc_to_card_fifo_dout;
r_inst_type <= i_pc_to_card_fifo_dout(c_payload_lower_index+2 downto c_payload_lower_index);
r_inst_opcode <= i_pc_to_card_fifo_dout(c_opcode_upper_index downto c_opcode_lower_index);
case (i_pc_to_card_fifo_dout(c_payload_lower_index+2 downto c_payload_lower_index)) is
    when c_inst_type_a =>
        s_state <= st_send_type_a;
        s_state_binary <= "00100";
    when c_inst_type_b =>
        s_state <= st_send_type_b;
        s_state_binary <= "00101";
    when c_inst_type_c =>
        s_state <= st_send_type_c;
        s_state_binary <= "00110";
        r_packet_index <= i_pc_to_card_fifo_dout(c_packet_upper_index downto c_packet_lower_index);
    when others =>
        s_state <= st_fetch;
        s_state_binary <= "00001";
end case;
---------------------------------------- vahid's codes -----------------------------------------
---------------------------------------- type A -----------------------------------------
when st_send_type_a =>
o_frame <= i_pc_to_card_fifo_dout;
o_frame_en <= '1';
s_state <= st_type_a_wait;
r_timeout_counter_reset <= '1';

when st_type_a_wait =>
    o_frame_en <= '0';
    r_timeout_counter_reset <= '0';
    if r_timeout_counter >= c_timeout_type_a then
        r_timeout_event_counter <= r_timeout_event_counter + 1;
        if r_timeout_event_counter >= c_max_timeout_event_type_a then
            s_state <= st_timeout_a;            
        else
            s_state <= st_send_type_a;
            r_timeout_counter_reset <= '1';
        end if;
    elsif i_frame_en = '1' then 
        s_state <= st_type_a_check_result; 
    else
        s_state <= st_type_a_wait;
    end if;
    
when st_type_a_check_result => 
    r_timeout_counter_reset <= '1';   
    if i_frame(0) = '1' then
        r_faulty_result_counter <= r_faulty_result_counter + 1; 
        if r_faulty_result_counter >= c_max_faulty_result_event_type_a then
            s_state <= st_type_a_faulty_result;
        else
            s_state <= st_send_type_a;
        end if;
    else
        s_state <= st_type_a_write_result;
    end if;  
        
when st_type_a_write_result =>    
    r_timeout_counter_reset <= '1';
    o_card_to_pc_fifo_din <= i_frame;
    o_card_to_pc_fifo_wr_en <= '1';
    s_state <= st_fetch;
    if i_frame (c_packet_length_upper_index downto c_packet_length_lower_index) = c_21_bit_zero then 
        s_state <= st_fetch;
    else  
        s_state <= st_type_a_wait;
    end if;    

when st_type_a_faulty_result =>    
    r_timeout_counter_reset <= '1';
    o_card_to_pc_fifo_din <= i_frame; -- we must decide to what to write for faulty results
    o_card_to_pc_fifo_wr_en <= '1';
    s_state <= st_fetch;

when st_timeout_a =>    
    r_timeout_counter_reset <= '1';
    o_card_to_pc_fifo_din <= i_frame; -- we must decide to what to write for time out results
    o_card_to_pc_fifo_wr_en <= '1';
    s_state <= st_fetch;





---------------------------------------- type B -----------------------------------------
when st_send_type_b =>
---------------------------------------- type C -----------------------------------------
when st_send_type_c =>
    o_frame(FRAMELENGTH-1 downto c_packet_lower_index) <= r_input_gbt_frame(FRAMELENGTH-1 downto c_opcode_lower_index)&"11"&r_packet_index;
    o_frame(c_packet_lower_index-1 downto 0) <= (others => '0');
    o_frame_en <= '1';
    s_state <= st_RP_wait_for_first_frame_reply;
    s_state_binary <= "10100";
    r_input_gbt_frame <= (others => '0');
--when st_RP_wait_for_first_frame_reply =>  
--    r_RP_time_out <= r_RP_time_out +1;
--    if(i_frame_en = '1')then
--        r_input_gbt_frame <= i_frame;
--    end if; 
--    o_frame_en <= '0'; 
--    o_frame <= (others => '0');
----    if(r_RP_time_out >=  RPTIMEOUT)then
--	if(test_flag =  '1')then
--        r_RP_time_out <= 0;
--        r_RP_time_out_counter <= r_RP_time_out_counter +1;
--        if(r_RP_time_out_counter = 3)then
--            s_state <= st_timeout_c;
--            s_state_binary <= "10010";
--            r_RP_time_out_counter <=  0;
--        else
--            s_state <= st_send_type_c;
--            s_state_binary <= "00110";
--        end if;
--    else
--        if(r_input_gbt_frame(c_opcode_upper_index downto c_opcode_lower_index) = c_RP_opcode and r_input_gbt_frame(c_packet_upper_index downto c_packet_lower_index)=r_packet_index)then
--            s_state <= st_RP_wait_for_bitstream_fifo;
--            s_state_binary <= "10101";
--            r_RP_time_out <= 0;
--        else
--            s_state <= st_RP_wait_for_first_frame_reply;
--            s_state_binary <= "10100";
--        end if;
--    end if;
--when st_RP_wait_for_bitstream_fifo => 
--    if(i_bitstream_data_fifo_prog_full='1')then
--        s_state <= st_RP_wait_for_bitstream_fifo_read;
--        s_state_binary <= "10110";
----        s_state <= st_RP_send_bunch_frame;
----        s_RP_bunch_counter <= s_RP_bunch_counter +1;
----        r_packet_index (PACKETINDEXLENGTH-1 downto 9) <= r_packet_index (PACKETINDEXLENGTH-1 downto 9)-1;
--        o_bitstream_data_fifo_rd_en <= '1';
--    else
--        s_state <= st_RP_wait_for_bitstream_fifo;
--        s_state_binary <= "10101";
--    end if;
--when st_RP_wait_for_bitstream_fifo_read =>
--    s_state <= st_RP_send_bunch_frame;
--    s_state_binary <= "10111";
--    s_RP_bunch_counter <= s_RP_bunch_counter +1;
--when st_RP_send_bunch_frame =>
--    o_frame(c_opcode_upper_index downto c_opcode_lower_index) <= c_RP_opcode;
--    o_frame(c_payload_upper_index downto c_payload_upper_index-31) <= i_bit_stream_data;
--    o_frame(c_packet_upper_index downto c_packet_lower_index) <= r_packet_index;
--    o_frame_en <= '1';
--    if(s_RP_bunch_counter =  bunch_size-1)then 
--         o_bitstream_data_fifo_rd_en <= '0';
--    end if;
--    if(s_RP_bunch_counter =  bunch_size)then    
--        s_state <= st_RP_wait_for_next_bunch_request;
--        s_state_binary <= "11000";
----        o_bitstream_data_fifo_rd_en <= '0';
--        s_RP_bunch_counter <= 0;
--        r_input_gbt_frame <= (others => '0');
--        r_packet_index (PACKETINDEXLENGTH-1 downto 10) <= r_packet_index (PACKETINDEXLENGTH-1 downto 10)-1;
--     else
--        s_RP_bunch_counter <= s_RP_bunch_counter +1;
--        s_state <= st_RP_send_bunch_frame;
--        s_state_binary <= "10111";
--     end if;


--when st_RP_wait_for_next_bunch_request =>
--     o_frame_en <= '0';
--     r_RP_time_out <= r_RP_time_out+1;
--     if(i_frame_en = '1')then
--        r_input_gbt_frame <= i_frame;
--     end if;
     
----    if(r_RP_time_out >=  RPTIMEOUT)then
--	if(test_flag =  '1')then
--       s_state <= st_timeout_c;
--       s_state_binary <= "10010";
--     else
--        if(r_input_gbt_frame(c_opcode_upper_index downto c_opcode_lower_index) = c_RP_opcode and r_input_gbt_frame(c_packet_upper_index downto c_packet_lower_index)=r_packet_index)then
--            if(r_packet_index = "000000000000000000000")then
--                s_state <= st_RP_wait_for_completion;
--                s_state_binary <= "11001";
--                r_RP_time_out <= 0;
--                r_input_gbt_frame <= (others => '0');
--            else
--                s_state <= st_RP_wait_for_bitstream_fifo;
--                s_state_binary <= "10101";
--                r_RP_time_out <= 0;
--            end if;
            
--        else
--            s_state <= st_RP_wait_for_next_bunch_request;
--            s_state_binary <= "11000";
--        end if;
--    end if;
    
     
--when st_RP_wait_for_completion =>
--    r_RP_time_out <= r_RP_time_out+1;
--    if(i_frame_en = '1')then
--        r_input_gbt_frame <= i_frame;
--    end if;
----    if(r_RP_time_out >=  RPTIMEOUT)then
--	if(test_flag =  '1')then
--       s_state <= st_timeout_c;
--       s_state_binary <= "10010";
--     else
--        if(r_input_gbt_frame(FRAMELENGTH-1 downto c_packet_lower_index) = ("000" & c_RP_opcode & "00" & '0'& x"FFFFF"))then
--            s_state <= st_type_c_faulty_result;
--            s_state_binary <= "01111";
--            r_RP_time_out <= 0;
--        elsif(r_input_gbt_frame(FRAMELENGTH-1 downto c_packet_lower_index) = ("000" & c_RP_opcode & "00" & '1'& x"FFFFF"))then
--            s_state <= st_type_c_write_result;
--            s_state_binary <= "01100";
--            r_RP_time_out <= 0;
--        else
--            s_state <= st_RP_wait_for_completion;
--            s_state_binary <= "11001";
--        end if;
--     end if;
when st_type_c_faulty_result =>
    if(i_card_to_pc_fifo_full = '0')then
        o_card_to_pc_fifo_din(FRAMELENGTH-1 downto c_packet_lower_index) <= ("000" & c_RP_opcode & "00" & '1'& x"FFFFF");
        o_card_to_pc_fifo_din(0) <= '1';
        o_card_to_pc_fifo_wr_en <= '1';
        s_state <= st_fetch;
        s_state_binary <= "00001";
    else
        s_state <= st_type_c_faulty_result;
        s_state_binary <= "01111";
    end if;
  
when st_type_c_write_result =>
    if(i_card_to_pc_fifo_full = '0')then
        o_card_to_pc_fifo_din(FRAMELENGTH-1 downto c_packet_lower_index) <= ("000" & c_RP_opcode & "00" & '0'& x"FFFFF");
        o_card_to_pc_fifo_din(0) <= '0';
        o_card_to_pc_fifo_wr_en <= '1';
        s_state <= st_fetch;
        s_state_binary <= "00001";
    else
        s_state <= st_type_c_write_result;
        s_state_binary <= "01100";
    end if;
when st_timeout_c =>
    o_card_to_pc_fifo_din(FRAMELENGTH-1 downto c_packet_lower_index) <= ("000" & c_RP_opcode & "00" & '0'& x"FFFFF");
    o_card_to_pc_fifo_din(0) <= '1';
    o_card_to_pc_fifo_wr_en <= '1';
    s_state <= st_fetch;
    s_state_binary <= "00001";
    
when others =>
s_state <= st_fetch;
s_state_binary <= "00001";
end case;
end if;
end if;
end if;
end process;

----------------------------------- start of vahid codes---------------------------------------------
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
----------------------------------- end of vahid codes-----------------------------------------------

----------------------------------------------------------------------------------
end Behavioral;
----------------------------------------------------------------------------------
