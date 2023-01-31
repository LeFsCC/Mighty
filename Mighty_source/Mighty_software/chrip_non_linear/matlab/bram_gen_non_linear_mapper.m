clc;
clear all;
close all;

%##############################################################
% rom 参数
%##############################################################
module_name = 'rom_non_linear_mapper';
module_dir = 'E:\projects_fpga\21001\21001_FPGA_DAC_V2\chrip_non_linear\matlab';
rom_data_width = 12;
rom_depth = 4096;
rom_addr_width = ceil(log2(rom_depth));

%##############################################################
% 数据生成
%##############################################################
FREQ_L = 0;
FREQ_H = 4095;

FREQ_L_HEX = dec2hex(FREQ_L)
FREQ_H_HEX = dec2hex(FREQ_H)

x = 0:1:(rom_depth-1);
data_linear = ((FREQ_H - FREQ_L)/(rom_depth-1)) * x + FREQ_L;
data = ((FREQ_H - FREQ_L)/((rom_depth-1)^2)) * x .* x + FREQ_L;
data_bin = dec2bin(data,rom_data_width-1);
data_hex = dec2hex(data(1),rom_data_width-1);

figure(1);
plot(data_linear);
hold on;
plot(data);

%##############################################################
% VHDL 代码 生成
%##############################################################
fid=fopen([module_dir,'\',module_name,'.vhd'],'w');

fprintf(fid,'library IEEE;\r\n');
fprintf(fid,'use IEEE.STD_LOGIC_1164.ALL;\r\n');
fprintf(fid,'use IEEE.STD_LOGIC_ARITH.ALL;\r\n');
fprintf(fid,'use IEEE.STD_LOGIC_UNSIGNED.ALL;\r\n');
fprintf(fid,'\r\n\r\n\r\n');
fprintf(fid,['entity ',module_name,' is\r\n','port ( \r\n']);
%端口
fprintf(fid,'\ti_clk : in std_logic;\r\n');
fprintf(fid,'\ti_addr : in std_logic_vector(%d downto 0);\r\n',(rom_addr_width-1));
fprintf(fid,'\to_data : out std_logic_vector(%d downto 0)\r\n',(rom_data_width-1));
fprintf(fid,');\r\n');
fprintf(fid,['end ',module_name,';\r\n\r\n']);
fprintf(fid,['architecture Behavioral of ',module_name,' is\r\n\r\n']);
%声明
fprintf(fid,'TYPE ARRAY_ROM is array (natural range<>) of std_logic_vector(%d downto 0);\r\n\r\n',(rom_data_width-1));
fprintf(fid,'signal rom_data :ARRAY_ROM(%d downto 0);\r\n',(rom_depth-1));
fprintf(fid,'\r\n');
fprintf(fid,'attribute RAM_STYLE : string;\r\n');
fprintf(fid,'attribute RAM_STYLE of rom_data: signal is "BLOCK";\r\n');

fprintf(fid,'\r\n');
fprintf(fid,'begin\r\n');    
fprintf(fid,'\r\n\r\n');

for i = 0 : (rom_depth-1)
    fprintf(fid,'rom_data(%d) <= "%s";\r\n',i,dec2bin(data(i+1),rom_data_width));
end

fprintf(fid,'\r\n\r\n');
fprintf(fid,'process(i_clk)\r\nbegin\r\n');
fprintf(fid,'\tif rising_edge(i_clk) then\r\n');
fprintf(fid,'\t\tif conv_integer(i_addr) < %d then\r\n',rom_depth);
fprintf(fid,'\t\t\to_data <= rom_data(conv_integer(i_addr));\r\n');
fprintf(fid,'\t\telse\r\n');
fprintf(fid,'\t\t\to_data <= (others => ''0'');\r\n');
fprintf(fid,'\t\tend if;\r\n');
fprintf(fid,'\tend if;\r\n');
fprintf(fid,'end process;\r\n');

fprintf(fid,'\r\n\r\n\r\n');
fprintf(fid,'end Behavioral;\r\n\r\n\r\n');    
fclose(fid);



