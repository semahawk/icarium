`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    12:42:24 01/12/2019 
// Design Name: 
// Module Name:    rom 
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

module rom (
    input rst_i,
    input clk_i,

    `WB_SLAVE_PORT_SIGNALS(rom_)
);

    // number of instructions to be stored in the ROM
    // total size: INSTRUCTIONS * DAT_WIDTH bits
    parameter INSTRUCTIONS = 128;
    parameter GRANULE = 8;

    reg state = `STATE_IDLE;
    reg [`DAT_WIDTH-1:0] r_dat_o;
    reg r_ack = 1'h0;
    reg r_err = 1'h0;

    assign rom_ack_o = rom_stb_i ? r_ack : 1'b0;
    assign rom_err_o = rom_stb_i ? r_err : 1'b0;
    assign rom_dat_o = r_dat_o;

    always @(*) begin
        casex (rom_adr_i)
16'h0000: r_dat_o = 64'h0280401002000010; // set r1, 0x80100000 shl 16
16'h0008: r_dat_o = 64'h0280800000000e60; // set r2, 0x73 shl 0
16'h0010: r_dat_o = 64'h0281000000000060; // set r4, 0x3 shl 0
16'h0018: r_dat_o = 64'h0281400000000020; // set r5, 0x1 shl 0
16'h0020: r_dat_o = 64'h0281801757c00000; // set r6, 0xbabe0000 shl 0
16'h0028: r_dat_o = 64'h0400c20000000000; // load r3, r1 off 0
16'h0030: r_dat_o = 64'h0a80c00000000000; // testbit r3, 0
16'h0038: r_dat_o = 64'h0948800000000028; // jump.nz 0x800000000028
16'h0040: r_dat_o = 64'h0600440000000010; // store r2, r1 off 16
16'h0048: r_dat_o = 64'h0e81400000000020; // shiftl r5, 1
16'h0050: r_dat_o = 64'h10018a0000000000; // or r6, r5
16'h0058: r_dat_o = 64'h12018c0000000000; // and r6, r6
16'h0060: r_dat_o = 64'h0c81000000000020; // sub r4, 1
16'h0068: r_dat_o = 64'h0908800000000078; // jump.z 0x800000000078
16'h0070: r_dat_o = 64'h0900800000000028; // jump 0x800000000028
16'h0078: r_dat_o = 64'h02028c0000000000; // set r10, r6
16'h0080: r_dat_o = 64'hff00000000000000; // halt
            default:  r_dat_o = 64'hfe00000000000000; // halt by default
        endcase
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            state <= `STATE_IDLE;
            r_ack <= 1'h0;
            r_err <= 1'h0;
        end else begin
            case (state)
                `STATE_IDLE: begin
                    if (rom_stb_i) begin
                        state <= `STATE_WAIT_FOR_PHASE_END;

                        if (rom_we_i) begin
                            // it's a ROM - no writing allowed
                            // simply assert err_o and do nothing else
                            r_ack <= 1'h0;
                            r_err <= 1'h1;
                        end else begin
                            r_ack <= 1'h1;
                            r_err <= 1'h0;
                        end
                    end
                end
                `STATE_WAIT_FOR_PHASE_END: begin
                    if (~rom_stb_i) begin
                        state <= `STATE_IDLE;
                        r_ack <= 1'h0;
                        r_err <= 1'h0;
                    end
                end
            endcase
        end
    end

endmodule
