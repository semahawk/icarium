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
`define REG_SP   30
`define REG_PC   31

`define STATE_HALT      0
`define STATE_INIT      1
`define STATE_INIT2     2
`define STATE_FETCH     3
`define STATE_DECODE    4
`define STATE_REG_READ  5
`define STATE_EXECUTE   6
`define STATE_REG_WRITE 7

`define OP_NOP     7'h00
`define OP_SET     7'h01
`define OP_LOAD    7'h02
`define OP_STORE   7'h03
`define OP_JUMP    7'h04
`define OP_TESTBIT 7'h05
`define OP_SUB     7'h06
`define OP_SHIFTL  7'h07
`define OP_OR      7'h08
`define OP_AND     7'h09
`define OP_XOR     7'h0a
`define OP_ADD     7'h0b
`define OP_SHIFTR  7'h0c
`define OP_CALL    7'h0d
`define OP_RETURN  7'h0e
`define OP_HALT    7'h7f

`define OP_CALL_STATE_0 0
`define OP_CALL_STATE_1 1
`define OP_CALL_STATE_2 2
`define OP_CALL_STATE_3 3

`define OP_RETURN_STATE_0 0
`define OP_RETURN_STATE_1 1
`define OP_RETURN_STATE_2 2
`define OP_RETURN_STATE_3 3

