----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
----------------------------------------------------------------------------------
entity fpb_rx is
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
end fpb_rx;
----------------------------------------------------------------------------------
architecture Behavioral of fpb_rx is
----------------------------------------------------------------------------------
type state_machine  is (idle, ready_to_receive_frame_start , receive_frame,calculate_crc, receive_frame_done);
signal  pre_state , nxt_state : state_machine := idle;   
----------------------------------------------------------------------------------
signal  s_crc_check         :   std_logic := '0';
signal  r_crc_check         :   std_logic := '0';
signal  s_new_frame         :   std_logic := '0';
signal  r_new_frame         :   std_logic := '0';
--signal  r_new_frame_2       :   std_logic := '0';
signal  received_frame      :   std_logic_vector (87 downto 0) := (others => '0');
signal  r_received_frame    :   std_logic_vector (87 downto 0) := (others => '0');
signal  crc_in              :   std_logic_vector (7 downto 0) := (others => '0');
signal  crc_out             :   std_logic_vector (7 downto 0) := (others => '0');
----------------------------------------------------------------------------------
signal timer    : integer range 0 to 15 := 0;
signal counter  : integer range 0 to 15 := 0;
----------------------------------------------------------------------------------
component crc is
  port ( 
    data_in : in  std_logic_vector (79 downto 0);
    crc_out : out std_logic_vector (7 downto 0));
end component;
----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
process (clk_div)
begin
if rising_edge (clk_div) then
    if rst = '1' then
        pre_state <= idle;
        counter <= 0;
    else
        if counter >= timer then
            pre_state <= nxt_state;
            counter <= 0;
        else
            pre_state <= pre_state;
            counter <= counter + 1;
        end if;
    end if;
end if;
end process;

process (pre_state,calib_done,isds_p_data, counter)
begin
case pre_state is

when idle =>
    timer <= 0;
    if calib_done = '1' then
        nxt_state <= ready_to_receive_frame_start;
    else
        nxt_state <= idle;
    end if;

when ready_to_receive_frame_start =>
    timer <= 0;
    if isds_p_data = "10101010" then
        nxt_state <= receive_frame;
    else
        nxt_state <= ready_to_receive_frame_start;
    end if;

when receive_frame =>
    timer <= 10;
    nxt_state <= calculate_crc;

when calculate_crc =>
    timer <= 0;
    nxt_state <= receive_frame_done;
    
when receive_frame_done =>
    timer <= 0;
    nxt_state <= ready_to_receive_frame_start;

when others =>
    timer <= 0;
    nxt_state <= idle;

end case;
end process;
----------------------------------------------------------------------------------
s_new_frame <= '1' when pre_state = receive_frame_done else '0'; 
frame_out <= received_frame (79 downto 0);
--frame_out <= r_received_frame;
----------------------------------------------------------------------------------
process (clk_div)
begin
if rising_edge (clk_div) then
    r_new_frame <= s_new_frame;
end if;
end process;
new_frame <= r_new_frame;
----------------------------------------------------------------------------------
--process (clk_div)
--begin
--if rising_edge (clk_div) then
--    if rst = '1' then
--        r_received_frame <= (others => '0');
--    elsif s_new_frame = '1' then
--        r_received_frame <= received_frame;
--    else
--        r_received_frame <= r_received_frame;
--    end if;
--end if;
--end process;
----------------------------------------------------------------------------------
process (clk_div)
begin
if rising_edge (clk_div) then
    if rst = '1' then
        received_frame <= (others => '0');
    else
     if pre_state = receive_frame then
        received_frame <= isds_p_data  &  received_frame (87 downto 8);
     else
        received_frame <= received_frame;
    end if;
    end if;
end if;
end process;
----------------------------------------------------------------------------------
crc_ins : crc
  port map( 
    data_in => received_frame(79 downto 0),
    crc_out => crc_out
    );
----------------------------------------------------------------------------------
crc_in <= received_frame(87 downto 80);
s_crc_check <= '1' when crc_out = crc_in else '0';

process (clk_div)
begin
if rising_edge (clk_div) then
    r_crc_check <= s_crc_check;
end if;
end process;
crc_check <= r_crc_check;
----------------------------------------------------------------------------------
end Behavioral;
----------------------------------------------------------------------------------