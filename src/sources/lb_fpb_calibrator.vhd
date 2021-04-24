----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
----------------------------------------------------------------------------------
entity lb_fpb_calibrator is
  Port ( 
  clk_div           :   in  std_logic;
  rst               :   in  std_logic;
  isds_reset        :   out std_logic;
  isds_bitslip      :   out std_logic;
--  ld_dly            :   out std_logic;
  fpb_calib_done    :   out std_logic;
--  lb_state_number   :   out  std_logic_vector (3 downto 0); --
  isds_p_d_in       :   in  std_logic_vector (7 downto 0);
  osds_p_d_out      :   out std_logic_vector (7 downto 0)
  );
end lb_fpb_calibrator;
----------------------------------------------------------------------------------
architecture Behavioral of lb_fpb_calibrator is
----------------------------------------------------------------------------------
type lb_isds_calibrator_state_machine is (
idle , lb_isds_calib_bitslip_1 , lb_isds_calib_bitslip_2 ,
do_bitslip , wait_until_bitslip_done , lb_isds_calibration_done );
signal pre_state , nxt_state : lb_isds_calibrator_state_machine := idle;
----------------------------------------------------------------------------------
type lb_osds_calibrator_state_machine is (
start , send_ff , send_00 , send_bb , calibration_done);
signal pre_state_osds , nxt_state_osds : lb_osds_calibrator_state_machine := start;
----------------------------------------------------------------------------------
--signal  timer_osds              :   integer range 0 to 250 := 0; 
signal  timer                   :   integer range 0 to 15 := 0; 
signal  calib_data_counter      :   integer range 0 to 15 := 0; 
--signal  bitslip_counter         :   integer range 0 to 15 := 0; 
--signal  phase_shift_counter     :   integer range 0 to 1000 := 0; 
signal  osds_bb_counter         :   integer range 0 to 255 := 0;
signal  osds_data_counter       :   integer range 0 to 120 := 0;
signal  isds_bitslip_calib_done :   std_logic := '0';
signal  r_rst                   :   std_logic := '0'; 
signal  s_isds_bitslip          :   std_logic := '0'; 
signal  s_isds_reset            :   std_logic := '0'; 
--signal  s_mmcm_psen             :   std_logic := '0'; 
signal  s_fpb_calib_done        :   std_logic := '0'; 
signal  r_isds_bitslip          :   std_logic := '0'; 
signal  r_isds_reset            :   std_logic := '0'; 
--signal  r_mmcm_psen             :   std_logic := '0'; 
signal  r_fpb_calib_done        :   std_logic := '0'; 
----------------------------------------------------------------------------------
signal  lb_state_number         :   std_logic_vector (2 downto 0) := (others => '0');
signal  lb_osds_state_number    :   std_logic_vector (2 downto 0) := (others => '0');
signal  s_osds_p_d_out          :   std_logic_vector (7 downto 0) := (others => '0');
signal  r_osds_p_d_out          :   std_logic_vector (7 downto 0) := (others => '0');
----------------------------------------------------------------------------------
COMPONENT ila_fpb
PORT (
	clk : IN STD_LOGIC;
	probe0 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
	probe1 : IN STD_LOGIC_VECTOR(2 DOWNTO 0)
);
END COMPONENT  ;
----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
--r_rst <= rst;
process (clk_div)
variable reset_counter : integer range 0 to 20 := 0;
begin
if rising_edge (clk_div) then
    if rst = '1' then 
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
process (clk_div)
variable counter : integer range 0 to 15 := 0;
begin
if rising_edge (clk_div) then
    if r_rst = '1' then
        counter := 0;
        pre_state <= idle;
    elsif counter >= timer then
        counter := 0;
        pre_state <= nxt_state;
    else
        pre_state <= pre_state;
        counter := counter + 1;
    end if;
end if;
end process;

process (pre_state , isds_p_d_in)
begin
case pre_state is

when idle =>
    timer <= 0;
    nxt_state <= lb_isds_calib_bitslip_1;
    
when lb_isds_calib_bitslip_1 =>
    timer <= 0;
    if isds_p_d_in = "11111111" then
        nxt_state <= lb_isds_calib_bitslip_2;
    elsif isds_p_d_in = "00000000" then
        nxt_state <= lb_isds_calib_bitslip_1;
    else
        nxt_state <= do_bitslip;
    end if;

when lb_isds_calib_bitslip_2 =>
    timer <= 0;
    if calib_data_counter >= 10 then
        nxt_state <= lb_isds_calibration_done;
    else
        if isds_p_d_in = "00000000" then
            nxt_state <= lb_isds_calib_bitslip_1;
        else
            nxt_state <= idle;
        end if;
    end if;

when do_bitslip =>
    timer <= 0;
    nxt_state <= wait_until_bitslip_done;

when wait_until_bitslip_done =>
    timer <= 5;
    nxt_state <= idle;

when lb_isds_calibration_done =>
    timer <= 0;
    nxt_state <= lb_isds_calibration_done;        
    
when others =>
    timer <= 0;
    nxt_state <= idle;

end case;
end process;
----------------------------------------------------------------------------------
process (clk_div)
--variable counter : integer range 0 to 250 := 0;
begin
if rising_edge (clk_div) then
    if r_rst = '1' then
        pre_state_osds <= start;
--        counter := 0;
--    elsif counter >= timer_osds then
--        counter := 0;
else
        pre_state_osds <= nxt_state_osds;
--    else
--        counter := counter + 1;
--        pre_state_osds <= pre_state_osds;
    end if;
end if;
end process;

process (pre_state_osds , isds_p_d_in , isds_bitslip_calib_done)
begin
case pre_state_osds is

