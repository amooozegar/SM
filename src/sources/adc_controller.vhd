--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
------------------------------------------------------------------------------------------------   
ENTITY adc_controller IS
  GENERIC(
    sys_clk_freq     : INTEGER := 40_000_000;                      --input clock speed from user logic in Hz
    ADC_ADDRESS      : STD_LOGIC_VECTOR(6 DOWNTO 0) := "0101001"); --I2C address of the ADC 
  PORT(
    clk         : IN    STD_LOGIC;                                 --system clock
    reset       : IN    STD_LOGIC;                                 --synchronous active-high reset
    scl         : INOUT STD_LOGIC;                                 --I2C serial clock
    sda         : INOUT STD_LOGIC;                                 --I2C serial data
    adc_ack_err : OUT   STD_LOGIC;                                 --I2C slave acknowledge error flag 
    adc_done    : OUT   STD_LOGIC;                                 --will be '1' when getting ADC value correctly 
    adc_ena     : IN    STD_LOGIC;                                 
    adc_conv    : out   STD_LOGIC;                                 
    ch_sel      : IN    STD_LOGIC_VECTOR(2 DOWNTO 0);
    adg_mux_in  : IN    STD_LOGIC_VECTOR(3 DOWNTO 0);
    adg_mux_out : out   STD_LOGIC_VECTOR(3 DOWNTO 0);
    adc_data    : OUT   STD_LOGIC_VECTOR(9 DOWNTO 0)   
    ); 
END adc_controller;
------------------------------------------------------------------------------------------------   
ARCHITECTURE behavior OF adc_controller IS
------------------------------------------------------------------------------------------------   
  TYPE machine IS(start,  set_reg_pointer, select_adc_or_temp_value_reg , read_data, output_result , shut_down_adc
  ); --needed states
  SIGNAL state       : machine;                       --state machine
  SIGNAL config      : STD_LOGIC_VECTOR(7 DOWNTO 0);  --value to set the Sensor Configuration Register
  SIGNAL i2c_ena     : STD_LOGIC;                     --i2c enable signal
  SIGNAL i2c_addr    : STD_LOGIC_VECTOR(6 DOWNTO 0);  --i2c address signal
  SIGNAL i2c_rw      : STD_LOGIC;                     --i2c read/write command signal
  SIGNAL i2c_data_wr : STD_LOGIC_VECTOR(7 DOWNTO 0);  --i2c write data
  SIGNAL i2c_data_rd : STD_LOGIC_VECTOR(7 DOWNTO 0);  --i2c read data
  SIGNAL i2c_busy    : STD_LOGIC;                     --i2c busy signal
  SIGNAL busy_prev   : STD_LOGIC;                     --previous value of i2c busy signal
                       
  SIGNAL temp_data     : STD_LOGIC_VECTOR(15 DOWNTO 0); --adc data buffer  
  SIGNAL adc_or_temp   : STD_LOGIC;
  SIGNAL adc_ena_reg_1 : STD_LOGIC;
  SIGNAL adc_ena_reg_2 : STD_LOGIC;
  SIGNAL adc_ena_sig   : STD_LOGIC;
  SIGNAL CONFIGURATION_REGISTER  : STD_LOGIC_VECTOR (7 DOWNTO 0) := "00000001";
------------------------------------------------------------------------------------------------   
  COMPONENT i2c_master IS
    GENERIC(
     input_clk : INTEGER;  --input clock speed from user logic in Hz
     bus_clk   : INTEGER); --speed the i2c bus (scl) will run at in Hz
    PORT(
     clk       : IN     STD_LOGIC;                    --system clock
     reset     : IN     STD_LOGIC;                    --active high reset
     ena       : IN     STD_LOGIC;                    --latch in command
     addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
     rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
     data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
     busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
     data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
     ack_err   : OUT    STD_LOGIC;                    --flag if improper acknowledge from slave
     sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
     scl       : INOUT  STD_LOGIC);                   --serial clock output of i2c bus
  END COMPONENT;
