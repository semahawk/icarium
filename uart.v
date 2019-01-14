`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:12:27 01/10/2019 
// Design Name: 
// Module Name:    uart 
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

`define STATE_IDLE           0
`define STATE_SENDSTART_BITS 1
`define STATE_SEND_DATA      2
`define STATE_SENDSTOP_BITS  3

module uart (
    input rst_i,
    input clk_i,

    `WB_SLAVE_PORT_SIGNALS(uart_),

    output [7:0] uart_out
);

    reg [`DAT_WIDTH-1:0] r_dat_i;
    reg [`DAT_WIDTH-1:0] r_dat_o;
    reg r_ack = 1'h0;
    reg r_err = 1'h0;
    reg [4:0] uart_state;
    reg [7:0] r_uart_out;

    assign uart_ack_o = uart_stb_i ? r_ack : 1'b0;
    assign uart_err_o = uart_stb_i ? r_err : 1'b0;
    assign uart_dat_o = r_dat_o;
    assign uart_out = r_uart_out;

    always @(posedge clk_i) begin
        if (rst_i) begin
            uart_state <= `STATE_IDLE;
            r_ack <= 1'b0;
            r_err <= 1'b0;
            r_dat_o <= 64'hdeadbabe;
            r_uart_out <= 8'h0;
        end else begin
            case (uart_state)
                `STATE_IDLE: begin
                    if (uart_stb_i) begin
                        r_ack <= 1'b1;
                        r_err <= 1'b0;

                        if (uart_we_i)
                            r_uart_out <= uart_dat_i[7:0];
                    end
                end // `STATE_IDLE
            endcase
        end
    end

endmodule
