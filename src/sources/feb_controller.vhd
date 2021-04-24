----------------------------------------------------------------------------------
--000 read ADC value
--001 set  DAC value
--010 read DAC value
--011 turn DACs ON
--100 turn DACs OFF
-- for reading adc temperature set channel to "000"
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;
----------------------------------------------------------------------------------
entity feb_controller is
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
end feb_controller;
----------------------------------------------------------------------------------
architecture Behavioral of feb_controller is
----------------------------------------------------------------------------------
component feb_i2c_master IS
  PORT(
    clk                     : IN        STD_LOGIC;   -- 40MHz                                        
    reset                   : IN        STD_LOGIC;                     
    ena                     : IN        STD_LOGIC;                     
    addr                    : IN        STD_LOGIC_VECTOR(6 DOWNTO 0);  
    rw                      : IN        STD_LOGIC;                     
    data_wr                 : IN        STD_LOGIC_VECTOR(7 DOWNTO 0);  
    busy                    : OUT       STD_LOGIC;             
    ack_err                 : OUT       STD_LOGIC;                             
    data_rd                 : OUT       STD_LOGIC_VECTOR(7 DOWNTO 0);                       
    sda_in_to_feb           : OUT       STD_LOGIC;                      
    sda_out_from_feb        : IN        STD_LOGIC;                      
    scl_in_to_feb           : OUT       STD_LOGIC
    );                     
END component;
----------------------------------------------------------------------------------
TYPE machine IS(
start, select_db , set_distribution_board, read_command ,
read_adc_value_1 ,read_adc_value_2 ,read_adc_value_3 , read_adc_value_4,
set_dac_value_1 ,set_dac_value_2 ,set_dac_value_3 , set_dac_value_4,
read_dac_value_1 ,read_dac_value_2 ,read_dac_value_3 , read_dac_value_4,     
turn_on_DACs, turn_off_DACs,         
command_done 
  ); --needed states
