--#########################################
--chirp 发送模块
--#########################################


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity chirp_gen is
generic (
   FREQ_H : std_logic_vector(11 downto 0) := x"5E1";                --配置chirp 码的高侧频率
   FREQ_L : std_logic_vector(11 downto 0) := x"517";                --配置chirp 码的低侧频率
   BAUD_RATE : std_logic_vector(31 downto 0) := x"0068_DB8B";       --配置发送波特率，BAUD_RATE = 波特率/i_clk * 2^32
   FREQ_SAMPLING : std_logic_vector(31 downto 0) := x"2000_0000";   --配置DAC 采样率，FREQ_SAMPLING = 采样率/i_clk * 2^32
   TIME_DELAY : std_logic_vector(31 downto 0) := x"0000_7530"       --输出使能延迟时间，t=TIME_DELAY/fclk
);
port ( 
    i_clk : in std_logic;                                   --时钟输入
    i_rst : in std_logic;                                   --同步复位
    i_send : in std_logic;                                  --数据发送，上升沿有效，触发会后发送i_data_num数量个符号，单次发送最多不超过255个符号
    i_data : in std_logic_vector(1023 downto 0);            --数据输入，i_send上升沿锁存，单个符号为4bit，高位在前发送
    i_data_num : in std_logic_vector(7 downto 0);           --单次发送符号数
    o_tlv5619_data : out std_logic_vector(11 downto 0);     --tlv5619 模块接口
    o_tlv5619_send : out std_logic;                         --tlv5619 模块接口
    o_output_en : out std_logic                             --tlv5619 模块接口
    );
end chirp_gen;

architecture Behavioral of chirp_gen is

TYPE D32_ARRAY IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(31 DOWNTO 0); 

--通过公式计算不同码型的初始频率
constant FREQ_UNIT_REAL :real := (real(conv_integer(FREQ_H)) - real(conv_integer(FREQ_L))) * real(conv_integer(BAUD_RATE)) / real(conv_integer(FREQ_SAMPLING)) * 1048576.0;
constant FREQ_UNIT_INT :integer := integer(FREQ_UNIT_REAL);
constant FREQ_UNIT :std_logic_vector(31 downto 0) := conv_std_logic_vector(FREQ_UNIT_INT,32);
constant FREQ_H_32bit :std_logic_vector(31 downto 0) := FREQ_H & x"00000";
constant FREQ_L_32bit :std_logic_vector(31 downto 0) := FREQ_L & x"00000";
constant FREQ_H_L :std_logic_vector(31 downto 0) := FREQ_H_32bit - FREQ_L_32bit;
constant FREQ_INIT_UNIT_INT :integer := integer((real(conv_integer(FREQ_H)) - real(conv_integer(FREQ_L))) / 8.0 * 1048576.0);
constant FREQ_INIT_0 :std_logic_vector(31 downto 0) := conv_std_logic_vector(conv_integer(FREQ_L) * 1048576 + FREQ_INIT_UNIT_INT * 0,32);
constant FREQ_INIT_1 :std_logic_vector(31 downto 0) := conv_std_logic_vector(conv_integer(FREQ_L) * 1048576 + FREQ_INIT_UNIT_INT * 1,32);
constant FREQ_INIT_2 :std_logic_vector(31 downto 0) := conv_std_logic_vector(conv_integer(FREQ_L) * 1048576 + FREQ_INIT_UNIT_INT * 2,32);
constant FREQ_INIT_3 :std_logic_vector(31 downto 0) := conv_std_logic_vector(conv_integer(FREQ_L) * 1048576 + FREQ_INIT_UNIT_INT * 3,32);
constant FREQ_INIT_4 :std_logic_vector(31 downto 0) := conv_std_logic_vector(conv_integer(FREQ_L) * 1048576 + FREQ_INIT_UNIT_INT * 4,32);
constant FREQ_INIT_5 :std_logic_vector(31 downto 0) := conv_std_logic_vector(conv_integer(FREQ_L) * 1048576 + FREQ_INIT_UNIT_INT * 5,32);
constant FREQ_INIT_6 :std_logic_vector(31 downto 0) := conv_std_logic_vector(conv_integer(FREQ_L) * 1048576 + FREQ_INIT_UNIT_INT * 6,32);
constant FREQ_INIT_7 :std_logic_vector(31 downto 0) := conv_std_logic_vector(conv_integer(FREQ_L) * 1048576 + FREQ_INIT_UNIT_INT * 7,32);
constant FREQ_INIT_8 :std_logic_vector(31 downto 0) := conv_std_logic_vector(conv_integer(FREQ_L) * 1048576 + FREQ_INIT_UNIT_INT * 8,32);