------------------------------------------------------------------------------------------------   
BEGIN
------------------------------------------------------------------------------------------------   
adc_conv <= '0';
adg_mux_out <= adg_mux_in;
------------------------------------------------------------------------------------------------   
  --instantiate the i2c master
  i2c_master_0:  i2c_master
    GENERIC MAP(
    input_clk => sys_clk_freq, 
    bus_clk => 400_000
    )
    PORT MAP(
    clk => clk, 
    reset => reset, 
    ena => i2c_ena, 
    addr => i2c_addr,
    rw => i2c_rw, 
    data_wr => i2c_data_wr, 
    busy => i2c_busy,
    data_rd => i2c_data_rd, 
    ack_err => adc_ack_err, 
    sda => sda,
    scl => scl
    );
------------------------------------------------------------------------------------------------   
process (clk)
begin
    if rising_edge (clk) then
        adc_ena_reg_1 <= adc_ena;
        adc_ena_reg_2 <= adc_ena_reg_1;
    end if;
end process;
adc_ena_sig <= adc_ena_reg_1 AND NOT adc_ena_reg_2;
------------------------------------------------------------------------------------------------   
--  PROCESS(clk, reset , adc_ena_sig)
  PROCESS(clk)
    VARIABLE busy_cnt : INTEGER RANGE 0 TO 2 := 0;      --counts the busy signal transistions during one transaction
  BEGIN
  IF(clk'EVENT AND clk = '1') THEN  --rising edge of system clock
    IF(reset = '1') THEN               --reset activated
      adc_done <= '0';                      --clear adc done
      i2c_ena <= '0';                      --clear i2c enable
      busy_cnt := 0;                       --clear busy counter
      adc_data <= (OTHERS => '0');      
      state <= start;                      --return to start state
    ELSE
      CASE state IS                        --state machine
--------------------------------------------------------------              
        WHEN start =>
        adc_done <= '0';
          IF(adc_ena_sig = '1') THEN   
            state <= set_reg_pointer;             
          ELSE                                 
            state <= start;            
          END IF;
-------------------------------------------------------------- 
        WHEN set_reg_pointer =>            
          busy_prev <= i2c_busy;                       --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND i2c_busy = '1') THEN  --i2c busy just went high
            busy_cnt := busy_cnt + 1;                    --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                             --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                    --no command latched in yet
              i2c_ena <= '1';                              --initiate the transaction
              i2c_addr <= ADC_ADDRESS;                --set the address of the ADC
              i2c_rw <= '0';                               --command 1 is a write
              i2c_data_wr <= CONFIGURATION_REGISTER; --"00000001";                   --set the Register Pointer to the Configuration Register
            WHEN 1 =>                                    --1st busy high: command 1 latched, okay to issue command 2
              i2c_data_wr <= ch_sel & "00000";             --write the new configuration value to the Configuration Register
            WHEN 2 =>                                    --2nd busy high: command 2 latched
              i2c_ena <= '0';                              --deassert enable to stop transaction after command 2
              IF(i2c_busy = '0') THEN                      --transaction complete
                busy_cnt := 0;                               --reset busy_cnt for next transaction
                state <= select_adc_or_temp_value_reg;                    --advance to setting the Register Pointer for data reads
              END IF;
            WHEN OTHERS => NULL;
          END CASE;
-------------------------------------------------------------- 
        WHEN select_adc_or_temp_value_reg =>
          busy_prev <= i2c_busy;                       --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND i2c_busy = '1') THEN  --i2c busy just went high
            busy_cnt := busy_cnt + 1;                    --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                             --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                    --no command latched in yet
              i2c_ena <= '1';                              --initiate the transaction
              i2c_addr <= ADC_ADDRESS;                --set the address of the ADC
              i2c_rw <= '0';                               --command 1 is a write
              i2c_data_wr <= "00000" & adc_or_temp & "00";   --set the Register Pointer to the Ambient Temperature Register
            WHEN 1 =>                                    --1st busy high: command 1 latched
              i2c_ena <= '0';                              --deassert enable to stop transaction after command 1
              IF(i2c_busy = '0') THEN                      --transaction complete
                busy_cnt := 0;                               --reset busy_cnt for next transaction
                state <= read_data;                          --advance to reading the data
              END IF;
            WHEN OTHERS => NULL;
          END CASE;
