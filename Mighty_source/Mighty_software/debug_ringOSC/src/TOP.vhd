    
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity top is
port (
    o_led : out std_logic;
    o_dac_data : out std_logic_vector(11 downto 0);
    o_csn : out std_logic;
    o_wen : out std_logic;
    o_ldacn : out std_logic;
    o_pdn : out std_logic;
    o_clk : out std_logic;
    o_output_en : out std_logic
 );
end top;

architecture Behavioral of top is


component Gowin_OSC
port (
    oscout: out std_logic
);
end component;

component tlv5619
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
end component;

component chirp_gen
generic (
   FREQ_H : std_logic_vector(11 downto 0) := x"75F";                --配置chirp 码的高侧频率，x"5E1"为5.5MHz
   FREQ_L : std_logic_vector(11 downto 0) := x"6F5";                --配置chirp 码的低侧频率，x"517"为4.5MHz
   BAUD_RATE : std_logic_vector(31 downto 0) := x"0068_DB8B";       --配置发送波特率，BAUD_RATE = 波特率/i_clk * 2^32
   FREQ_SAMPLING : std_logic_vector(31 downto 0) := x"2000_0000"    --配置DAC 采样率，FREQ_SAMPLING = 采样率/i_clk * 2^32
);
port ( 
    i_clk : in std_logic;                                   --时钟输入
    i_rst : in std_logic;                                   --同步复位
    i_send : in std_logic;                                  --数据发送，上升沿有效，触发会后发送i_data_num数量个符号，单次发送最多不超过255个符号
    i_data : in std_logic_vector(1023 downto 0);            --数据输入，i_send上升沿锁存，单个符号为4bit，高位在前发送
    i_data_num : in std_logic_vector(7 downto 0);           --单次发送符号数
    o_tlv5619_data : out std_logic_vector(11 downto 0);     --tlv5619 模块接口
    o_tlv5619_send : out std_logic                          --tlv5619 模块接口
    );
end component;

signal clk_in :std_logic :=  '0';
signal r_o_led :std_logic :=  '0';
signal ce :std_logic :=  '0';

signal tlv5619_send :std_logic :=  '0';
signal tlv5619_data :std_logic_vector(11 downto 0) :=  (others => '0');

signal chirp_send :std_logic :=  '0';
signal chirp_data :std_logic_vector(1023 downto 0) :=  (others => '0');


begin

--内部振荡器
Gowin_OSC_u1: Gowin_OSC
port map (
    oscout => clk_in  --5Mhz时钟
    );

--LED闪烁
process(clk_in)
    variable v_cnt :integer range 0 to 1000000 := 0;
begin
    if rising_edge(clk_in) then
        if v_cnt = 1000 then
            v_cnt := 0;
            r_o_led <= not r_o_led;
        else
            v_cnt := v_cnt + 1;
        end if;
    end if;
end process;



tlv5619_u1 : tlv5619
port map (
   i_clk => clk_in,
   i_rst => '0',
   i_send => tlv5619_send,
   i_data => tlv5619_data,
   o_dac_data => o_dac_data,
   o_csn => o_csn,
   o_wen => o_wen,
   o_ldacn => o_ldacn,
   o_pdn => o_pdn
);


chirp_gen_u1 : chirp_gen
port map (
   i_clk => clk_in,
   i_rst => '0',
   i_send => chirp_send,
   i_data => chirp_data,
   i_data_num => x"64",         --100bit
   o_tlv5619_data => open,
   o_tlv5619_send => tlv5619_send
);




--数据
chirp_data(1023 downto 768) <= x"8888_8888_1010_2020_3030_4040_5050_6060_7070_8080_0808_0808_0808_0808_0808_0808";
chirp_data(767 downto 512) <= x"0123_4567_89AB_0F0F_0808_0808_0808_0808_0808_0808_0808_0808_0808_0808_0808_0808";
chirp_data(511 downto 256) <= x"0123_4567_89AB_0F0F_0808_0808_0808_0808_0808_0808_0808_0808_0808_0808_0808_0808";
chirp_data(255 downto 0) <= x"0123_4567_89AB_0F0F_0808_0808_0808_0808_0808_0808_0808_0808_0808_0808_0808_0808";



chirp_send <= r_o_led; 

o_led <= r_o_led;
o_output_en <= '1';
o_clk <= clk_in;

--###################################
--DAC输出值
--###################################
process(clk_in)
begin
    if rising_edge(clk_in) then
        if r_o_led = '0' then
            tlv5619_data <= x"000";
        else
            tlv5619_data <= x"fff";
        end if;
    end if;
end process;




--###################################


end Behavioral;
