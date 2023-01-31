----------------------------------------------------------------------------------
-- Company: Yee Space
-- Engineer: jichenxu
-- 
-- Create Date: 2019/09/15 17:21:50
-- Design Name: uart_rev1
-- Module Name: uart_send - Behavioral
-- Project Name: public
-- Target Devices: Xilinx Serial-7
-- Tool Versions: Vivado 2018.1
-- Description: Uart transmitter module.
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

entity uart_send is
    generic (
           DIV_FACTOR : std_logic_vector(31 downto 0) := x"004B7F5A"; -- DIV_FACTOR = BAUD RATE / I_CLK * 2^32 ; 
           PARITY : std_logic_vector(1 downto 0) := "00"     -- PARITY = "00" -> non parity;PARITY = "01" -> odd parity;PARITY = "10" -> even parity;
           );
    Port ( i_clk : in STD_LOGIC;
           i_rst : in STD_LOGIC;
           i_valid : in STD_LOGIC;
           i_data : in STD_LOGIC_VECTOR(7 downto 0);
           o_fifo_full :out STD_LOGIC;
           o_uart_tx : out STD_LOGIC);
end uart_send;

architecture Behavioral of uart_send is

--The module aims to generate the CE signal of Uart Baud Rate with NCO.
COMPONENT uart_bit_ce_gen
Port ( i_clk : in STD_LOGIC;
       i_rst : in STD_LOGIC;
       i_val_init : in STD_LOGIC_VECTOR (31 downto 0);
       i_val_incr : in STD_LOGIC_VECTOR (31 downto 0);
       o_ce : out STD_LOGIC);
END COMPONENT;

--uart tx fifo.
COMPONENT fifo_uart_send
  PORT (
    clk : IN STD_LOGIC;
    srst : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
  );
END COMPONENT;

--Uart 发送状态机定义
type STATES is (	
	S_RST,           --RST 状态，用于接收机初始化。
	S_IDLE,          --IDLE 状态，等待FIFO有数据。
	S_READ_DATA_S1,  --READ_DATA_S1 状态，准备发送数据。
	S_READ_DATA_S2,  --READ_DATA_S2 状态，准备发送数据。
	S_SEND_DATA,     --SEND_DATA 状态，数据发送。
	S_SEND_PARITY,   --SEND_PARITY 状态，发送奇偶校验位。
	S_SEND_FINISH    --SEND_FINISH 状态，发送停止位。
);

signal states_main : STATES :=S_RST;

signal bit_ce :std_logic := '0';
signal send_data_reg :std_logic_vector(8 downto 0) := (others => '0');
signal send_data_cnt :std_logic_vector(3 downto 0) := (others => '0');
signal bit_parity :std_logic := '0';
signal fifo_uart_send_rd_en,fifo_uart_send_empty,fifo_uart_send_full :std_logic := '0';
signal fifo_uart_send_dout :std_logic_vector(7 downto 0) := (others => '0');
signal uart_tx :std_logic := '0';

begin

process(i_clk,i_rst)
begin
	if i_rst = '1' then
	   states_main <= S_RST;
	elsif rising_edge(i_clk) then
        case states_main is
            when S_RST =>
                states_main <= S_IDLE;
                uart_tx <= '1';
                bit_parity <= '0';
                fifo_uart_send_rd_en <= '0';
                
            when S_IDLE =>
                if fifo_uart_send_empty = '0' then
                    states_main <= S_READ_DATA_S1;
                    fifo_uart_send_rd_en <= '1';
                end if;
            
            when S_READ_DATA_S1 =>
                states_main <= S_READ_DATA_S2;
                fifo_uart_send_rd_en <= '0';
                
            when S_READ_DATA_S2 =>
                states_main <= S_SEND_DATA;
                fifo_uart_send_rd_en <= '0';
                send_data_reg <= fifo_uart_send_dout & '0';
                send_data_cnt <= x"8";
                bit_parity <= '0';
                       
            when S_SEND_DATA =>
                if bit_ce = '1' then
                    if send_data_cnt = x"0" then 
                        if PARITY = "01" or PARITY = "10" then      --根据PARITY参数，选择是否跳过校验状态
                            states_main <= S_SEND_PARITY;
                        else
                            states_main <= S_SEND_FINISH;
                        end if;
                    else
                        send_data_cnt <= send_data_cnt - '1';
                    end if;
                    send_data_reg <= '1' & send_data_reg(8 downto 1);    --数据发送移位寄存器
                    uart_tx <= send_data_reg(0);
                    bit_parity <= bit_parity xor send_data_reg(0);      --奇偶校验值计算
                end if;
                
            when S_SEND_PARITY =>
                if bit_ce = '1' then
                    states_main <= S_SEND_FINISH;
                    if PARITY = "01" then       --奇偶校
                        uart_tx <= bit_parity xor '1';
                    elsif PARITY = "10" then
                        uart_tx <= bit_parity;  --偶偶校
                    else
                        uart_tx <= '1';
                    end if;
                end if;
                    
            when S_SEND_FINISH =>
                if bit_ce = '1' then
                    states_main <= S_IDLE;
                    uart_tx <= '1';
                end if;
            when others =>
                states_main <= S_RST;
        end case;
	end if;
end process;

--------------------------------------------------------------------------------------------------
--baud rate generator
--------------------------------------------------------------------------------------------------
uart_bit_ce_gen_u1: uart_bit_ce_gen PORT MAP(
	i_clk => i_clk,
	i_rst => i_rst,
	i_val_init => x"00000000",
	i_val_incr => DIV_FACTOR,
	o_ce => bit_ce
);

--------------------------------------------------------------------------------------------------
--uart tx fifo
--------------------------------------------------------------------------------------------------
fifo_uart_send_u1 : fifo_uart_send
  PORT MAP (
    clk => i_clk,
    srst => i_rst,
    din => i_data,
    wr_en => i_valid,
    rd_en => fifo_uart_send_rd_en,
    dout => fifo_uart_send_dout,
    full => fifo_uart_send_full,
    empty => fifo_uart_send_empty
  );

--------------------------------------------------------------------------------------------------
--output port map
--------------------------------------------------------------------------------------------------
o_fifo_full <= fifo_uart_send_full;
o_uart_tx <= uart_tx;
--------------------------------------------------------------------------------------------------


end Behavioral;
