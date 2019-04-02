`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    12:42:24 01/12/2019 
// Design Name: 
// Module Name:    ram 
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
`include "utils.v"

`define STATE_IDLE               0
`define STATE_WAIT_FOR_PHASE_END 1

module ram (
    input rst_i,
    input clk_i,

    `WB_SLAVE_PORT_SIGNALS(ram_)
);

    // 128 8-byte words = 1KiB by default
    parameter WORDS = 128;

    reg state = `STATE_IDLE;
    reg [`DAT_WIDTH-1:0] r_dat_o;
    reg r_ack = 1'h0;
    reg r_err = 1'h0;

    reg [`DAT_WIDTH-1:0] memory [0:WORDS-1];

    assign ram_ack_o = ram_stb_i ? r_ack : 1'b0;
    assign ram_err_o = ram_stb_i ? r_err : 1'b0;
    assign ram_dat_o = r_dat_o;

    always @(posedge clk_i) begin
        if (rst_i) begin
            state <= `STATE_IDLE;
            r_ack <= 1'h0;
            r_err <= 1'h0;
        end else begin
            case (state)
                `STATE_IDLE: begin
                    if (ram_stb_i) begin
                        state <= `STATE_WAIT_FOR_PHASE_END;

                        if ((ram_adr_i >> 3) >= WORDS) begin
                            // the address is too big
                            r_ack <= 1'h0;
                            r_err <= 1'h1;
                        end else begin
                            if (ram_we_i) begin
                                // FIXME this effectively means we are ignoring the
                                // low 3 bits of the address
                                memory[(ram_adr_i & 64'hffff) >> 3] <= ram_dat_i;
                            end else begin
                                r_dat_o <= memory[(ram_adr_i & 64'hffff) >> 3];
                            end

                            r_ack <= 1'h1;
                            r_err <= 1'h0;
                        end
                    end
                end
                `STATE_WAIT_FOR_PHASE_END: begin
                    if (~ram_stb_i) begin
                        state <= `STATE_IDLE;
                        r_ack <= 1'h0;
                        r_err <= 1'h0;
                    end
                end
            endcase
        end
    end

endmodule