when start =>
    s_osds_p_d_out <= "00000000";
--    timer_osds <= 0;
    nxt_state_osds <= send_ff;

when send_ff =>
    s_osds_p_d_out <= "11111111";    
--    timer_osds <= 0;
    nxt_state_osds <= send_00; 

when send_00 =>
    s_osds_p_d_out <= "00000000";
--    timer_osds <= 0;
    if osds_data_counter >= 100 then
        if isds_bitslip_calib_done = '1' then
            nxt_state_osds <= send_bb;
        else
            nxt_state_osds <= send_ff;
        end if;
    else 
        nxt_state_osds <= send_ff;
    end if;

when send_bb =>
    s_osds_p_d_out <= "10111011";
--    timer_osds <= 0;
    if osds_bb_counter >= 250 then
        nxt_state_osds <= start;
    elsif isds_p_d_in = "10111011" then
        nxt_state_osds <= calibration_done;
    else
        nxt_state_osds <= send_bb;
    end if;
        
when calibration_done =>
    s_osds_p_d_out <= "00000000";
--    timer_osds <= 0;
    nxt_state_osds <= calibration_done;    
    
when others =>
    s_osds_p_d_out <= "00000000";
--    timer_osds <= 0;
    nxt_state_osds <= start;

end case;
end process;
----------------------------------------------------------------------------------
process (clk_div)
begin
if rising_edge (clk_div) then
    if pre_state = idle  OR r_rst = '1'then
        calib_data_counter <= 0;
    elsif pre_state = lb_isds_calib_bitslip_2 then
        calib_data_counter <= calib_data_counter + 1;
    else
        calib_data_counter <= calib_data_counter;
    end if;
end if;
end process;
------------------------------------------------------------------------------------
process (clk_div)
begin
if rising_edge (clk_div) then
    if r_rst = '1' OR pre_state_osds = send_bb then
        osds_data_counter <= 0;
    elsif pre_state_osds = send_ff then
        osds_data_counter <= osds_data_counter + 1;
    else
        osds_data_counter <= osds_data_counter;
    end if;
end if;
end process;

process (clk_div)
begin
if rising_edge (clk_div) then
    if pre_state_osds = start then
        osds_bb_counter <= 0;
    elsif pre_state_osds = send_bb then
        osds_bb_counter <= osds_bb_counter + 1;
    else
        osds_bb_counter <= osds_bb_counter;
    end if;
end if;
end process;
----------------------------------------------------------------------------------
s_isds_bitslip <= '1' when pre_state = do_bitslip else '0';
isds_bitslip_calib_done <= '1' when pre_state = lb_isds_calibration_done else '0';
--s_isds_reset <= '1' when pre_state = reset_iserdes else '0';
s_fpb_calib_done <= '1' when pre_state_osds = calibration_done else '0';
--ld_dly <= '1' when pre_state = do_input_delay else '0';
----------------------------------------------------------------------------------
process (clk_div)
begin
if rising_edge (clk_div) then
    if r_rst = '1' then
        r_isds_bitslip <= '0';
        r_isds_reset <= '0';
        r_fpb_calib_done <= '0';
--        r_mmcm_psen <= '0';
    else
        r_isds_bitslip <= s_isds_bitslip;
        r_isds_reset <= s_isds_reset;
        r_fpb_calib_done <= s_fpb_calib_done;
--        r_mmcm_psen <= s_mmcm_psen;
    end if;
end if;
end process;

isds_bitslip <= r_isds_bitslip;
isds_reset <= r_isds_reset;
fpb_calib_done <= r_fpb_calib_done;
----------------------------------------------------------------------------------
--process (clk_div)
--begin
--if rising_edge (clk_div) then
--    if r_rst = '1' OR pre_state = do_input_delay then
--        bitslip_counter <= 0;
--    elsif pre_state = do_bitslip then
--        bitslip_counter <= bitslip_counter + 1;
--    else
--        bitslip_counter <= bitslip_counter;
--    end if;
--end if;
--end process;
----------------------------------------------------------------------------------
--process (clk_div)
--begin
--if rising_edge (clk_div) then
--    if r_rst = '1' OR pre_state = reset_iserdes then
--        phase_shift_counter <= 0;
--    elsif pre_state = do_phase_shift then
--        phase_shift_counter <= phase_shift_counter + 1;
--    else
--        phase_shift_counter <= phase_shift_counter;
--    end if;
--end if;
--end process;
----------------------------------------------------------------------------------
process (clk_div)
begin
if rising_edge (clk_div) then
    if r_rst = '1' then
        r_osds_p_d_out <= (others => '0');
    else
        r_osds_p_d_out <= s_osds_p_d_out;
    end if;
end if;
end process;
osds_p_d_out <= r_osds_p_d_out;
----------------------------------------------------------------------------------
--ila_fpb_ins : ila_fpb
--PORT MAP (
--	clk => clk_div,
--	probe0 => lb_state_number,
--	probe1 => lb_osds_state_number
--);
----------------------------------------------------------------------------------
with pre_state select lb_state_number <= 
"001" when idle , 
"010" when lb_isds_calib_bitslip_1 , 
"011" when lb_isds_calib_bitslip_2 , 
"100" when do_bitslip , 
"101" when wait_until_bitslip_done ,
"110" when lb_isds_calibration_done , 
"000" when others;


with pre_state_osds select lb_osds_state_number <= 
"001" when start , 
"010" when send_ff , 
"011" when send_00 , 
"100" when send_bb , 
"101" when calibration_done ,
"000" when others;
----------------------------------------------------------------------------------
end Behavioral;
----------------------------------------------------------------------------------