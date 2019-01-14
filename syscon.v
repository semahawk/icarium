`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:41:01 01/14/2019 
// Design Name: 
// Module Name:    syscon 
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

`include "config.v"
`include "wishbone.v"

module syscon (
    input ref_clk_i,
    input ref_rst_i,
    output syscon_clk_o,
    output syscon_rst_o,

    `WB_SLAVE_PORT_SIGNALS(syscon_)
);

    // how many clocks does the global reset last for
    parameter GLOBAL_RESET_CLOCKS = 10;

    reg [31:0] global_reset_counter = 32'd0;
    reg global_reset_done = 1'd0;

    assign syscon_clk_o = ref_clk_i;
    assign syscon_rst_o = global_reset_done ? ref_rst_i : 1'h1;

    // drive the Wishbone signals
    assign syscon_ack_o = syscon_stb_i;
    assign syscon_err_o = 1'h0;
    assign syscon_dat_o = {`DAT_WIDTH{1'h0}};

    always @(posedge ref_clk_i) begin
        if (ref_rst_i) begin
            global_reset_counter <= 32'd0;
            global_reset_done <= 1'd0;
        end else begin
            if (global_reset_counter == GLOBAL_RESET_CLOCKS) begin
                global_reset_done <= 1'd1;
            end else begin
                global_reset_counter = global_reset_counter + 1;
            end
        end
    end

endmodule