component chirp_gen_nco
port ( 
    i_clk : in std_logic;                               --时钟输入
    i_clear : in std_logic;                             --计数器复位，高有效，触发后计数器值更新为i_val_init值
    i_val_init : in std_logic_vector(31 downto 0);      --计数器初始值
    i_val_incr : in std_logic_vector(31 downto 0);      --NCO 累加量，即频率控制字，计算公式为：i_val_incr = Fout/i_clk * 2^32
    o_ce : out std_logic                                --NCO 输出，脉冲宽度为单个i_clk周期，频率为Fout
);
end component;


--状态机
type STATES is (	
	S_RST,          --复位状态
	S_IDLE,         --空闲状态
	S_DELAY,         --延迟时间
	S_SEND_JUGE,    --数据映射，将输入数据映射为不同的码型
	S_SEND_UP,      --发送 up chirp
	S_SEND_DOWN,    --发送 down chirp
    S_SEND_CONSTANT --发送 固定频率
);

signal states_main : STATES := S_RST;
signal tp_states_main :std_logic_vector(7 downto 0) := (others => '0');

signal send_reg :std_logic :=  '0';
signal send_r :std_logic :=  '0';

signal dac_sampling_nco_clear :std_logic := '0';
signal dac_ce :std_logic := '0';
signal baud_rate_nco_clear :std_logic := '0';
signal baud_rate_ce :std_logic := '0';

signal r_o_tlv5619_data :std_logic_vector(31 downto 0) := (others => '0');
signal r_o_output_en :std_logic :=  '0';


signal freq_init :D32_ARRAY(15 downto 0) := (others => (others => '0'));


signal data_shift_reg :std_logic_vector(1023 downto 0) := (others => '0');

signal send_data_cnt :std_logic_vector(7 downto 0) := (others => '0');
signal cnt_delay :std_logic_vector(31 downto 0) := (others => '0');


begin

--将不同码型的初始频率映射到数组
freq_init(0) <= FREQ_INIT_0;
freq_init(1) <= FREQ_INIT_1;
freq_init(2) <= FREQ_INIT_2;
freq_init(3) <= FREQ_INIT_3;
freq_init(4) <= FREQ_INIT_4;
freq_init(5) <= FREQ_INIT_5;
freq_init(6) <= FREQ_INIT_6;
freq_init(7) <= FREQ_INIT_7;

freq_init(8) <= FREQ_INIT_8;
freq_init(9) <= FREQ_INIT_6;
freq_init(10) <= FREQ_INIT_4;
freq_init(11) <= FREQ_INIT_2;

freq_init(12) <= FREQ_INIT_0;
freq_init(13) <= FREQ_INIT_4;
freq_init(14) <= FREQ_INIT_8;
freq_init(15) <= x"0000_0000";


