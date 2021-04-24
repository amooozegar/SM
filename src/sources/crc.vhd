
-------------------------------------------------------------------------------
-- Copyright (C) 2009 OutputLogic.com
-- This source file may be used and distributed without restriction
-- provided that this copyright statement is not removed from the file
-- and that any derivative work contains the original copyright notice
-- and the associated disclaimer.
--
-- THIS SOURCE FILE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS
-- OR IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
-- WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
-------------------------------------------------------------------------------
-- CRC module for data(79:0)
--   lfsr(7:0)=1+x^4+x^5+x^8;
-------------------------------------------------------------------------------
--https://fa.wikipedia.org/wiki/%DA%A9%D8%AF_%D8%A7%D9%81%D8%B2%D9%88%D9%86%DA%AF%DB%8C_%DA%86%D8%B1%D8%AE%D8%B4%DB%8C
--https://en.wikipedia.org/wiki/Cyclic_redundancy_check
-- in link above shows us how to select the polynomial
--http://outputlogic.com/?page_id=321
-- in link above is a tool for generating crc vhdl code
-------------------------------------------------------------------------------
-- https://stackoverflow.com/questions/30887584/crc-generatorsender-and-checkerreceiver-parallel-implementation-vhdl
--There are 2 solutions:

--1. Solution:
--You can compute the CRC over all your input data and append zeros at the end where the CRC will be inserted. The receiver calculates the CRC with the same algorithmn over all data (payload + crc). The CRC is zero if all data is correct.