SIGNAL state       : machine; 
----------------------------------------------------------------------------------
signal adc_or_temp          :   std_logic := '0';
signal busy_prev            :   std_logic := '0';
signal adc_channel_number   :   STD_LOGIC_VECTOR (7 DOWNTO 0);
signal sel_dac_sig          :   STD_LOGIC_VECTOR (1 DOWNTO 0);
signal dac_channel_number   :   STD_LOGIC_VECTOR (7 DOWNTO 0);
signal  sda_in_to_feb       :   std_logic;
signal  scl_in_to_feb       :   std_logic;
signal  sda_out_from_feb    :   std_logic;
signal  sda_in_to_feb_bus   :   std_logic_vector (7 downto 0);
signal  scl_in_to_feb_bus   :   std_logic_vector (7 downto 0);
signal  sda_out_from_feb_bus:   std_logic_vector (7 downto 0);
signal  ena                 :   std_logic;
signal  rw                  :   std_logic;
signal  busy                :   std_logic;
signal  ack_error           :   std_logic;
signal  addr                :   std_logic_vector (6 downto 0);
signal  data_wr             :   std_logic_vector (7 downto 0);
signal  data_rd             :   std_logic_vector (7 downto 0);
signal  r_data_from_feb_adc :   std_logic_vector (15 downto 0);
signal  r_data_from_feb_dac :   std_logic_vector (15 downto 0);
signal  r_data_from_feb     :   std_logic_vector (9  downto 0);
----------------------------------------------------------------------------------
CONSTANT PCA9544                    : STD_LOGIC_VECTOR (6 DOWNTO 0) :=  "1110000";   -- address of PCA9544 on D.B. 
CONSTANT c_PCF8574A                 : STD_LOGIC_VECTOR (6 DOWNTO 0) :=  "0111000";   -- ADDRESS OF IO EXPANDER "0111" & A2 A1 & A0 = 0
CONSTANT c_AD5316                   : STD_LOGIC_VECTOR (6 DOWNTO 0) :=  "0001110";   -- ADDRESS OF DAC
CONSTANT CONFIGURATION_REGISTER     : STD_LOGIC_VECTOR (7 DOWNTO 0) := "00000001";
----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
PROCESS (clk_40)
VARIABLE busy_cnt : INTEGER RANGE 0 TO 3 := 0;
BEGIN
    IF (clk_40'EVENT AND clk_40 = '1') THEN
        IF (rst = '1') THEN    
            busy_cnt := 0;   
            cmd_done <= '0';    
            r_data_from_feb <= (OTHERS => '0');
            r_data_from_feb_adc <= (OTHERS => '0');
            r_data_from_feb_dac <= (OTHERS => '0');
            state <= start;
        ELSE
CASE state IS
---------------------------------------------------------------
WHEN start =>
    cmd_done <= '0';
    IF(ena_feb_controller = '1') THEN   
        state <= select_db;             
    ELSE                                 
        state <= start;            
    END IF;
---------------------------------------------------------------    
WHEN select_db =>    
    state <= set_distribution_board;
---------------------------------------------------------------
WHEN set_distribution_board =>  
      busy_prev <= busy;                       
      IF(busy_prev = '0' AND busy = '1') THEN  
        busy_cnt := busy_cnt + 1;                    
      END IF;
      CASE busy_cnt IS                             
        WHEN 0 =>                                  
          ena <= '1';                          
          addr <= PCA9544;   -- ADDRESS OF IO pca9544 on D.B.              
          rw <= '0';                         
          data_wr <= "1111110" & db_output_selector;  -- choose channel 0 or 1
        WHEN 1 =>                                   
          ena <= '0';                           
          IF(busy = '0') THEN                   
            busy_cnt := 0;                          
            state <= read_command;                     
          END IF;
        WHEN OTHERS => NULL;
      END CASE;
---------------------------------------------------------------             
WHEN read_command =>  
    case command is
    when "000" =>
        state       <= read_adc_value_1;
    when "001" =>
        state       <= set_dac_value_1;
    when "010" =>
        state       <= read_dac_value_1; 
    when "011" =>
        state       <= turn_on_DACs; 
    when "100" =>
        state       <= turn_off_DACs;         
    when others =>
        state       <= start;
    end case;
---------------------------------------------------------------   
WHEN read_adc_value_1 =>            
          busy_prev <= busy;                                        --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND busy = '1') THEN                   --i2c busy just went high
            busy_cnt := busy_cnt + 1;                               --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                                          --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                               --no command latched in yet
              ena <= '1';                                           --initiate the transaction
              addr <= "0101" & feb_selector & feb_chip_selector ;   --ADDRESS OF ADC "0101" A2 A1 A0 
              rw <= '0';                                            --command 0 is a write
              data_wr <= CONFIGURATION_REGISTER;                    --"00000001"; set the Register Pointer to the Configuration Register
            WHEN 1 =>                                               --1st busy high: command 1 latched, okay to issue command 2
              data_wr <= adc_channel_number;                        --write on config register to choose adc channel 
            WHEN 2 =>                                               --2nd busy high: command 2 latched
              ena <= '0';                                           --deassert enable to stop transaction after command 2
              IF(busy = '0') THEN                                   --transaction complete
                busy_cnt := 0;                                      --reset busy_cnt for next transaction
                state <= read_adc_value_2;                          --advance to setting the Register Pointer for data reads
              END IF;
            WHEN OTHERS => NULL;
          END CASE;
------------------------               
WHEN read_adc_value_2 => 
      busy_prev <= busy;                       
      IF(busy_prev = '0' AND busy = '1') THEN  
        busy_cnt := busy_cnt + 1;                    
      END IF;
      CASE busy_cnt IS                             
        WHEN 0 =>                                  
          ena <= '1';                          
          addr <= "0101" & feb_selector & feb_chip_selector ;   --ADDRESS OF ADC "0101" A2 A1 A0              
          rw <= '0';                         
          data_wr <= "00000" & adc_or_temp & "00";              --choose channel adc or temp value register
        WHEN 1 =>                                   
          ena <= '0';                           
          IF(busy = '0') THEN                   
            busy_cnt := 0;                          
            state <= read_adc_value_3;                     
          END IF;
        WHEN OTHERS => NULL;
      END CASE;
