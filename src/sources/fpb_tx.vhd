----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
----------------------------------------------------------------------------------
entity fpb_tx is
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
end fpb_tx;
----------------------------------------------------------------------------------
architecture Behavioral of fpb_tx is
----------------------------------------------------------------------------------
type state_machine  is (idle, ready_to_send_frame , send_start , send_frame);
signal  pre_state , nxt_state : state_machine := idle;   
----------------------------------------------------------------------------------
signal  crc_out             :   std_logic_vector (7 downto 0);
signal  osds_p_d_in         :   std_logic_vector (7 downto 0);
signal  r_frame_in          :   std_logic_vector (frame_width-1 downto 0);
----------------------------------------------------------------------------------
signal timer : integer range 0 to 15 := 0;
signal counter : integer range 0 to 15 := 0;
--signal sub_frame_counter/ : integer range 0 to 9 := 0;
----------------------------------------------------------------------------------
component crc is
  port ( 
    data_in : in  std_logic_vector (79 downto 0);
    crc_out : out std_logic_vector (7 downto 0));
end component;
----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
osds_p_data <= osds_p_d_in;
----------------------------------------------------------------------------------
process (clk_div)
--variable counter : integer range 0 to 9 := 0;
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

process (pre_state,calib_done,ena,counter)
begin
case pre_state is

when idle =>
    timer <= 0;
    osds_p_d_in <= (others => '0');
    if calib_done = '1' then
        nxt_state <= ready_to_send_frame;
    else
        nxt_state <= idle;
    end if;

when ready_to_send_frame =>
    timer <= 0;
    osds_p_d_in <= (others => '0');
    if ena = '1' then
        nxt_state <= send_start;
    else
        nxt_state <= ready_to_send_frame;
    end if;

when send_start =>
    timer <= 0;
    nxt_state <= send_frame;
    osds_p_d_in <= "10101010";

when send_frame =>
    timer <= 12;
    nxt_state <= ready_to_send_frame;
    if counter = 0 then
        osds_p_d_in <= r_frame_in (7 downto 0);
    elsif counter = 1 then
        osds_p_d_in <= r_frame_in (15 downto 8);
    elsif counter = 2 then
        osds_p_d_in <= r_frame_in (23 downto 16);
    elsif counter = 3 then
        osds_p_d_in <= r_frame_in (31 downto 24);
    elsif counter = 4 then
        osds_p_d_in <= r_frame_in (39 downto 32);
    elsif counter = 5 then
        osds_p_d_in <= r_frame_in (47 downto 40);
    elsif counter = 6 then
        osds_p_d_in <= r_frame_in (55 downto 48);
    elsif counter = 7 then
        osds_p_d_in <= r_frame_in (63 downto 56);
    elsif counter = 8 then
        osds_p_d_in <= r_frame_in (71 downto 64);
    elsif counter = 9 then
        osds_p_d_in <= r_frame_in (79 downto 72);
    elsif counter = 10 then
        osds_p_d_in <= crc_out;        
    else
        osds_p_d_in <= (others => '0');
    end if;

when others =>
    timer <= 0;
    osds_p_d_in <= (others => '0');
    nxt_state <= idle;

end case;
end process;
----------------------------------------------------------------------------------
process (clk_div)
begin
if rising_edge (clk_div) then
    if rst = '1' then
        r_frame_in <= (others => '0');
    else
        if pre_state = ready_to_send_frame then
            r_frame_in <= frame_in;
        else
            r_frame_in <= r_frame_in;
        end if;
    end if;
end if;
end process;
----------------------------------------------------------------------------------
ready <= '1' when pre_state = ready_to_send_frame else '0';
--led <= "10101010" when bitslip_d_gen_done = '1' else "11110000";
----------------------------------------------------------------------------------
crc_ins : crc
  port map( 
    data_in => r_frame_in,
    crc_out => crc_out
    );
----------------------------------------------------------------------------------
end Behavioral;
----------------------------------------------------------------------------------