process(i_clk)
begin
    if rising_edge(i_clk) then
        if i_rst = '1' then
            states_main <= S_RST;
        else
            case states_main is
                when S_RST =>	tp_states_main <= x"00";
                    states_main <= S_IDLE;
                    r_o_tlv5619_data <= (others => '0');
                    cnt_delay <= (others => '0');
                    send_data_cnt <= (others => '0');
                    dac_sampling_nco_clear <= '1';
                    baud_rate_nco_clear <= '1';
                    r_o_output_en <= '0';
                    
                when S_IDLE =>	tp_states_main <= x"01";
                    r_o_tlv5619_data <= (others => '0');
                    dac_sampling_nco_clear <= '0';
                    baud_rate_nco_clear <= '1';
                    r_o_output_en <= '0';
                    if send_r = '1' then
                        data_shift_reg <= i_data;
                        send_data_cnt <= i_data_num;
                        states_main <= S_DELAY;
                        cnt_delay <= TIME_DELAY;
                    end if;
                
                when S_DELAY =>	tp_states_main <= x"06";
                    r_o_output_en <= '1';
                    if cnt_delay = x"0000_0000" then
                        states_main <= S_SEND_JUGE;
                    else
                        cnt_delay <= cnt_delay - '1';
                    end if;

                when S_SEND_JUGE =>	tp_states_main <= x"02";
                    baud_rate_nco_clear <= '0';
                    if send_data_cnt = x"00" then
                        states_main <= S_IDLE;
                    else
                        send_data_cnt <= send_data_cnt - '1';
                        data_shift_reg <= data_shift_reg(1019 downto 0) & x"0";
                        r_o_tlv5619_data <= freq_init(conv_integer(data_shift_reg(1023 downto 1020)));
                        dac_sampling_nco_clear <= '0';
                        if data_shift_reg(1023 downto 1020) <= x"7" then
                            states_main <= S_SEND_UP;
                        elsif data_shift_reg(1023 downto 1020) <= x"B" then
                            states_main <= S_SEND_DOWN;
                        else
                            states_main <= S_SEND_CONSTANT;
                        end if;
                    end if;
                
                when S_SEND_UP =>	tp_states_main <= x"03";
                    if baud_rate_ce = '1' then
                        states_main <= S_SEND_JUGE;
                        dac_sampling_nco_clear <= '1';
                    else
                        if dac_ce = '1' then
                            if r_o_tlv5619_data + FREQ_UNIT > FREQ_H & x"00000" then
                                r_o_tlv5619_data <= r_o_tlv5619_data + FREQ_UNIT - FREQ_H_L;
                            else
                                r_o_tlv5619_data <= r_o_tlv5619_data + FREQ_UNIT;
                            end if;
                        end if;
                    end if;
                    
                when S_SEND_DOWN =>	tp_states_main <= x"04";
                    if baud_rate_ce = '1' then
                        states_main <= S_SEND_JUGE;
                        dac_sampling_nco_clear <= '1';
                    else
                        if dac_ce = '1' then
                            if r_o_tlv5619_data - FREQ_UNIT < FREQ_L & x"00000" then
                                r_o_tlv5619_data <= r_o_tlv5619_data - FREQ_UNIT + FREQ_H_L;
                            else
                                r_o_tlv5619_data <= r_o_tlv5619_data - FREQ_UNIT;
                            end if;
                        end if;
                    end if;
                    
                when S_SEND_CONSTANT =>	tp_states_main <= x"05";
                    if baud_rate_ce = '1' then
                        states_main <= S_SEND_JUGE;
                        dac_sampling_nco_clear <= '1';
                    end if; 
                    
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


dac_sampling_nco_u1 : chirp_gen_nco
port map (
    i_clk => i_clk,
    i_clear => dac_sampling_nco_clear,
    i_val_init => x"0000_0000",
    i_val_incr => FREQ_SAMPLING,
    o_ce => dac_ce
    );

baud_rate_nco_u1 : chirp_gen_nco
port map (
    i_clk => i_clk,
    i_clear => baud_rate_nco_clear,
    i_val_init => x"0000_0000",
    i_val_incr => BAUD_RATE,
    o_ce => baud_rate_ce
    );

o_tlv5619_send <= dac_ce;
o_tlv5619_data <= r_o_tlv5619_data(31 downto 20);
o_output_en <= r_o_output_en;


end Behavioral;