------------------------          
WHEN read_adc_value_3 =>
    busy_prev <= busy;                                      --capture the value of the previous i2c busy signal
    IF(busy_prev = '0' AND busy = '1') THEN                 --i2c busy just went high
      busy_cnt := busy_cnt + 1;                             --counts the times busy has gone from low to high during transaction
    END IF;
    CASE busy_cnt IS                                        --busy_cnt keeps track of which command we are on
      WHEN 0 =>                                             --no command latched in yet
        ena <= '1';                                         --initiate the transaction
        addr <= "0101" & feb_selector & feb_chip_selector ; --ADDRESS OF ADC "0101" A2 A1 A0
        rw <= '1';                                          --command 1 is a read
      WHEN 1 =>                                             --1st busy high: command 1 latched, okay to issue command 2
        IF(busy = '0') THEN                                 --indicates data read in command 1 is ready
          r_data_from_feb_adc(15 DOWNTO 8) <= data_rd;      --retrieve MSB data from command 1
        END IF;
      WHEN 2 =>                                             --2nd busy high: command 2 latched
        ena <= '0';                                         --deassert enable to stop transaction after command 2
        IF(busy = '0') THEN                                 --indicates data read in command 2 is ready
          r_data_from_feb_adc(7 DOWNTO 0) <= data_rd;       --retrieve LSB data from command 2                                                                                   
          busy_cnt := 0;                                    --reset busy_cnt for next transaction
          state <= read_adc_value_4;                            --advance to output the result
          END IF;
     WHEN OTHERS => NULL;
    END CASE;
------------------------    
WHEN read_adc_value_4 =>   
    r_data_from_feb <= r_data_from_feb_adc (15 downto 6);
    state <= command_done;  
---------------------------------------------------------------
WHEN set_dac_value_1 =>   --set address for dac 1 or dac 2 
      busy_prev <= busy;                       
      IF(busy_prev = '0' AND busy = '1') THEN  
        busy_cnt := busy_cnt + 1;                    
      END IF;
      CASE busy_cnt IS                             
        WHEN 0 =>                                  
          ena <= '1';                          
          addr <= "0111" & feb_selector & '0';   -- ADDRESS OF IO EXPANDER "0111" & A2 A1 & A0 = 0             
          rw <= '0';                         
          data_wr <= "0000" & "00" & sel_dac_sig; --select DAC: feb_chip_selector='0'->sel_dac_sig=01->DAC1, feb_chip_selector='1'->sel_dac_sig=10->DAC2
        WHEN 1 =>                                   
          ena <= '0';                           
          IF(busy = '0') THEN                   
            busy_cnt := 0;                          
            state <= set_dac_value_2;                     
          END IF;
        WHEN OTHERS => NULL;
      END CASE;
------------------------        
WHEN set_dac_value_2 =>     
          busy_prev <= busy;                                        --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND busy = '1') THEN                   --i2c busy just went high
            busy_cnt := busy_cnt + 1;                               --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                                          --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                               --no command latched in yet
              ena <= '1';                                           --initiate the transaction
              addr <= c_AD5316 ;                                    --ADDRESS OF DAC "0001" A2 A1 & A0 = 0 
              rw <= '0';                                            --command 0 is a write
              data_wr <= dac_channel_number;                        --select dac channel
            WHEN 1 =>                                               --1st busy high: command 1 latched, okay to issue command 2
              data_wr <= "0011" & data_to_feb (9 DOWNTO 6);                        --write on config register to choose adc channel 
            WHEN 2 =>                                               --2nd busy high: command 2 latched
              data_wr <= data_to_feb (5 DOWNTO 0) & "00" ;
            WHEN 3 =>                                               --2nd busy high: command 2 latched
              ena <= '0';                                           --deassert enable to stop transaction after command 2
              IF(busy = '0') THEN                                   --transaction complete
                busy_cnt := 0;                                      --reset busy_cnt for next transaction
                state <= set_dac_value_3;                          --advance to setting the Register Pointer for data reads
              END IF;
            WHEN OTHERS => NULL;
          END CASE;
