--Copyright (C)2014-2021 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: IP file
--GOWIN Version: V1.9.7.06Beta
--Part Number: GW1N-UV9QN48C6/I5
--Device: GW1N-9
--Created Time: Thu Jun 24 22:34:36 2021

library IEEE;
use IEEE.std_logic_1164.all;

entity Gowin_OSC is
    port (
        oscout: out std_logic
    );
end Gowin_OSC;

architecture Behavioral of Gowin_OSC is

    --component declaration
    component OSC
        generic (
            FREQ_DIV: in integer := 100;
            DEVICE: in string := "GW1N-4"
        );
        port (
            OSCOUT: out std_logic
        );
    end component;

begin
    osc_inst: OSC
        generic map (
            FREQ_DIV => 52,
            DEVICE => "GW1N-9C"
        )
        port map (
            OSCOUT => oscout
        );

end Behavioral; --Gowin_OSC