--------------------------------------------------------------             
        WHEN read_data =>
            busy_prev <= i2c_busy;                       --capture the value of the previous i2c busy signal
            IF(busy_prev = '0' AND i2c_busy = '1') THEN  --i2c busy just went high
              busy_cnt := busy_cnt + 1;                    --counts the times busy has gone from low to high during transaction
            END IF;
            CASE busy_cnt IS                             --busy_cnt keeps track of which command we are on
              WHEN 0 =>                                    --no command latched in yet
                i2c_ena <= '1';                              --initiate the transaction
                i2c_addr <= ADC_ADDRESS;                --set the address of the ADC
                i2c_rw <= '1';                               --command 1 is a read
              WHEN 1 =>                                    --1st busy high: command 1 latched, okay to issue command 2
                IF(i2c_busy = '0') THEN                      --indicates data read in command 1 is ready
                  temp_data(15 DOWNTO 8) <= i2c_data_rd;       --retrieve MSB data from command 1
                END IF;
              WHEN 2 =>                                    --2nd busy high: command 2 latched
                i2c_ena <= '0';                              --deassert enable to stop transaction after command 2
                IF(i2c_busy = '0') THEN                      --indicates data read in command 2 is ready
                  temp_data(7 DOWNTO 0) <= i2c_data_rd;        --retrieve LSB data from command 2
                  busy_cnt := 0;                               --reset busy_cnt for next transaction
                  state <= output_result;                      --advance to output the result
                END IF;
             WHEN OTHERS => NULL;
            END CASE;
-------------------------------------------------------------- 
  --output the adc data
  WHEN output_result =>
    adc_data <= temp_data(15 DOWNTO 16-10);  --write adc data to output
    state <= shut_down_adc; 
--    state <= start; 
--------------------------------------------------------------           
  WHEN shut_down_adc =>
    adc_done <= '1';
    busy_prev <= i2c_busy;                       --capture the value of the previous i2c busy signal
  IF(busy_prev = '0' AND i2c_busy = '1') THEN  --i2c busy just went high
    busy_cnt := busy_cnt + 1;                    --counts the times busy has gone from low to high during transaction
  END IF;
  CASE busy_cnt IS                             --busy_cnt keeps track of which command we are on
    WHEN 0 =>                                    --no command latched in yet
      i2c_ena <= '1';                              --initiate the transaction
      i2c_addr <= ADC_ADDRESS;                --set the address of the ADC
      i2c_rw <= '0';                               --command 1 is a write
      i2c_data_wr <= CONFIGURATION_REGISTER; --"00000001";                   --set the Register Pointer to the Configuration Register
    WHEN 1 =>                                    --1st busy high: command 1 latched, okay to issue command 2
      i2c_data_wr <= ch_sel & "00001";             --write the new configuration value to the Configuration Register
    WHEN 2 =>                                    --2nd busy high: command 2 latched
      i2c_ena <= '0';                              --deassert enable to stop transaction after command 2
      IF(i2c_busy = '0') THEN                      --transaction complete
        busy_cnt := 0;                               --reset busy_cnt for next transaction
        state <= start;                    --advance to setting the Register Pointer for data reads
      END IF;
    WHEN OTHERS => NULL;
  END CASE;
--------------------------------------------------------------           
    --default to start state read_temp_1
        WHEN OTHERS =>
          state <= start;
-------------------------------------------------------------- 
      END CASE;
    END IF;
    END IF;
  END PROCESS;   
------------------------------------------------------------------------------------------------   
adc_or_temp <= '0' when ch_sel = "000" else '1';
--adc_done <= '1' when state = shut_down_adc else '0';
  
END behavior;
