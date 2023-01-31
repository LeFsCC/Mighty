--Copyright (C)2014-2021 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--GOWIN Version: V1.9.7.06Beta
--Part Number: GW1N-UV9QN48C6/I5
--Device: GW1N-9C
--Created Time: Sun Jun 27 23:12:30 2021

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component Gowin_OSC
    port (
        oscout: out std_logic
    );
end component;

your_instance_name: Gowin_OSC
    port map (
        oscout => oscout_o
    );

----------Copy end-------------------
