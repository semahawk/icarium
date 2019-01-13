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

    reg [`DAT_WIDTH-1:0] rom_code [0:INSTRUCTIONS-1];
    reg [`DAT_WIDTH-1:0] r_dat_o;
    reg r_ack = 1'h0;
    reg r_err = 1'h0;
    reg state = `STATE_IDLE;
    reg [31:0] i;

    assign rom_ack_o = rom_stb_i ? r_ack : 1'b0;
    assign rom_err_o = rom_stb_i ? r_err : 1'b0;
    assign rom_dat_o = r_dat_o;

    initial begin
        $readmemh("rom_code.txt", rom_code);
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            state <= `STATE_IDLE;
            r_ack <= 1'h0;
            r_err <= 1'h0;

            $readmemh("rom_code.txt", rom_code);
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
                            if (rom_code[rom_adr_i / (`DAT_WIDTH / 8)] === {`DAT_WIDTH{1'hx}}) begin
                                // accessing code which is not there
                                r_dat_o <= rom_code[rom_adr_i / (`DAT_WIDTH / 8)];
                                r_ack <= 1'h0;
                                r_err <= 1'h1;
                            end else begin
                                // valid address containing actual data requested
                                r_dat_o <= rom_code[rom_adr_i / (`DAT_WIDTH / 8)];
                                r_ack <= 1'h1;
                                r_err <= 1'h0;
                            end
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