------------------------
WHEN set_dac_value_3 =>
    busy_prev <= busy;                                      --capture the value of the previous i2c busy signal
    IF(busy_prev = '0' AND busy = '1') THEN                 --i2c busy just went high
      busy_cnt := busy_cnt + 1;                             --counts the times busy has gone from low to high during transaction
    END IF;
    CASE busy_cnt IS                                        --busy_cnt keeps track of which command we are on
      WHEN 0 =>                                             --no command latched in yet
        ena <= '1';                                         --initiate the transaction
        addr <= c_AD5316 ;                                    --ADDRESS OF DAC "0001" A2 A1 & A0 = 0
        rw <= '1';                                          --command 1 is a read
      WHEN 1 =>                                             --1st busy high: command 1 latched, okay to issue command 2
        IF(busy = '0') THEN                                 --indicates data read in command 1 is ready
          r_data_from_feb_dac(15 DOWNTO 8) <= data_rd;      --retrieve MSB data from command 1
        END IF;
      WHEN 2 =>                                             --2nd busy high: command 2 latched
        ena <= '0';                                         --deassert enable to stop transaction after command 2
        IF(busy = '0') THEN                                 --indicates data read in command 2 is ready
          r_data_from_feb_dac(7 DOWNTO 0) <= data_rd;       --retrieve LSB data from command 2          
          busy_cnt := 0;                                    --reset busy_cnt for next transaction
          state <= set_dac_value_4;                            --advance to output the result
          END IF;
     WHEN OTHERS => NULL;
    END CASE;
------------------------
WHEN set_dac_value_4 =>   
    r_data_from_feb <= r_data_from_feb_dac (11 DOWNTO 2);
    state <= command_done;  
---------------------------------------------------------------
WHEN read_dac_value_1 => --set address for dac 1 or dac 2 
      busy_prev <= busy;                       
      IF(busy_prev = '0' AND busy = '1') THEN  
        busy_cnt := busy_cnt + 1;                    
      END IF;
      CASE busy_cnt IS                             
        WHEN 0 =>                                  
          ena <= '1';                          
          addr <= "0111" & feb_selector & '0';   -- ADDRESS OF IO EXPANDER "0111" & A2 A1 & A0 = 0             
          rw <= '0';                         
          data_wr <= "0000" & "00" & sel_dac_sig; --select DAC: feb_chip_selector='0'->sel_dac_sig=01->DAC1, feb_chip_selector='1'->sel_dac_sig=10->DAC2
        WHEN 1 =>                                   
          ena <= '0';                           
          IF(busy = '0') THEN                   
            busy_cnt := 0;                          
            state <= read_dac_value_2;                     
          END IF;
        WHEN OTHERS => NULL;
      END CASE;
------------------------      
WHEN read_dac_value_2 =>     
          busy_prev <= busy;                                        --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND busy = '1') THEN                   --i2c busy just went high
            busy_cnt := busy_cnt + 1;                               --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                                          --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                               --no command latched in yet
              ena <= '1';                                           --initiate the transaction
              addr <= c_AD5316 ;                                    --ADDRESS OF DAC "0001" A2 A1 & A0 = 0 
              rw <= '0';                                            --command 0 is a write
              data_wr <= dac_channel_number;                        --select dac channel
            WHEN 1 =>                                               --1st busy high: command 1 latched, okay to issue command 2
              ena <= '0';                                           --deassert enable to stop transaction after command 2
              IF(busy = '0') THEN                                   --transaction complete
                busy_cnt := 0;                                      --reset busy_cnt for next transaction
                state <= read_dac_value_3;                          --advance to setting the Register Pointer for data reads
              END IF;  
            WHEN OTHERS => NULL;
          END CASE;
------------------------
WHEN read_dac_value_3 =>
    busy_prev <= busy;                                      --capture the value of the previous i2c busy signal
    IF(busy_prev = '0' AND busy = '1') THEN                 --i2c busy just went high
      busy_cnt := busy_cnt + 1;                             --counts the times busy has gone from low to high during transaction
    END IF;
    CASE busy_cnt IS                                        --busy_cnt keeps track of which command we are on
      WHEN 0 =>                                             --no command latched in yet
        ena <= '1';                                         --initiate the transaction
        addr <= c_AD5316 ;                                  --ADDRESS OF DAC "0001" A2 A1 & A0 = 0
        rw <= '1';                                          --command 1 is a read
      WHEN 1 =>                                             --1st busy high: command 1 latched, okay to issue command 2
        IF(busy = '0') THEN                                 --indicates data read in command 1 is ready
          r_data_from_feb_dac(15 DOWNTO 8) <= data_rd;      --retrieve MSB data from command 1
        END IF;
      WHEN 2 =>                                             --2nd busy high: command 2 latched
        ena <= '0';                                         --deassert enable to stop transaction after command 2
        IF(busy = '0') THEN                                 --indicates data read in command 2 is ready
          r_data_from_feb_dac(7 DOWNTO 0) <= data_rd;       --retrieve LSB data from command 2
          busy_cnt := 0;                                    --reset busy_cnt for next transaction
          state <= read_dac_value_4;                            --advance to output the result
          END IF;
     WHEN OTHERS => NULL;
    END CASE;