// those values should be encoded into the instruction
`define INSTR_FORMAT_RRO  2'b00
`define INSTR_FORMAT_RIS  2'b01
`define INSTR_FORMAT_I    2'b10

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
        if (we_i) begin
            regs[reg_id_i] <= reg_dat_i;
        end else begin
            reg_dat_o <= regs[reg_id_i];
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
    wire [6:0]  instr_opcode    = instr[63:57];
    wire [1:0]  instr_format    = instr[56:55];
    wire [3:0]  instr_condition = instr[54:51];
    // fields of an RIS instruction (register, immediate, shift)
    wire [4:0]  instr_ris_reg = instr[50:46];
    wire [40:0] instr_ris_imm = instr[45:5];
    wire [4:0]  instr_ris_shl = instr[4:0];
    // fields of an RRO instruction (register, register, offset)
    wire [4:0]  instr_rro_dst = instr[50:46];
    wire [4:0]  instr_rro_src = instr[45:41];
    wire [40:0] instr_rro_off = instr[40:0];
    // fields of an I instruction (immediate)
    wire [50:0] instr_i_imm   = instr[50:0];

    reg [1:0] instr_fetch_clocks = 2'd2;
    reg [1:0] fetch_dst_reg_clocks = 2'd2;
    reg [1:0] fetch_src_reg_clocks = 2'd2;
    reg [`DAT_WIDTH-1:0] instr_dst_reg_val;
    reg [`DAT_WIDTH-1:0] instr_src_reg_val;

    reg [1:0] op_call_state;
    reg [1:0] op_return_state;
    reg [`DAT_WIDTH-1:0] op_return_next_pc;

    reg [`DAT_WIDTH-1:0] cpu_save_next_pc;

    reg                   cpu_regs_write = 1'b0;
    reg  [4:0]            cpu_regs_id = `REG_PC;
    reg  [`DAT_WIDTH-1:0] cpu_regs_in;
    wire [`DAT_WIDTH-1:0] cpu_regs_out;

    reg cpu_stat_z = 1'b0;

    regs cpu_regs (
        .rst_i(rst_i),
        .clk_i(clk_i),
        .we_i(cpu_regs_write),
        .reg_id_i(cpu_regs_id),
        .reg_dat_i(cpu_regs_in),
        .reg_dat_o(cpu_regs_out)
    );

    reg [63:0] cpu_ticks = 64'h0;

    always @(posedge clk_i) begin
        if (rst_i)
            cpu_ticks <= 64'h0;
        else
            cpu_ticks <= cpu_ticks + 1;
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            cpu_state <= `STATE_INIT;
            cpu_regs_write <= 1'b0;
            fetch_dst_reg_clocks <= 2'd2;
            fetch_src_reg_clocks <= 2'd2;
            op_call_state <= `OP_CALL_STATE_0;
            op_return_state <= `OP_RETURN_STATE_0;
        end else begin
            case (cpu_state)
                `STATE_HALT: begin
                    // TODO add some logic to get out of here
                    // $display("%g: CPU halted...", $time);
                end // `STATE_HALT
                 `STATE_INIT: begin
                    cpu_regs_write <= 1'd1;
                    cpu_regs_id <= `REG_PC;
                    cpu_regs_in <= 64'h800000000000;
                    cpu_state <= `STATE_INIT2;
                end // `STATE_INIT
                `STATE_INIT2: begin
                    // let the PC clock in
                    cpu_regs_write <= 1'd0;
                    cpu_state <= `STATE_FETCH;
                end // `STATE_INIT2
                // issue a read bus cycle, to the address
                // which is currently stored in the `pc` register
                `STATE_FETCH: begin
                    // $monitor("%g: fetching instruction at pc:%x", $time, cpu_regs_out);

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
                    // save the pc of the next instruction (if any op needs it)
                    cpu_save_next_pc <= cpu_regs_out;
                    cpu_regs_write <= 1'b0;

                    if (cpu_ack_i) begin
                        // $display("%g: read instruction %x", $time, cpu_dat_i);
                        // $display("%g: -- condition: 4'b%b", $time, cpu_dat_i[54:51]);

                        if (cpu_dat_i[54:51] == 4'b0001 /* .z */ && cpu_stat_z == 1'b0) begin
                            // $display("%g: -- condition not met - not executing the instruction", $time);
                            cpu_state <= `STATE_REG_WRITE;
                        end else if (cpu_dat_i[54:51] == 4'b1001 /* .nz */ && cpu_stat_z == 1'b1) begin
                            // $display("%g: -- condition not met - not executing the instruction", $time);
                            cpu_state <= `STATE_REG_WRITE;
                        end else begin
                            // `instr` will be set on the next cycle, so
                            //  we can't use the instr_format here
                            if (cpu_dat_i[56:55] == `INSTR_FORMAT_RIS || cpu_dat_i[56:55] == `INSTR_FORMAT_RRO)
                                cpu_state <= `STATE_REG_READ;
                            else
                                cpu_state <= `STATE_EXECUTE;

                            instr <= cpu_dat_i;
                            cpu_stb_o <= 1'b0;
                            cpu_cyc_o <= 1'b0;
                        end
                    end else if (cpu_err_i) begin
                        $display("%g: err_i asserted when reading the next instruction",
                            $time, cpu_dat_i);

                        cpu_state <= `STATE_HALT;
                    end
                end // `STATE_DECODE
                `STATE_REG_READ: begin
                    if (fetch_dst_reg_clocks > 0) begin
                        if (instr_format == `INSTR_FORMAT_RRO)
                            cpu_regs_id <= instr_rro_dst;
                        else if (instr_format == `INSTR_FORMAT_RIS)
                            cpu_regs_id <= instr_ris_reg;

                        cpu_regs_write <= 1'b0;
                        fetch_dst_reg_clocks <= fetch_dst_reg_clocks - 1;
                    end else if (fetch_src_reg_clocks > 0) begin
                        instr_dst_reg_val <= cpu_regs_out;

                        if (instr_format == `INSTR_FORMAT_RIS) begin
                            cpu_state <= `STATE_EXECUTE;
                            fetch_dst_reg_clocks <= 2'd2;
                            fetch_src_reg_clocks <= 2'd2;
                        end else begin
                            cpu_regs_write <= 1'b0;
                            cpu_regs_id <= instr_rro_src;
                            fetch_src_reg_clocks <= fetch_src_reg_clocks - 1;
                        end
                    end else begin
                        instr_src_reg_val <= cpu_regs_out;
                        cpu_state <= `STATE_EXECUTE;
                        fetch_dst_reg_clocks <= 2'd2;
                        fetch_src_reg_clocks <= 2'd2;

                        // 'pre-load' the sp register
                        if (instr_opcode == `OP_CALL) begin
                            cpu_regs_write <= 1'b0;
                            cpu_regs_id <= `REG_SP;
                        end
                    end
                end
                `STATE_EXECUTE: begin
                    case (instr_opcode)
                        `OP_NOP: begin
                            // $display("%g: nop", $time);

                            cpu_state <= `STATE_REG_WRITE;
                        end // `OP_SET
                        `OP_SET: begin
                            if (instr_format == `INSTR_FORMAT_RIS) begin
                                // $display("%g: set r%1d, 0h%01x shl 0h%1x",
                                    // $time, instr_ris_reg, instr_ris_imm, instr_ris_shl);

                                cpu_regs_id <= instr_ris_reg;
                                cpu_regs_in <= instr_ris_imm << instr_ris_shl;
                            end else if (instr_format == `INSTR_FORMAT_RRO) begin
                                // $display("%g: set r%1d, r%1d",
                                    // $time, instr_rro_dst, instr_rro_src);

                                cpu_regs_id <= instr_rro_dst;
                                cpu_regs_in <= instr_src_reg_val;
                            end

                            cpu_regs_write <= 1'b1;
                            cpu_state <= `STATE_REG_WRITE;
                        end // `OP_SET
                        `OP_SUB: begin
                            // $display("%g: sub r%1d, 0h%01x",
                                // $time, instr_ris_reg, instr_ris_imm);

                            cpu_regs_write <= 1'b1;
                            cpu_regs_id <= instr_ris_reg;
                            cpu_regs_in <= instr_dst_reg_val - instr_ris_imm;
                            cpu_state <= `STATE_REG_WRITE;

                            if ((instr_dst_reg_val - instr_ris_imm) == 64'h0) begin
                                cpu_stat_z <= 1'b1;
                            end else begin
                                cpu_stat_z <= 1'b0;
                            end
                        end // `OP_SUB
                        `OP_ADD: begin
                            // $display("%g: add r%1d, 0h%01x",
                                // $time, instr_ris_reg, instr_ris_imm);

                            cpu_regs_write <= 1'b1;
                            cpu_regs_id <= instr_ris_reg;
                            cpu_regs_in <= instr_dst_reg_val + instr_ris_imm;
                            cpu_state <= `STATE_REG_WRITE;

                            // TODO: check for overflow etc. and set flags
                        end // `OP_ADD
                        `OP_SHIFTL: begin
                            // $display("%g: shiftl r%1d, 0h%01x",
                                // $time, instr_ris_reg, instr_ris_imm);

                            cpu_regs_write <= 1'b1;
                            cpu_regs_id <= instr_ris_reg;
                            cpu_regs_in <= instr_dst_reg_val << instr_ris_imm;
                            cpu_state <= `STATE_REG_WRITE;
                        end // `OP_SHIFTL
                        `OP_SHIFTR: begin
                            // $display("%g: shiftr r%1d, 0h%01x",
                                // $time, instr_ris_reg, instr_ris_imm);

                            cpu_regs_write <= 1'b1;
                            cpu_regs_id <= instr_ris_reg;
                            cpu_regs_in <= instr_dst_reg_val >> instr_ris_imm;
                            cpu_state <= `STATE_REG_WRITE;
                        end // `OP_SHIFTR
                        `OP_OR: begin
                            // $display("%g: or r%1d, r%1d",
                                // $time, instr_rro_dst, instr_rro_src);

                            cpu_regs_write <= 1'b1;
                            cpu_regs_id <= instr_rro_dst;
                            cpu_regs_in <= instr_dst_reg_val | instr_src_reg_val;
                            cpu_state <= `STATE_REG_WRITE;
                        end // `OP_OR
                        `OP_AND: begin
                            // $display("%g: and r%1d, r%1d",
                                // $time, instr_rro_dst, instr_rro_src);

                            cpu_regs_write <= 1'b1;
                            cpu_regs_id <= instr_rro_dst;
                            cpu_regs_in <= instr_dst_reg_val & instr_src_reg_val;
                            cpu_state <= `STATE_REG_WRITE;
                        end // `OP_AND
                        `OP_XOR: begin
                            // $display("%g: xor r%1d, r%1d",
                                // $time, instr_rro_dst, instr_rro_src);

                            cpu_regs_write <= 1'b1;
                            cpu_regs_id <= instr_rro_dst;
                            cpu_regs_in <= instr_dst_reg_val ^ instr_src_reg_val;
                            cpu_state <= `STATE_REG_WRITE;
                        end // `OP_XOR
                        `OP_LOAD: begin
                            // $display("%g: load r%1d, r%1d (h'%x) off 0h%01x",
                                // $time, instr_rro_dst, instr_rro_src,
                                // instr_src_reg_val + instr_rro_off, instr_rro_off);

                            cpu_stb_o <= 1'b1;
                            cpu_cyc_o <= 1'b1;
                            cpu_we_o <= 1'b0;
                            cpu_sel_o <= 8'hff;
                            cpu_adr_o <= instr_src_reg_val + instr_rro_off;

                            if (cpu_ack_i) begin
                                cpu_stb_o <= 1'b0;
                                cpu_cyc_o <= 1'b0;
                                cpu_regs_write <= 1'b1;
                                cpu_regs_id <= instr_rro_dst;
                                cpu_regs_in <= cpu_dat_i;
                                cpu_state <= `STATE_REG_WRITE;
                            end
                        end // `OP_LOAD
                        `OP_STORE: begin
                            // $display("%g: store r%1d, r%1d off 0h%01x",
                                // $time, instr_rro_src, instr_rro_dst, instr_rro_off);

                            cpu_stb_o <= 1'b1;
                            cpu_cyc_o <= 1'b1;
                            cpu_we_o <= 1'b1;
                            cpu_sel_o <= 8'hff;
                            cpu_adr_o <= instr_dst_reg_val + instr_rro_off;
                            cpu_dat_o <= instr_src_reg_val;

                            if (cpu_ack_i) begin
                                // $display("%g: -- written %x to address %x", $time, cpu_dat_o, cpu_adr_o);
                                cpu_stb_o <= 1'b0;
                                cpu_cyc_o <= 1'b0;
                                cpu_we_o <= 1'b0;
                                cpu_state <= `STATE_REG_WRITE;
                            end
                        end // `OP_LOAD
                        `OP_JUMP: begin
                            if (instr_rro_off[40] == 1'b1)
                                $display("%g: jump r%1d (h'%x) off -0x%1x", $time,
                                    instr_rro_dst, instr_dst_reg_val, ~instr_rro_off + 1);
                            else
                                $display("%g: jump r%1d (h'%x) off 0x%1x", $time,
                                    instr_rro_dst, instr_dst_reg_val, instr_rro_off);

                            cpu_regs_in <= $signed(instr_dst_reg_val) + $signed(instr_rro_off);
                            cpu_regs_write <= 1'b1;
                            cpu_regs_id <= `REG_PC;
                            cpu_state <= `STATE_REG_WRITE;
                        end // `OP_JUMP
                        `OP_CALL: begin
                            if (instr_rro_off[40] == 1'b1)
                                $display("%g: call r%1d (h'%x) off -0x%1x", $time,
                                    instr_rro_dst, instr_dst_reg_val, ~instr_rro_off + 1);
                            else
                                $display("%g: call r%1d (h'%x) off 0x%1x", $time,
                                    instr_rro_dst, instr_dst_reg_val, instr_rro_off);

                            case (op_call_state)
                                `OP_CALL_STATE_0: begin
                                    // the `STATE_REG_READ stage preloaded the sp register
                                    // delay one cycle to fetch the content of sp
                                    op_call_state <= `OP_CALL_STATE_1;
                                end
                                `OP_CALL_STATE_1: begin
                                    // and prepare for sp to be decreased
                                    cpu_regs_write <= 1'b1;
                                    cpu_regs_in <= cpu_regs_out - 8 /* sp - 8 */;
                                    cpu_regs_id <= `REG_SP;

                                    // issue a bus write cycle to write the return address
                                    // onto the stack
                                    cpu_stb_o <= 1'b1;
                                    cpu_cyc_o <= 1'b1;
                                    cpu_we_o <= 1'b1;
                                    cpu_sel_o <= 8'hff;
                                    cpu_adr_o <= cpu_regs_out - 8 /* value of sp */;
                                    cpu_dat_o <= cpu_save_next_pc + 8 /* next instruction's pc */;

                                    if (cpu_ack_i) begin
                                        cpu_stb_o <= 1'b0;
                                        cpu_cyc_o <= 1'b0;
                                        cpu_we_o <= 1'b0;
                                        op_call_state <= `OP_CALL_STATE_2;
                                    end
                                end
                                `OP_CALL_STATE_2: begin
                                    // make sure the new value of sp clocks in
                                    op_call_state <= `OP_CALL_STATE_3;
                                end
                                `OP_CALL_STATE_3: begin
                                    // and finally, make the actual jump
                                    // by overwritting pc
                                    cpu_regs_in <= $signed(instr_dst_reg_val) + $signed(instr_rro_off);
                                    cpu_regs_write <= 1'b1;
                                    cpu_regs_id <= `REG_PC;
                                    cpu_state <= `STATE_REG_WRITE;
                                    op_call_state <= `OP_CALL_STATE_0;
                                end
                            endcase
                        end // `OP_CALL
                        `OP_RETURN: begin
                            $display("%g: return", $time);

                            case (op_return_state)
                                `OP_RETURN_STATE_0: begin
                                    cpu_regs_write <= 1'b0;
                                    cpu_regs_id <= `REG_SP;
                                    op_return_state <= `OP_RETURN_STATE_1;
                                end
                                `OP_RETURN_STATE_1: begin
                                    // delay one cycle to fetch the content of sp
                                    op_return_state <= `OP_RETURN_STATE_2;
                                end
                                `OP_RETURN_STATE_2: begin
                                    // make a bus read cycle to read the
                                    // return address from the top of stack
                                    cpu_stb_o <= 1'b1;
                                    cpu_cyc_o <= 1'b1;
                                    cpu_we_o <= 1'b0;
                                    cpu_sel_o <= 8'hff;
                                    cpu_adr_o <= cpu_regs_out /* value of sp */;

                                    if (cpu_ack_i) begin
                                        cpu_stb_o <= 1'b0;
                                        cpu_cyc_o <= 1'b0;
                                        // save the pc to jump to
                                        op_return_next_pc <= cpu_dat_i;
                                        // let's increment sp by 8
                                        cpu_regs_write <= 1'b1;
                                        cpu_regs_id <= `REG_SP;
                                        cpu_regs_in <= cpu_regs_out + 8;
                                        op_return_state <= `OP_RETURN_STATE_3;
                                    end
                                end
                                `OP_RETURN_STATE_3: begin
                                  // new sp should have clocked in
                                  // let's now set the pc to the new one
                                  cpu_regs_write <= 1'b1;
                                  cpu_regs_id <= `REG_PC;
                                  cpu_regs_in <= op_return_next_pc;
                                  cpu_state <= `STATE_REG_WRITE;
                                  op_return_state <= `OP_RETURN_STATE_0;
                                end
                            endcase
                        end // `OP_RETURN
                        `OP_TESTBIT: begin
                            // $display("%g: testbit r%01d, %01d", $time,
                                // instr_ris_reg, instr_ris_imm);

                            if (instr_dst_reg_val & (64'b1 << instr_ris_imm)) begin
                                // $display("%g: -- bit %01d is set - clearing CPU_STAT_Z", $time, instr_ris_imm);
                                cpu_stat_z <= 1'b0;
                            end else begin
                                // $display("%g: -- bit %01d is unset - setting CPU_STAT_Z", $time, instr_ris_imm);
                                cpu_stat_z <= 1'b1;
                            end

                            cpu_state <= `STATE_REG_WRITE;
                        end // `OP_TESTBIT
                        `OP_HALT: begin
                            // $display("%g: halt", $time);

                            cpu_state <= `STATE_HALT;
                        end // `OP_HALT
                    endcase
                end // `STATE_EXECUTE
                `STATE_REG_WRITE: begin
                    // let the register write clock in
                    // and then read out the PC register so FETCH has it
                    // $display("%g: reg write", $time);
                    cpu_regs_write <= 1'b0;
                    cpu_regs_id <= `REG_PC;
                    cpu_state <= `STATE_FETCH;
                end // `STATE_REG_WRITE
            endcase
        end
    end

endmodule
