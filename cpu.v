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

`define STATE_HALT      0
`define STATE_INIT      1
`define STATE_FETCH     2
`define STATE_DECODE    3
`define STATE_EXECUTE   4
`define STATE_REG_WRITE 5

`define OP_NOP   7'h00
`define OP_SET   7'h01
`define OP_LOAD  7'h02
`define OP_STORE 7'h03
`define OP_HALT  7'h7f

module regs (
    input rst_i,
    input clk_i,
    input we_i,
    input [$clog2(`REG_PC+1)-1:0] reg_id_i,
    input [`DAT_WIDTH-1:0] reg_dat_i,
    output reg [`DAT_WIDTH-1:0] reg_dat_o
);

    reg [`DAT_WIDTH-1:0] regs [0:`REG_PC];

    always @(posedge clk_i) begin
        if (rst_i) begin
            regs[`REG_ZERO] <= 64'h0;
            regs[`REG_PC] <= 64'h800000000000;
        end else begin
            if (we_i) begin
                regs[reg_id_i] <= reg_dat_i;
            end else begin
                reg_dat_o <= regs[reg_id_i];
            end
        end
    end

endmodule

module cpu (
    input rst_i,
    input clk_i,

    `WB_MASTER_PORT_SIGNALS(cpu_)
);

    reg [31:0] cpu_state = `STATE_INIT;
    reg [`DAT_WIDTH-1:0] instr;
    wire [6:0]  instr_opcode  = instr[63:57];
    wire [1:0]  instr_variant = instr[56:55];
    // fields of an RIS instruction (register, immediate, shift)
    wire [4:0]  instr_ris_reg = instr[54:50];
    wire [43:0] instr_ris_imm = instr[49:6];
    wire [5:0]  instr_ris_shl = instr[5:0];
    // fields of an RRO instruction (register, register, offset)
    wire [4:0]  instr_rro_dst = instr[54:50];
    wire [4:0]  instr_rro_src = instr[49:45];
    wire [44:0] instr_rro_off = instr[44:0];
    // fields of an I instruction (immediate)
    wire [54:0] instr_i_imm   = instr[54:0];

    reg [`DAT_WIDTH-1:0] instr_dst_val;
    reg [1:0] op_store_fetch_dst_clocks = 2, op_store_fetch_src_clocks = 2;
    reg [1:0] op_load_fetch_src_clocks = 2;
    reg [1:0] instr_fetch_clocks = 2'd2;

    reg [31:0] i;

    reg                   cpu_regs_write = 1'b0;
    reg  [4:0]            cpu_regs_id = `REG_PC;
    reg  [`DAT_WIDTH-1:0] cpu_regs_in;
    wire [`DAT_WIDTH-1:0] cpu_regs_out;

    regs cpu_regs (
        .rst_i(rst_i),
        .clk_i(clk_i),
        .we_i(cpu_regs_write),
        .reg_id_i(cpu_regs_id),
        .reg_dat_i(cpu_regs_in),
        .reg_dat_o(cpu_regs_out)
    );

    always @(posedge clk_i) begin
        if (rst_i) begin
            cpu_state <= `STATE_INIT;
            cpu_regs_write <= 1'b0;
            cpu_regs_id <= `REG_PC;
            op_store_fetch_dst_clocks <= 2'd2;
            op_store_fetch_src_clocks <= 2'd2;
            op_load_fetch_src_clocks <= 2'd2;
        end else begin
            case (cpu_state)
                `STATE_HALT: begin
                    // TODO add some logic to get out of here
                    $display("%g: CPU halted...", $time);
                end // `STATE_HALT
                `STATE_INIT: begin
                    // let the PC clock in from cpu_regs
                    cpu_state <= `STATE_FETCH;
                end // `STATE_INIT
                // issue a read bus cycle, to the address
                // which is currently stored in the `pc` register
                `STATE_FETCH: begin
                    $display("%g: fetching instruction at pc:%x", $time, cpu_regs_out);

                    if (instr_fetch_clocks > 0) begin
                        cpu_regs_write <= 1'b0;
                        cpu_regs_id <= `REG_PC;
                        instr_fetch_clocks <= instr_fetch_clocks - 1;
                    end else begin
                        instr_fetch_clocks <= 2'd2;

                        cpu_state <= `STATE_DECODE;
                        cpu_stb_o <= 1'b1;
                        cpu_cyc_o <= 1'b1;
                        cpu_we_o <= 1'b0;
                        cpu_sel_o <= 8'hff;
                        cpu_adr_o <= cpu_regs_out;

                        // increment the PC by one (instruction)
                        cpu_regs_write <= 1'b1;
                        cpu_regs_id <= `REG_PC;
                        cpu_regs_in <= cpu_regs_out + `DAT_WIDTH / 8;
                    end
                end // `STATE_FETCH
                `STATE_DECODE: begin
                    cpu_regs_write <= 1'b0;

                    if (cpu_ack_i) begin
                        $display("%g: read instruction %x", $time, cpu_dat_i);

                        cpu_state <= `STATE_EXECUTE;
                        instr <= cpu_dat_i;
                        cpu_stb_o <= 1'b0;
                        cpu_cyc_o <= 1'b0;
                    end else if (cpu_err_i) begin
                        $display("%g: err_i asserted when reading the next instruction",
                            $time, cpu_dat_i);

                        cpu_state <= `STATE_HALT;
                    end
                end // `STATE_DECODE
                `STATE_EXECUTE: begin
                    case (instr_opcode)
                        `OP_NOP: begin
                            $display("%g: nop", $time);

                            cpu_state <= `STATE_REG_WRITE;
                        end // `OP_SET
                        `OP_SET: begin
                            $display("%g: set r%1d, 0h%01x shl 0h%1x",
                                $time, instr_ris_reg, instr_ris_imm, instr_ris_shl);

                            cpu_regs_write <= 1'b1;
                            cpu_regs_id <= instr_ris_reg;
                            cpu_regs_in <= instr_ris_imm << instr_ris_shl;
                            cpu_state <= `STATE_REG_WRITE;
                        end // `OP_SET
                        `OP_LOAD: begin
                            $display("%g: load r%1d, r%1d off 0h%01x",
                                $time, instr_rro_dst, instr_rro_src, instr_rro_off);

                            if (op_load_fetch_src_clocks > 0) begin
                                $display("%g: loading value from register r%1d", $time, instr_rro_src);
                                cpu_regs_write <= 1'b0;
                                cpu_regs_id <= instr_rro_src;
                                op_load_fetch_src_clocks <= op_load_fetch_src_clocks - 1;
                            end else begin
                                $display("%g: -- r%1d -> %x", $time, instr_rro_src, cpu_regs_out);
                                cpu_stb_o <= 1'b1;
                                cpu_cyc_o <= 1'b1;
                                cpu_we_o <= 1'b0;
                                cpu_sel_o <= 8'hff;
                                cpu_adr_o <= cpu_regs_out + instr_rro_off;

                                $display("%g: -- adr_o: %x", $time, cpu_regs_out + instr_rro_off);

                                if (cpu_ack_i) begin
                                    $display("%g: -- data read: %x", $time, cpu_dat_i);

                                    cpu_stb_o <= 1'b0;
                                    cpu_cyc_o <= 1'b0;
                                    cpu_regs_write <= 1'b1;
                                    cpu_regs_id <= instr_rro_dst;
                                    cpu_regs_in <= cpu_dat_i;
                                    cpu_state <= `STATE_REG_WRITE;
                                    op_load_fetch_src_clocks <= 2'd2;
                                end
                            end
                        end // `OP_LOAD
                        `OP_STORE: begin
                            $display("%g: store r%1d, r%1d off 0h%01x",
                                $time, instr_rro_src, instr_rro_dst, instr_rro_off);

                            if (op_store_fetch_dst_clocks > 0) begin
                                cpu_regs_write <= 1'b0;
                                cpu_regs_id <= instr_rro_dst;
                                op_store_fetch_dst_clocks <= op_store_fetch_dst_clocks - 1;
                            end else if (op_store_fetch_src_clocks > 0) begin
                                instr_dst_val <= cpu_regs_out;
                                cpu_regs_write <= 1'b0;
                                cpu_regs_id <= instr_rro_src;
                                op_store_fetch_src_clocks <= op_store_fetch_src_clocks - 1;
                            end else begin
                                cpu_stb_o <= 1'b1;
                                cpu_cyc_o <= 1'b1;
                                cpu_we_o <= 1'b1;
                                cpu_sel_o <= 8'hff;
                                cpu_adr_o <= instr_dst_val + instr_rro_off;
                                cpu_dat_o <= cpu_regs_out;

                                if (cpu_ack_i) begin
                                    $display("%g: -- written %x to address %x", $time, cpu_dat_o, cpu_adr_o);
                                    cpu_stb_o <= 1'b0;
                                    cpu_cyc_o <= 1'b0;
                                    cpu_we_o <= 1'b0;
                                    op_store_fetch_dst_clocks <= 2'd2;
                                    op_store_fetch_src_clocks <= 2'd2;
                                    cpu_state <= `STATE_REG_WRITE;
                                end
                            end
                        end // `OP_LOAD
                        `OP_HALT: begin
                            $display("%g: halt", $time);

                            cpu_state <= `STATE_HALT;
                        end // `OP_HALT
                    endcase
                end // `STATE_EXECUTE
                `STATE_REG_WRITE: begin
                    // let the register write clock in
                    // and then read out the PC register so FETCH has it
                    $display("%g: reg write", $time);
                    cpu_regs_write <= 1'b0;
                    cpu_regs_id <= `REG_PC;
                    cpu_state <= `STATE_FETCH;
                end // `STATE_REG_WRITE
            endcase
        end
    end

endmodule
