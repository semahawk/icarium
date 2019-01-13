`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:22:31 01/10/2019 
// Design Name: 
// Module Name:    cpu 
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

`include "wishbone.v"

`define REG_ZERO  0
`define REG_PC   31

`define STATE_FETCH   0
`define STATE_DECODE  1
`define STATE_EXECUTE 2

`define OP_NOP   7'h00
`define OP_SET   7'h01
`define OP_LOAD  7'h02
`define OP_STORE 7'h03
`define OP_HALT  7'h7f

module cpu (
    input rst_i,
    input clk_i,

    `WB_MASTER_PORT_SIGNALS(cpu_)
);

    // _the_ cpu's registers
    reg [`DAT_WIDTH-1:0] cpu_regs [0:31];
    reg [31:0] cpu_state;
    reg cpu_halted;
    reg [`DAT_WIDTH-1:0] instr;
    wire [6:0]  instr_opcode  = instr[63:57];
    wire [1:0]  instr_variant = instr[56:55];
    // fields of an RIS instruction (register, immediate, shift)
    wire [4:0]  instr_ris_reg = instr[54:50];
    wire [43:0] instr_ris_imm = instr[49:6];
    wire [5:0]  instr_ris_shl = instr[5:0];
    // fields of an RRO instruction (register, register, offset)
    wire [5:0]  instr_rro_dst = instr[54:50];
    wire [5:0]  instr_rro_src = instr[49:45];
    wire [44:0] instr_rro_off = instr[44:0];
    reg [31:0] i;

    always @(posedge clk_i) begin
        if (rst_i) begin
            cpu_state <= `STATE_FETCH;
            cpu_halted <= 1'b0;
            cpu_stb_o <= 1'b0;
            cpu_cyc_o <= 1'b0;

            for (i = `REG_ZERO; i < `REG_PC; i = i + 1)
                cpu_regs[i] <= {`DAT_WIDTH{1'h0}};

            // ! TODO: change to ROM's actual address
            cpu_regs[`REG_PC] <= 64'h0000800000000000;
        end else if (cpu_halted) begin
            // nop
        end else begin
            case (cpu_state)
                // issue a read bus cycle, to the address
                // which is currently stored in the `pc` register
                `STATE_FETCH: begin
                    cpu_state <= `STATE_DECODE;
                    cpu_stb_o <= 1'b1;
                    cpu_cyc_o <= 1'b1;
                    cpu_we_o <= 1'b0;
                    cpu_sel_o <= 8'hff;
                    cpu_adr_o <= cpu_regs[`REG_PC];
                    cpu_regs[`REG_PC] <= cpu_regs[`REG_PC] + 8;
                end // `STATE_FETCH
                `STATE_DECODE: begin
                    if (cpu_ack_i) begin
                        cpu_state <= `STATE_EXECUTE;
                        instr <= cpu_dat_i;
                        cpu_stb_o <= 1'b0;
                        cpu_cyc_o <= 1'b0;
                    end else if (cpu_err_i) begin
                        cpu_halted <= 1'b1;
                        cpu_stb_o <= 1'b0;
                        cpu_cyc_o <= 1'b0;
                    end
                end // `STATE_DECODE
                `STATE_EXECUTE: begin
                    case (instr_opcode)
                        `OP_NOP: begin
                            $display("%g: nop", $time);

                            cpu_state <= `STATE_FETCH;
                        end // `OP_SET
                        `OP_SET: begin
                            $display("%g: set r%1d, 0h%01x shl 0h%1x",
                                $time, instr_ris_reg, instr_ris_imm, instr_ris_shl);

                            cpu_regs[instr_ris_reg] <= instr_ris_imm << instr_ris_shl;
                            cpu_state <= `STATE_FETCH;
                        end // `OP_SET
                        `OP_LOAD: begin
                            $display("%g: load r%1d, r%1d off 0h%01x",
                                $time, instr_rro_dst, instr_rro_src, instr_rro_off);

                            cpu_stb_o <= 1'b1;
                            cpu_cyc_o <= 1'b1;
                            cpu_we_o <= 1'b0;
                            cpu_sel_o <= 8'hff;
                            cpu_adr_o <= cpu_regs[instr_rro_src] + instr_rro_off;

                            if (cpu_ack_i) begin
                                $display("%g: -- data read: %x", $time, cpu_dat_i);

                                cpu_stb_o <= 1'b0;
                                cpu_cyc_o <= 1'b0;
                                cpu_regs[instr_rro_dst] <= cpu_dat_i;
                                cpu_state <= `STATE_FETCH;
                            end
                        end // `OP_LOAD
                        `OP_STORE: begin
                            $display("%g: store r%1d, r%1d off 0h%01x",
                                $time, instr_rro_src, instr_rro_dst, instr_rro_off);

                            cpu_stb_o <= 1'b1;
                            cpu_cyc_o <= 1'b1;
                            cpu_we_o <= 1'b1;
                            cpu_sel_o <= 8'hff;
                            cpu_adr_o <= cpu_regs[instr_rro_dst] + instr_rro_off;
                            cpu_dat_o <= cpu_regs[instr_rro_src];

                            if (cpu_ack_i) begin
                                $display("%g: -- written %x to address %x", $time, cpu_dat_o, cpu_adr_o);
                                cpu_stb_o <= 1'b0;
                                cpu_cyc_o <= 1'b0;
                                cpu_we_o <= 1'b0;
                                cpu_state <= `STATE_FETCH;
                            end
                        end // `OP_LOAD
                        `OP_HALT: begin
                            $display("%g: halt", $time);

                            cpu_halted <= 1'b1;
                            cpu_state <= `STATE_FETCH;
                        end // `OP_HALT
                    endcase
                end
            endcase
        end
    end

endmodule