------------------------
WHEN read_dac_value_4 =>   
    r_data_from_feb <= r_data_from_feb_dac (11 DOWNTO 2);
    state <= command_done;    
---------------------------------------------------------------
WHEN turn_on_DACs =>   
      busy_prev <= busy;                       
      IF(busy_prev = '0' AND busy = '1') THEN  
        busy_cnt := busy_cnt + 1;                    
      END IF;
      CASE busy_cnt IS                             
        WHEN 0 =>                                  
          ena <= '1';                          
          addr <= "0111" & feb_selector & '0';   -- ADDRESS OF IO EXPANDER "0111" & A2 A1 & A0 = 0             
          rw <= '0';                         
          data_wr <= "0000" & "00" & sel_dac_sig; --select DAC: feb_chip_selector='0'->sel_dac_sig=01->DAC1, feb_chip_selector='1'->sel_dac_sig=10->DAC2
        WHEN 1 =>                                   
          ena <= '0';                           
          IF(busy = '0') THEN                   
            busy_cnt := 0;                          
            state <= command_done;                     
          END IF;
        WHEN OTHERS => NULL;
      END CASE;
---------------------------------------------------------------
WHEN turn_off_DACs =>   --set address for dac 1 or dac 2 
      busy_prev <= busy;                       
      IF(busy_prev = '0' AND busy = '1') THEN  
        busy_cnt := busy_cnt + 1;                    
      END IF;
      CASE busy_cnt IS                             
        WHEN 0 =>                                  
          ena <= '1';                          
          addr <= "0111" & feb_selector & '0';   -- ADDRESS OF IO EXPANDER "0111" & A2 A1 & A0 = 0             
          rw <= '0';                         
          data_wr <= "0000" & "11" & sel_dac_sig; --select DAC: feb_chip_selector='0'->sel_dac_sig=01->DAC1, feb_chip_selector='1'->sel_dac_sig=10->DAC2
        WHEN 1 =>                                   
          ena <= '0';                           
          IF(busy = '0') THEN                   
            busy_cnt := 0;                          
            state <= command_done;                     
          END IF;
        WHEN OTHERS => NULL;
      END CASE;      
---------------------------------------------------------------
WHEN command_done => 
    state <= start;
    cmd_done <= '1';
---------------------------------------------------------------    
WHEN others =>     
    state <= start;
---------------------------------------------------------------
END case;
END IF;
END IF;
END PROCESS; 
----------------------------------------------------------------------------------
--data_from_feb_adc <= r_data_from_feb_adc (15 downto 6);
data_from_feb <= r_data_from_feb;
----------------------------------------------------------------------------------
WITH channel_selector SELECT adc_channel_number <= 
    "00100000"  WHEN "001",      -- CHANNEL A 
    "01000000"  WHEN "010",      -- CHANNEL B
    "01100000"  WHEN "011",      -- CHANNEL C
    "10000000"  WHEN "100",      -- CHANNEL D  
    "00000000"  WHEN OTHERS;  
----------------------------------------------------------------------------------
WITH channel_selector SELECT dac_channel_number <= 
    "00000001"  WHEN "001",      -- CHANNEL A
    "00000010"  WHEN "010",      -- CHANNEL B
    "00000100"  WHEN "011",      -- CHANNEL C
    "00001000"  WHEN "100",      -- CHANNEL D
    "00000000"  WHEN OTHERS;    
