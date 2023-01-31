--Copyright (C)2014-2021 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--GOWIN Version: V1.9.7.06Beta
--Part Number: GW1N-UV9QN48C6/I5
--Device: GW1N-9C
--Created Time: Sun Aug 22 18:36:26 2021

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component Gowin_pROM
    port (
        dout: out std_logic_vector(11 downto 0);
        clk: in std_logic;
        oce: in std_logic;
        ce: in std_logic;
        reset: in std_logic;
        ad: in std_logic_vector(9 downto 0)
    );
end component;

your_instance_name: Gowin_pROM
    port map (
        dout => dout_o,
        clk => clk_i,
        oce => oce_i,
        ce => ce_i,
        reset => reset_i,
        ad => ad_i
    );

----------Copy end-------------------
