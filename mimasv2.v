`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:10:47 01/14/2019 
// Design Name: 
// Module Name:    mimasv2 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module mimasv2 (
    input Mv2_CLK,
    output [7:0] Mv2_LED
);

    soc soc (
        .soc_clk_i(Mv2_CLK),
        .soc_rst_i(1'h0),
        .soc_leds_o(Mv2_LED)
    );

endmodule