----------------------------------------------------------------------------------
--data_from_feb_dac    <= r_data_from_feb_dac (11 DOWNTO 2);
----------------------------------------------------------------------------------
adc_or_temp <= '0' when channel_selector = "000" else '1';
----------------------------------------------------------------------------------
sel_dac_sig <= "01" when feb_chip_selector = '0' else "10";
----------------------------------------------------------------------------------
feb_connection_error <= ack_error;
----------------------------------------------------------------------------------
feb_i2c_master_ins : feb_i2c_master
  PORT map(
    clk                     => clk_40,                              
    reset                   => rst,
    ena                     => ena,
    addr                    => addr,
    rw                      => rw,
    data_wr                 => data_wr,
    busy                    => busy,                     
    ack_err                 => ack_error,                     
    data_rd                 => data_rd,                     
    sda_in_to_feb           => sda_in_to_feb, 
    sda_out_from_feb        => sda_out_from_feb, 
    scl_in_to_feb           => scl_in_to_feb    
    );
----------------------------------------------------------------------------------
sda_in_to_feb_bus(0) <= sda_in_to_feb when db_selector = "000" else '0';
sda_in_to_feb_bus(1) <= sda_in_to_feb when db_selector = "001" else '0';
sda_in_to_feb_bus(2) <= sda_in_to_feb when db_selector = "010" else '0';
sda_in_to_feb_bus(3) <= sda_in_to_feb when db_selector = "011" else '0';
sda_in_to_feb_bus(4) <= sda_in_to_feb when db_selector = "100" else '0';
sda_in_to_feb_bus(5) <= sda_in_to_feb when db_selector = "101" else '0';
sda_in_to_feb_bus(6) <= sda_in_to_feb when db_selector = "110" else '0';
sda_in_to_feb_bus(7) <= sda_in_to_feb when db_selector = "111" else '0';

scl_in_to_feb_bus(0) <= scl_in_to_feb when db_selector = "000" else '0';
scl_in_to_feb_bus(1) <= scl_in_to_feb when db_selector = "001" else '0';
scl_in_to_feb_bus(2) <= scl_in_to_feb when db_selector = "010" else '0';
scl_in_to_feb_bus(3) <= scl_in_to_feb when db_selector = "011" else '0';
scl_in_to_feb_bus(4) <= scl_in_to_feb when db_selector = "100" else '0';
scl_in_to_feb_bus(5) <= scl_in_to_feb when db_selector = "101" else '0';
scl_in_to_feb_bus(6) <= scl_in_to_feb when db_selector = "110" else '0';
scl_in_to_feb_bus(7) <= scl_in_to_feb when db_selector = "111" else '0';

with db_selector select sda_out_from_feb <=
sda_out_from_feb_bus(0) when "000",
sda_out_from_feb_bus(1) when "001",
sda_out_from_feb_bus(2) when "010",
sda_out_from_feb_bus(3) when "011",
sda_out_from_feb_bus(4) when "100",
sda_out_from_feb_bus(5) when "101",
sda_out_from_feb_bus(6) when "110",
sda_out_from_feb_bus(7) when "111",
'0' when others;
----------------------------------------------------------------------------------
--OBUFDS_inst_sda_out_0 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   sda_in_to_feb_p(0), -- Diff_p output (connect directly to top-level port)
--OB =>  sda_in_to_feb_n(0), -- Diff_n output (connect directly to top-level port)
--I => sda_in_to_feb_bus(0) -- Buffer input
--);
sda_in_to_feb_p(0) <= sda_in_to_feb_bus(0);

--OBUFDS_inst_scl_out_0 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   scl_in_to_feb_p(0), -- Diff_p output (connect directly to top-level port)
--OB =>  scl_in_to_feb_n(0), -- Diff_n output (connect directly to top-level port)
--I => scl_in_to_feb_bus(0) -- Buffer input
--);
scl_in_to_feb_p(0) <= scl_in_to_feb_bus(0);

