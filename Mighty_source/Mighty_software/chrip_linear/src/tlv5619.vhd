--#########################################
--DAC TLV5619 驱动模块
--#########################################


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;



entity tlv5619 is
port (
    i_clk : in std_logic;                               --工作时钟输入
    i_rst : in std_logic;                               --同步复位
    i_send : in std_logic;                              --数据刷新，上升沿有效，上升沿将数据锁存并发送至DAC芯片    
    i_data: in std_logic_vector(11 downto 0);           --数据输入，i_send上升沿时刻锁存
    o_dac_data : out std_logic_vector(11 downto 0);     --tlv5619接口
    o_csn : out std_logic;                              --tlv5619接口
    o_wen : out std_logic;                              --tlv5619接口
    o_ldacn : out std_logic;                            --tlv5619接口
    o_pdn : out std_logic                               --tlv5619接口
 );
end tlv5619;

architecture Behavioral of tlv5619 is

type STATES is (	
	S_RST,
	S_IDLE,
	S_SEND_DAT_S0
);

signal states_main : STATES := S_RST;
signal tp_states_main :std_logic_vector(7 downto 0) := (others => '0');

signal send_reg :std_logic :=  '0';
signal send_r :std_logic :=  '0';

signal r_o_dac_data :std_logic_vector(11 downto 0) := (others => '0');
signal r_o_wen :std_logic :=  '0';

begin

process(i_clk)
begin
    if rising_edge(i_clk) then
        if i_rst = '1' then
            states_main <= S_RST;
        else
            case states_main is
                when S_RST =>	tp_states_main <= x"00";
                    states_main <= S_IDLE;
                    r_o_dac_data <= (others => '0');
                    r_o_wen <= '0';
                    
                when S_IDLE =>	tp_states_main <= x"01";
                    r_o_wen <= '0';
                    if send_r = '1' then
                        r_o_dac_data <= i_data;
                        states_main <= S_SEND_DAT_S0;
                    end if;
                
                when S_SEND_DAT_S0 =>	tp_states_main <= x"02";
                    states_main <= S_IDLE;
                    r_o_wen <= '1';
					
                when others =>	tp_states_main <= x"FF";
                    states_main <= S_RST;
            end case;
        end if;
    end if;
end process;


process(i_clk)
begin
    if rising_edge(i_clk) then
        send_reg <= i_send;
    end if;
end process;
send_r <= i_send and (not send_reg);

o_dac_data <= r_o_dac_data;
o_wen <= r_o_wen;
o_csn <= '0';
o_ldacn <= '0';
o_pdn <= '1';


end Behavioral;
