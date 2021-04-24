----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;
----------------------------------------------------------------------------------
entity diag_controller is
  Port (
  i_clk_40                : in   std_logic;  
  i_reset                 : in   std_logic;  
  o_diag_done             : out  std_logic;
  i_diag_rd_en            : in   std_logic; 
  i_diag_enable           : in   std_logic; 
  i_diag_type             : in   std_logic_vector (3 downto 0); 
  i_diag_packet_length    : in   std_logic_vector (20 downto 0); 
  o_diag_packet_length    : out  std_logic_vector (20 downto 0); 
  o_diag_data             : out  std_logic_vector (47 downto 0)
   );
end diag_controller;
----------------------------------------------------------------------------------
architecture Behavioral of diag_controller is
----------------------------------------------------------------------------------
COMPONENT fifo
  PORT (
    clk     : IN STD_LOGIC;
    srst    : IN STD_LOGIC;
    din     : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    wr_en   : IN STD_LOGIC;
    rd_en   : IN STD_LOGIC;
    dout    : OUT STD_LOGIC_VECTOR(47 DOWNTO 0);
    full    : OUT STD_LOGIC;
    empty   : OUT STD_LOGIC;
    valid   : OUT STD_LOGIC;
    data_count : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
  );
END COMPONENT;
----------------------------------------------------------------------------------
COMPONENT ila_diag
PORT (
	clk : IN STD_LOGIC;
	probe0 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
	probe1 : IN STD_LOGIC_VECTOR(20 DOWNTO 0)
);
END COMPONENT  ;
----------------------------------------------------------------------------------
type diag_controller_state_machine is (idle , gen_data , gen_data_done , send_data);
signal state : diag_controller_state_machine := idle;
----------------------------------------------------------------------------------
signal fifo_rst     :   std_logic;
signal fifo_we      :   std_logic;
signal fifo_re      :   std_logic;
signal fifo_empty   :   std_logic;
signal fifo_din     :   std_logic_vector (47 downto 0) := (others => '0');
signal fifo_dout    :   std_logic_vector (47 downto 0) := (others => '0');
signal s_valid      :   STD_LOGIC;
signal s_data_count :   STD_LOGIC_VECTOR(6 DOWNTO 0) := (others => '0');
signal diag_ctrl_state_num :   STD_LOGIC_VECTOR(2 DOWNTO 0) := (others => '0');
--signal r_diag_packet_length :   STD_LOGIC_VECTOR(20 DOWNTO 0) := (others => '0');
----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
o_diag_data <= fifo_dout;
o_diag_packet_length <= i_diag_packet_length;
--r_diag_packet_length <= i_diag_packet_length;
----------------------------------------------------------------------------------
--with state select diag_ctrl_state_num <= 
--"001" when idle,
--"010" when gen_data,
--"011" when gen_data_done,
--"100" when send_data,
--"111" when others;
--ila_diag_ins : ila_diag
--PORT MAP (
--	clk => i_clk_40,
--	probe0 => diag_ctrl_state_num,
--	probe1 => i_diag_packet_length
--);
----------------------------------------------------------------------------------
process (i_clk_40)
variable v_fifo_din     :   std_logic_vector (47 downto 0) := (others => '0');
begin
if rising_edge (i_clk_40) then
    if i_reset = '1' then
        state <= idle;
        fifo_rst <= '1';
        o_diag_done <= '0';
        fifo_we <= '0';
        fifo_re <= '0';
    else

case state is

when idle =>
    fifo_rst <= '1';    
    o_diag_done <= '0';
    fifo_we <= '0';
    fifo_re <= '0';
    v_fifo_din := (others =>'0');
    if i_diag_enable = '1' then
        state <= gen_data;
    else
        state <= idle;
    end if;
    
when gen_data =>
    fifo_re <= '0';
    fifo_we <= '1';
    fifo_rst <= '0';
    v_fifo_din := v_fifo_din + '1';
    if v_fifo_din (20 downto 0) >= i_diag_packet_length then
        state <= gen_data_done;
    else
        state <= gen_data;
    end if;

when gen_data_done =>
    fifo_we <= '0';
    o_diag_done <= '1';
    state <= send_data;

when send_data =>
    o_diag_done <= '0';
    fifo_we <= '0';
    fifo_re <= '1';
    v_fifo_din := (others =>'0'); 
    if fifo_empty = '1' then
        state <= idle;
    else
        state <= send_data;
    end if;

when others =>
    fifo_we <= '0';
    fifo_re <= '0';
    v_fifo_din := (others =>'0'); 
    state <= idle;
end case;
end if;
end if;
fifo_din <= v_fifo_din;
end process;
----------------------------------------------------------------------------------
fifo_ins : fifo
  PORT MAP (
    clk     => i_clk_40,
    srst    => fifo_rst,
    din     => fifo_din,
    wr_en   => fifo_we,
    rd_en   => i_diag_rd_en,
    dout    => fifo_dout,
    full    => open,
    empty   => fifo_empty,
    valid   => open,
    data_count   => open
  );
----------------------------------------------------------------------------------

end Behavioral;
----------------------------------------------------------------------------------