--IBUFDS_inst_sda_in_0 : IBUFDS
--generic map (
--DIFF_TERM => FALSE, -- Differential Termination
--IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
--IOSTANDARD => "DEFAULT")
--port map (
--O => sda_out_from_feb_bus(0), -- Buffer output
--I =>   sda_out_from_feb_p(0), -- Diff_p buffer input (connect directly to top-level port)
--IB =>  sda_out_from_feb_n(0) -- Diff_n buffer input (connect directly to top-level port)
--);
sda_out_from_feb_bus(0) <= sda_out_from_feb_p(0);
--------------------------------------
--OBUFDS_inst_sda_out_1 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   sda_in_to_feb_p(1), -- Diff_p output (connect directly to top-level port)
--OB =>  sda_in_to_feb_n(1), -- Diff_n output (connect directly to top-level port)
--I => sda_in_to_feb_bus(1) -- Buffer input
--);

--OBUFDS_inst_scl_out_1 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   scl_in_to_feb_p(1), -- Diff_p output (connect directly to top-level port)
--OB =>  scl_in_to_feb_n(1), -- Diff_n output (connect directly to top-level port)
--I => scl_in_to_feb_bus(1) -- Buffer input
--);

--IBUFDS_inst_sda_in_1 : IBUFDS
--generic map (
--DIFF_TERM => FALSE, -- Differential Termination
--IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
--IOSTANDARD => "DEFAULT")
--port map (
--O => sda_out_from_feb_bus(1), -- Buffer output
--I =>   sda_out_from_feb_p(1), -- Diff_p buffer input (connect directly to top-level port)
--IB =>  sda_out_from_feb_n(1) -- Diff_n buffer input (connect directly to top-level port)
--);
----------------------------------------
--OBUFDS_inst_sda_out_2 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   sda_in_to_feb_p(2), -- Diff_p output (connect directly to top-level port)
--OB =>  sda_in_to_feb_n(2), -- Diff_n output (connect directly to top-level port)
--I => sda_in_to_feb_bus(2) -- Buffer input
--);

--OBUFDS_inst_scl_out_2 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   scl_in_to_feb_p(2), -- Diff_p output (connect directly to top-level port)
--OB =>  scl_in_to_feb_n(2), -- Diff_n output (connect directly to top-level port)
--I => scl_in_to_feb_bus(2) -- Buffer input
--);

--IBUFDS_inst_sda_in_2 : IBUFDS
--generic map (
--DIFF_TERM => FALSE, -- Differential Termination
--IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
--IOSTANDARD => "DEFAULT")
--port map (
--O => sda_out_from_feb_bus(2), -- Buffer output
--I =>   sda_out_from_feb_p(2), -- Diff_p buffer input (connect directly to top-level port)
--IB =>  sda_out_from_feb_n(2) -- Diff_n buffer input (connect directly to top-level port)
--);
----------------------------------------
--OBUFDS_inst_sda_out_3 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   sda_in_to_feb_p(3), -- Diff_p output (connect directly to top-level port)
--OB =>  sda_in_to_feb_n(3), -- Diff_n output (connect directly to top-level port)
--I => sda_in_to_feb_bus(3) -- Buffer input
--);

--OBUFDS_inst_scl_out_3 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   scl_in_to_feb_p(3), -- Diff_p output (connect directly to top-level port)
--OB =>  scl_in_to_feb_n(3), -- Diff_n output (connect directly to top-level port)
--I => scl_in_to_feb_bus(3) -- Buffer input
--);

--IBUFDS_inst_sda_in_3 : IBUFDS
--generic map (
--DIFF_TERM => FALSE, -- Differential Termination
--IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
--IOSTANDARD => "DEFAULT")
--port map (
--O => sda_out_from_feb_bus(3), -- Buffer output
--I =>   sda_out_from_feb_p(3), -- Diff_p buffer input (connect directly to top-level port)
--IB =>  sda_out_from_feb_n(3) -- Diff_n buffer input (connect directly to top-level port)
--);
----------------------------------------
--OBUFDS_inst_sda_out_4 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   sda_in_to_feb_p(4), -- Diff_p output (connect directly to top-level port)
--OB =>  sda_in_to_feb_n(4), -- Diff_n output (connect directly to top-level port)
--I => sda_in_to_feb_bus(4) -- Buffer input
--);

--OBUFDS_inst_scl_out_4 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   scl_in_to_feb_p(4), -- Diff_p output (connect directly to top-level port)
--OB =>  scl_in_to_feb_n(4), -- Diff_n output (connect directly to top-level port)
--I => scl_in_to_feb_bus(4) -- Buffer input
--);

