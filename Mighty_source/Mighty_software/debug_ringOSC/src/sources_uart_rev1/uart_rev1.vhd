----------------------------------------------------------------------------------
-- Company: Yee Space
-- Engineer: jichenxu
-- 
-- Create Date: 2019/09/15 19:27:35
-- Design Name: uart_rev1
-- Module Name: uart_rev1 - Behavioral
-- Project Name: public
-- Target Devices: Xilinx Serial-7
-- Tool Versions: Vivado 2018.1
-- Description: Uart transceiver module.
--              Providing the setting of Baud Rate;
--              Providing the choice of parity modes: noun,odd,even.
--              Integrating transmitter fifo.
----------------------------------------------------------------------------------
--Modify History: 
----Modify time:
----Modifier:
----Description:
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart_rev1 is
    generic (
            DIV_FACTOR : std_logic_vector(31 downto 0) := x"004B7F5A"; -- DIV_FACTOR = BAUD RATE / I_CLK * 2^32 ; 
            PARITY : std_logic_vector(1 downto 0) := "00"     -- PARITY = "00" -> non parity;PARITY = "01" -> odd parity;PARITY = "10" -> even parity;
            );
    Port ( i_clk : in STD_LOGIC;
           i_rst : in STD_LOGIC;
           i_tx_valid : in STD_LOGIC;
           i_tx_data : in STD_LOGIC_VECTOR (7 downto 0);
           o_tx_fifo_full : out STD_LOGIC;
           o_rx_valid : out STD_LOGIC;
           o_rx_data : out STD_LOGIC_VECTOR (7 downto 0);
           o_uart_tx : out STD_LOGIC;
           i_uart_rx : in STD_LOGIC);
end uart_rev1;

architecture Behavioral of uart_rev1 is

COMPONENT uart_send
generic (
        DIV_FACTOR : std_logic_vector(31 downto 0) := DIV_FACTOR; -- DIV_FACTOR = BAUD RATE / I_CLK * 2^32 ; 
        PARITY : std_logic_vector(1 downto 0) := PARITY     -- PARITY = "00" -> non parity;PARITY = "01" -> odd parity;PARITY = "10" -> even parity;
        );
Port ( i_clk : in STD_LOGIC;
       i_rst : in STD_LOGIC;
       i_valid : in STD_LOGIC;
       i_data : in STD_LOGIC_VECTOR(7 downto 0);
       o_fifo_full :out STD_LOGIC;
       o_uart_tx : out STD_LOGIC);
END COMPONENT;

COMPONENT uart_recv
generic (
        DIV_FACTOR : std_logic_vector(31 downto 0) := DIV_FACTOR; -- DIV_FACTOR = BAUD RATE / I_CLK * 2^32 ; 
        PARITY : std_logic_vector(1 downto 0) := PARITY     -- PARITY = "00" -> non parity;PARITY = "01" -> odd parity;PARITY = "10" -> even parity;
        );
Port ( i_clk : in STD_LOGIC;
       i_rst : in STD_LOGIC;
       i_uart_rx : in STD_LOGIC;
       o_valid : out STD_LOGIC;
       o_data : out STD_LOGIC_VECTOR (7 downto 0));
END COMPONENT;

begin

uart_send_u1: uart_send PORT MAP(
	i_clk => i_clk,
	i_rst => i_rst,
	i_valid => i_tx_valid,
	i_data => i_tx_data,
	o_fifo_full => o_tx_fifo_full,
	o_uart_tx => o_uart_tx
);

uart_recv_u1: uart_recv PORT MAP(
	i_clk => i_clk,
	i_rst => i_rst,
	i_uart_rx => i_uart_rx,
	o_valid => o_rx_valid,
	o_data => o_rx_data
);


end Behavioral;
