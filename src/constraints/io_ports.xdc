set_property PACKAGE_PIN C11	[get_ports clk_in1_n]
set_property PACKAGE_PIN C12	[get_ports clk_in1_p]
set_property IOSTANDARD LVDS_25 [get_ports clk_in1_p]
set_property IOSTANDARD LVDS_25 [get_ports clk_in1_n]

set_property PACKAGE_PIN C14	[get_ports adc_scl]
set_property PACKAGE_PIN C13	[get_ports adc_sda]

set_property IOSTANDARD LVCMOS33 [get_ports adc_scl]
set_property IOSTANDARD LVCMOS33 [get_ports adc_sda]

set_property IOSTANDARD LVCMOS33 [get_ports adc_conv]
set_property PACKAGE_PIN B12	[get_ports adc_conv]

set_property PACKAGE_PIN B14	[get_ports adg_mux_out[0]]
set_property PACKAGE_PIN A14	[get_ports adg_mux_out[1]]
set_property PACKAGE_PIN B10	[get_ports adg_mux_out[2]]
set_property PACKAGE_PIN A10	[get_ports adg_mux_out[3]]	

set_property IOSTANDARD LVCMOS33    [get_ports adg_mux_out[0]]
set_property IOSTANDARD LVCMOS33	[get_ports adg_mux_out[1]]
set_property IOSTANDARD LVCMOS33	[get_ports adg_mux_out[2]]
set_property IOSTANDARD LVCMOS33	[get_ports adg_mux_out[3]]	

set_property PACKAGE_PIN AF14	[get_ports o_cb_fpb_s_d_out] 
set_property IOSTANDARD LVCMOS18 [get_ports o_cb_fpb_s_d_out]

set_property PACKAGE_PIN AA14	[get_ports o_lb_fpb_s_d_out] 
set_property IOSTANDARD LVCMOS18 [get_ports o_lb_fpb_s_d_out]

set_property PACKAGE_PIN AD15	[get_ports i_cb_fpb_s_d_in] 
set_property IOSTANDARD LVCMOS18 [get_ports i_cb_fpb_s_d_in]

set_property PACKAGE_PIN AE18	[get_ports i_lb_fpb_s_d_in] 
set_property IOSTANDARD LVCMOS18 [get_ports i_lb_fpb_s_d_in]

#  clk_40_out                : out    std_logic; 
#  clk_40_in                 : in     std_logic; 

#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_40_out_OBUF]
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_40_in_IBUF]

#set_property PACKAGE_PIN AF15	[get_ports clk_40_out] 
#set_property IOSTANDARD LVCMOS18 [get_ports clk_40_out]

#set_property PACKAGE_PIN AF18	[get_ports clk_40_in] 
#set_property IOSTANDARD LVCMOS18 [get_ports clk_40_in]
  
  