--IBUFDS_inst_sda_in_4 : IBUFDS
--generic map (
--DIFF_TERM => FALSE, -- Differential Termination
--IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
--IOSTANDARD => "DEFAULT")
--port map (
--O => sda_out_from_feb_bus(4), -- Buffer output
--I =>   sda_out_from_feb_p(4), -- Diff_p buffer input (connect directly to top-level port)
--IB =>  sda_out_from_feb_n(4) -- Diff_n buffer input (connect directly to top-level port)
--);
----------------------------------------
--OBUFDS_inst_sda_out_5 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   sda_in_to_feb_p(5), -- Diff_p output (connect directly to top-level port)
--OB =>  sda_in_to_feb_n(5), -- Diff_n output (connect directly to top-level port)
--I => sda_in_to_feb_bus(5) -- Buffer input
--);

--OBUFDS_inst_scl_out_5 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   scl_in_to_feb_p(5), -- Diff_p output (connect directly to top-level port)
--OB =>  scl_in_to_feb_n(5), -- Diff_n output (connect directly to top-level port)
--I => scl_in_to_feb_bus(5) -- Buffer input
--);

--IBUFDS_inst_sda_in_5 : IBUFDS
--generic map (
--DIFF_TERM => FALSE, -- Differential Termination
--IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
--IOSTANDARD => "DEFAULT")
--port map (
--O => sda_out_from_feb_bus(5), -- Buffer output
--I =>   sda_out_from_feb_p(5), -- Diff_p buffer input (connect directly to top-level port)
--IB =>  sda_out_from_feb_n(5) -- Diff_n buffer input (connect directly to top-level port)
--);
----------------------------------------
--OBUFDS_inst_sda_out_6 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   sda_in_to_feb_p(6), -- Diff_p output (connect directly to top-level port)
--OB =>  sda_in_to_feb_n(6), -- Diff_n output (connect directly to top-level port)
--I => sda_in_to_feb_bus(6) -- Buffer input
--);

--OBUFDS_inst_scl_out_6 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   scl_in_to_feb_p(6), -- Diff_p output (connect directly to top-level port)
--OB =>  scl_in_to_feb_n(6), -- Diff_n output (connect directly to top-level port)
--I => scl_in_to_feb_bus(6) -- Buffer input
--);

--IBUFDS_inst_sda_in_6 : IBUFDS
--generic map (
--DIFF_TERM => FALSE, -- Differential Termination
--IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
--IOSTANDARD => "DEFAULT")
--port map (
--O => sda_out_from_feb_bus(6), -- Buffer output
--I =>   sda_out_from_feb_p(6), -- Diff_p buffer input (connect directly to top-level port)
--IB =>  sda_out_from_feb_n(6) -- Diff_n buffer input (connect directly to top-level port)
--);
----------------------------------------
--OBUFDS_inst_sda_out_7 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   sda_in_to_feb_p(7), -- Diff_p output (connect directly to top-level port)
--OB =>  sda_in_to_feb_n(7), -- Diff_n output (connect directly to top-level port)
--I => sda_in_to_feb_bus(7) -- Buffer input
--);

--OBUFDS_inst_scl_out_7 : OBUFDS
--generic map (
--IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
--SLEW => "SLOW") -- Specify the output slew rate
--port map (
--O =>   scl_in_to_feb_p(7), -- Diff_p output (connect directly to top-level port)
--OB =>  scl_in_to_feb_n(7), -- Diff_n output (connect directly to top-level port)
--I => scl_in_to_feb_bus(7) -- Buffer input
--);

--IBUFDS_inst_sda_in_7 : IBUFDS
--generic map (
--DIFF_TERM => FALSE, -- Differential Termination
--IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
--IOSTANDARD => "DEFAULT")
--port map (
--O => sda_out_from_feb_bus(7), -- Buffer output
--I =>   sda_out_from_feb_p(7), -- Diff_p buffer input (connect directly to top-level port)
--IB =>  sda_out_from_feb_n(7) -- Diff_n buffer input (connect directly to top-level port)
--);
----------------------------------------------------------------------------------
end Behavioral;
----------------------------------------------------------------------------------