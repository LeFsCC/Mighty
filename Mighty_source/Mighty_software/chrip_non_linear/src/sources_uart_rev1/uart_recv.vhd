----------------------------------------------------------------------------------
-- Company: Yee Space
-- Engineer: jichenxu
-- 
-- Create Date: 2019/09/15 19:27:35
-- Design Name: uart_rev1
-- Module Name: uart_recv - Behavioral
-- Project Name: public
-- Target Devices: Xilinx Serial-7
-- Tool Versions: Vivado 2018.1
-- Description: Uart receiver module.
--              Providing the setting of Baud Rate;
--              Providing the choice of parity modes: noun,odd,even.
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

entity uart_recv is
    generic (
            DIV_FACTOR : std_logic_vector(31 downto 0) := x"004B7F5A"; -- DIV_FACTOR = BAUD RATE / i_clk * 2^32 ; 
            PARITY : std_logic_vector(1 downto 0) := "01"     -- PARITY = "00" -> non parity;PARITY = "01" -> odd parity;PARITY = "10" -> even parity;
            );
    Port ( i_clk : in STD_LOGIC;
           i_rst : in STD_LOGIC;
           i_uart_rx : in STD_LOGIC;
           o_valid : out STD_LOGIC;
           o_data : out STD_LOGIC_VECTOR (7 downto 0));
end uart_recv;

architecture Behavioral of uart_recv is

--The module aims to generate the CE signal of Uart Baud Rate with NCO.
COMPONENT uart_bit_ce_gen
Port ( i_clk : in STD_LOGIC;
       i_rst : in STD_LOGIC;
       i_val_init : in STD_LOGIC_VECTOR (31 downto 0);
       i_val_incr : in STD_LOGIC_VECTOR (31 downto 0);
       o_ce : out STD_LOGIC);
END COMPONENT;

--Uart 接收状态机定义
type STATES is (	
	S_RST,               --RST 状态，用于接收机初始化。
	S_IDLE,              --IDLE 状态，等待Uart rx 收到起始位。
	S_RECV_DATA_START,   --RECV_DATA_START 状态，接收串口起始位，确认开始接收。
	S_RECV_DATA,         --RECV_DATA 状态，串口数据接收。
	S_RECV_PARITY,       --RECV_PARITY 状态，接收串口检验位，并确认校验是否通过。
	S_RECV_FINISH        --RECV_FINISH 状态，接收停止位，完成数据接收。
);

signal states_main : STATES :=S_RST;      --the signal of receiver state machine

signal reg_uart_rx :std_logic_vector(2 downto 0) := (others => '0');
signal uart_rx_d :std_logic := '0';

signal uart_bit_ce_rst,bit_ce :std_logic := '0';
signal recv_data_reg :std_logic_vector(7 downto 0) := (others => '0');
signal recv_data_cnt :std_logic_vector(3 downto 0) := (others => '0');
signal bit_parity :std_logic := '0';
signal recv_data_valid :std_logic := '0';
signal recv_data :std_logic_vector(7 downto 0) := (others => '0');

begin

--------------------------------------------------------------------------------------------------
--串口接收状态机
--------------------------------------------------------------------------------------------------
process(i_clk,i_rst)
begin
	if i_rst = '1' then
	   states_main <= S_RST;
	elsif rising_edge(i_clk) then
        case states_main is
            when S_RST =>
                states_main <= S_IDLE;
                recv_data_reg <= x"00";
                recv_data_cnt <= x"0";
                
            when S_IDLE =>
                if uart_rx_d = '0' then
                    states_main <= S_RECV_DATA_START;
                    uart_bit_ce_rst <= '0';     --重置波特率CE生成器，调整接收采样点为数据变化的中心。
                else
                    uart_bit_ce_rst <= '1';
                end if; 
                recv_data_valid <= '0';
                
            when S_RECV_DATA_START =>
                if bit_ce = '1' then        --bit_ce（波特率时钟使能） = ‘1’ 时采样。
                    if uart_rx_d = '0' then
                        recv_data_reg <= x"00";
                        recv_data_cnt <= x"7";      --数据接收计数器赋值
                        bit_parity <= '0'; 
                        states_main <= S_RECV_DATA;
                    else
                        states_main <= S_IDLE;
                    end if;
                end if;
                
            when S_RECV_DATA =>
                if bit_ce = '1' then
                    if recv_data_cnt = x"0" then
                        if PARITY = "01" or PARITY = "10" then  --根据PARITY参数，选择是否跳过校验状态
                            states_main <= S_RECV_PARITY;
                        else
                            states_main <= S_RECV_FINISH;
                        end if;
                    else
                        recv_data_cnt <= recv_data_cnt - '1';
                    end if;
                    recv_data_reg <= uart_rx_d & recv_data_reg(7 downto 1);     --数据接收移位寄存器
                    bit_parity <= bit_parity xor uart_rx_d;     --奇偶校验值计算
                end if;
                
            when S_RECV_PARITY =>
                if bit_ce = '1' then
                    if PARITY = "01" then       --奇偶校
                        if bit_parity = (not uart_rx_d) then
                            states_main <= S_RECV_FINISH;
                        else
                            states_main <= S_IDLE;    --校验未通过，停止接收。
                        end if;
                    elsif PARITY = "10" then    --偶偶校
                        if bit_parity = uart_rx_d then
                            states_main <= S_RECV_FINISH;
                        else
                            states_main <= S_IDLE;    --校验未通过，停止接收。
                        end if;
                    else
                        states_main <= S_RECV_FINISH;
                    end if;
                end if;
                
            when S_RECV_FINISH =>
                if bit_ce = '1' then
                    recv_data <= recv_data_reg;   --接收完成，输出数据。
                    recv_data_valid <= '1';     --置位数据输出有效。
                    states_main <= S_IDLE;
                end if;
                
            when others =>
                states_main <= S_RST;
        end case;
	end if;
end process;


--------------------------------------------------------------------------------------------------
--输入信号锁存
--------------------------------------------------------------------------------------------------
process(i_clk)
begin
    if rising_edge(i_clk) then
        reg_uart_rx <= reg_uart_rx((reg_uart_rx'left - 1) downto 0) & i_uart_rx;
        uart_rx_d <= reg_uart_rx(reg_uart_rx'left);
    end if;
end process;


--------------------------------------------------------------------------------------------------
--波特率时钟有效生成
--------------------------------------------------------------------------------------------------
uart_bit_ce_gen_u1: uart_bit_ce_gen PORT MAP(
	i_clk => i_clk,
	i_rst => uart_bit_ce_rst,
	i_val_init => x"00000000",
	i_val_incr => DIV_FACTOR,
	o_ce => bit_ce
);

--------------------------------------------------------------------------------------------------
--output port map
--------------------------------------------------------------------------------------------------
o_valid <= recv_data_valid;
o_data <= recv_data;
--------------------------------------------------------------------------------------------------



end Behavioral;