--2. Solution:
--You compute the CRC over all data words and append it directly after the datastream. The receiver uses the same technique and compares his CRC with the transmitted one. If they are equal, all data was transmitted correctly. (See David's comment).

--Both solutions can use a seed value (CRC start value). It must be equal on both sides.

--The second solution is faster and needs less buffers.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
-------------------------------------------------------------------------------
entity crc is
  port ( data_in : in std_logic_vector (79 downto 0);
    crc_out : out std_logic_vector (7 downto 0));
end crc;
-------------------------------------------------------------------------------
architecture imp_crc of crc is
  signal lfsr_c: std_logic_vector (7 downto 0);
begin
    crc_out <= lfsr_c;

    lfsr_c(0) <=  data_in(0) xor data_in(3) xor data_in(4) xor data_in(6) xor data_in(9) xor data_in(10) xor data_in(11) xor data_in(14) xor data_in(15) xor data_in(18) xor data_in(21) xor data_in(23) xor data_in(24) xor data_in(25) xor data_in(31) xor data_in(32) xor data_in(33) xor data_in(34) xor data_in(38) xor data_in(39) xor data_in(40) xor data_in(42) xor data_in(44) xor data_in(45) xor data_in(48) xor data_in(49) xor data_in(50) xor data_in(51) xor data_in(52) xor data_in(53) xor data_in(56) xor data_in(58) xor data_in(62) xor data_in(64) xor data_in(65) xor data_in(67) xor data_in(69) xor data_in(71) xor data_in(74) xor data_in(78) xor data_in(79);
    lfsr_c(1) <=  data_in(1) xor data_in(4) xor data_in(5) xor data_in(7) xor data_in(10) xor data_in(11) xor data_in(12) xor data_in(15) xor data_in(16) xor data_in(19) xor data_in(22) xor data_in(24) xor data_in(25) xor data_in(26) xor data_in(32) xor data_in(33) xor data_in(34) xor data_in(35) xor data_in(39) xor data_in(40) xor data_in(41) xor data_in(43) xor data_in(45) xor data_in(46) xor data_in(49) xor data_in(50) xor data_in(51) xor data_in(52) xor data_in(53) xor data_in(54) xor data_in(57) xor data_in(59) xor data_in(63) xor data_in(65) xor data_in(66) xor data_in(68) xor data_in(70) xor data_in(72) xor data_in(75) xor data_in(79);
    lfsr_c(2) <=  data_in(2) xor data_in(5) xor data_in(6) xor data_in(8) xor data_in(11) xor data_in(12) xor data_in(13) xor data_in(16) xor data_in(17) xor data_in(20) xor data_in(23) xor data_in(25) xor data_in(26) xor data_in(27) xor data_in(33) xor data_in(34) xor data_in(35) xor data_in(36) xor data_in(40) xor data_in(41) xor data_in(42) xor data_in(44) xor data_in(46) xor data_in(47) xor data_in(50) xor data_in(51) xor data_in(52) xor data_in(53) xor data_in(54) xor data_in(55) xor data_in(58) xor data_in(60) xor data_in(64) xor data_in(66) xor data_in(67) xor data_in(69) xor data_in(71) xor data_in(73) xor data_in(76);
    lfsr_c(3) <=  data_in(3) xor data_in(6) xor data_in(7) xor data_in(9) xor data_in(12) xor data_in(13) xor data_in(14) xor data_in(17) xor data_in(18) xor data_in(21) xor data_in(24) xor data_in(26) xor data_in(27) xor data_in(28) xor data_in(34) xor data_in(35) xor data_in(36) xor data_in(37) xor data_in(41) xor data_in(42) xor data_in(43) xor data_in(45) xor data_in(47) xor data_in(48) xor data_in(51) xor data_in(52) xor data_in(53) xor data_in(54) xor data_in(55) xor data_in(56) xor data_in(59) xor data_in(61) xor data_in(65) xor data_in(67) xor data_in(68) xor data_in(70) xor data_in(72) xor data_in(74) xor data_in(77);
    lfsr_c(4) <=  data_in(0) xor data_in(3) xor data_in(6) xor data_in(7) xor data_in(8) xor data_in(9) xor data_in(11) xor data_in(13) xor data_in(19) xor data_in(21) xor data_in(22) xor data_in(23) xor data_in(24) xor data_in(27) xor data_in(28) xor data_in(29) xor data_in(31) xor data_in(32) xor data_in(33) xor data_in(34) xor data_in(35) xor data_in(36) xor data_in(37) xor data_in(39) xor data_in(40) xor data_in(43) xor data_in(45) xor data_in(46) xor data_in(50) xor data_in(51) xor data_in(54) xor data_in(55) xor data_in(57) xor data_in(58) xor data_in(60) xor data_in(64) xor data_in(65) xor data_in(66) xor data_in(67) xor data_in(68) xor data_in(73) xor data_in(74) xor data_in(75) xor data_in(79);
    lfsr_c(5) <=  data_in(0) xor data_in(1) xor data_in(3) xor data_in(6) xor data_in(7) xor data_in(8) xor data_in(11) xor data_in(12) xor data_in(15) xor data_in(18) xor data_in(20) xor data_in(21) xor data_in(22) xor data_in(28) xor data_in(29) xor data_in(30) xor data_in(31) xor data_in(35) xor data_in(36) xor data_in(37) xor data_in(39) xor data_in(41) xor data_in(42) xor data_in(45) xor data_in(46) xor data_in(47) xor data_in(48) xor data_in(49) xor data_in(50) xor data_in(53) xor data_in(55) xor data_in(59) xor data_in(61) xor data_in(62) xor data_in(64) xor data_in(66) xor data_in(68) xor data_in(71) xor data_in(75) xor data_in(76) xor data_in(78) xor data_in(79);
    lfsr_c(6) <=  data_in(1) xor data_in(2) xor data_in(4) xor data_in(7) xor data_in(8) xor data_in(9) xor data_in(12) xor data_in(13) xor data_in(16) xor data_in(19) xor data_in(21) xor data_in(22) xor data_in(23) xor data_in(29) xor data_in(30) xor data_in(31) xor data_in(32) xor data_in(36) xor data_in(37) xor data_in(38) xor data_in(40) xor data_in(42) xor data_in(43) xor data_in(46) xor data_in(47) xor data_in(48) xor data_in(49) xor data_in(50) xor data_in(51) xor data_in(54) xor data_in(56) xor data_in(60) xor data_in(62) xor data_in(63) xor data_in(65) xor data_in(67) xor data_in(69) xor data_in(72) xor data_in(76) xor data_in(77) xor data_in(79);
    lfsr_c(7) <=  data_in(2) xor data_in(3) xor data_in(5) xor data_in(8) xor data_in(9) xor data_in(10) xor data_in(13) xor data_in(14) xor data_in(17) xor data_in(20) xor data_in(22) xor data_in(23) xor data_in(24) xor data_in(30) xor data_in(31) xor data_in(32) xor data_in(33) xor data_in(37) xor data_in(38) xor data_in(39) xor data_in(41) xor data_in(43) xor data_in(44) xor data_in(47) xor data_in(48) xor data_in(49) xor data_in(50) xor data_in(51) xor data_in(52) xor data_in(55) xor data_in(57) xor data_in(61) xor data_in(63) xor data_in(64) xor data_in(66) xor data_in(68) xor data_in(70) xor data_in(73) xor data_in(77) xor data_in(78);

end architecture imp_crc;
-------------------------------------------------------------------------------