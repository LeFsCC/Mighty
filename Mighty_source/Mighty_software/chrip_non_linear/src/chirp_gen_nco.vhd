--#########################################
--32 bit NCO 模块
--#########################################


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity chirp_gen_nco is
port ( 
    i_clk : in std_logic;                               --时钟输入
    i_clear : in std_logic;                             --计数器复位，高有效，触发后计数器值更新为i_val_init值
    i_val_init : in std_logic_vector(31 downto 0);      --计数器初始值
    i_val_incr : in std_logic_vector(31 downto 0);      --NCO 累加量，即频率控制字，计算公式为：i_val_incr = Fout/i_clk * 2^32
    o_ce : out std_logic                                --NCO 输出，脉冲宽度为单个i_clk周期，频率为Fout
);
end chirp_gen_nco;

architecture Behavioral of chirp_gen_nco is

signal cnt_nco :std_logic_vector(31 downto 0) := (others => '0');
signal cnt_nco_31reg :std_logic := '0';

begin

process(i_clk)
begin
    if rising_edge(i_clk) then
        if i_clear = '1' then
            cnt_nco <= i_val_init;
        else
            cnt_nco <= cnt_nco + i_val_incr;
        end if;
        cnt_nco_31reg <= cnt_nco(31);
        o_ce <= (cnt_nco_31reg) and (not cnt_nco(31));
    end if;
end process;



end Behavioral;

