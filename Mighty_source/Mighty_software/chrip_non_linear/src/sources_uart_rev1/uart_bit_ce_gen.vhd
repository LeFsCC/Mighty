----------------------------------------------------------------------------------
-- Company: Yee Space
-- Engineer: jichenxu
-- 
-- Create Date: 2019/09/15 16:56:13
-- Design Name: uart_rev1
-- Module Name: uart_bit_ce_gen - Behavioral
-- Project Name: public
-- Target Devices: Xilinx Serial-7
-- Tool Versions: Vivado 2018.1
-- Description: The module aims to generate the CE signal of Uart Baud Rate with NCO.
----------------------------------------------------------------------------------
--Modify History: 
----Modify time:
----Modifier:
----Description:
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart_bit_ce_gen is
    Port ( i_clk : in STD_LOGIC;
           i_rst : in STD_LOGIC;
           i_val_init : in STD_LOGIC_VECTOR (31 downto 0);  --set the initial value of counter
           i_val_incr : in STD_LOGIC_VECTOR (31 downto 0);  --set the acc parameter of NCO;  i_val_incr = o_ce(frequency) / i_clk * 2^32 ; 
           o_ce : out STD_LOGIC);   --output CE signal
end uart_bit_ce_gen;

architecture Behavioral of uart_bit_ce_gen is

signal nco_acc :std_logic_vector(31 downto 0) :=(others => '0');    --acc of NCO
signal nco_acc_31_reg :std_logic := '0';
signal ce :std_logic := '0';

begin

--------------------------------------------------------------------------------------------------
--NCO algorithm
--------------------------------------------------------------------------------------------------
process(i_clk,i_rst)
begin
    if i_rst = '1' then
        nco_acc <= i_val_init;  --acc initialization
    elsif rising_edge(i_clk) then
        nco_acc <= nco_acc + i_val_incr;
        nco_acc_31_reg <= nco_acc(31);  
    end if;
end process;

ce <= nco_acc(31) and (not nco_acc_31_reg);    --generate the rising edge of nco_acc(31)
--------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------
--output port map
--------------------------------------------------------------------------------------------------
o_ce <= ce;
--------------------------------------------------------------------------------------------------


end Behavioral;
