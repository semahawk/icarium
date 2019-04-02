`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    20:56:07 01/10/2019 
// Design Name: 
// Module Name:    intercon 
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

`define STATE_WAIT_FOR_BUS_CLAIM 0
`define STATE_WAIT_FOR_CYCLE_END 1

module intercon (
    input wire rst_i,
    input wire clk_i,

    //
    // master -> intercon
    //
    input wire [MASTERS_NUM-1:0] m2i_cyc_i,
    input wire [MASTERS_NUM-1:0] m2i_stb_i,
    input wire [MASTERS_NUM-1:0] m2i_we_i,
    input wire [MASTERS_NUM*`ADR_WIDTH-1:0] m2i_adr_i,
    input wire [MASTERS_NUM*`DAT_WIDTH-1:0] m2i_dat_i,
    input wire [MASTERS_NUM*`SEL_WIDTH-1:0] m2i_sel_i,
    //
    // intercon -> master
    //
    output wire [MASTERS_NUM-1:0] i2m_ack_o,
    output wire [MASTERS_NUM-1:0] i2m_err_o,
    // shared between all masters
    output wire [`DAT_WIDTH-1:0] i2m_dat_o,
    //
    // slave -> intercon
    //
    input wire [SLAVES_NUM-1:0] s2i_ack_i,
    input wire [SLAVES_NUM-1:0] s2i_err_i,
    input wire [SLAVES_NUM*`DAT_WIDTH-1:0] s2i_dat_i,
    //
    // intercon -> slave
    //
    // each slave gets it's own stb signal
    output wire [SLAVES_NUM-1:0] i2s_stb_o,
    //  and these are all shared across all slaves
    output wire i2s_cyc_o,
    output wire [`ADR_WIDTH-1:0] i2s_adr_o,
    output wire [`DAT_WIDTH-1:0] i2s_dat_o,
    output wire [`SEL_WIDTH-1:0] i2s_sel_o,
    output wire i2s_we_o
);

    parameter MASTERS_NUM = 2;
    parameter SLAVES_NUM = 2;

    reg [0:0] state = `STATE_WAIT_FOR_BUS_CLAIM;
    reg [$clog2(MASTERS_NUM)-1:0] grant = 0;

    reg [$clog2(SLAVES_NUM)-1:0] selected_slave;
    wire [`ADR_WIDTH-1:0] granted_masters_adr_i = m2i_adr_i[`ADR_WIDTH*grant+:`ADR_WIDTH];

    // distribute the stb_o signal only to the one slave
    assign i2s_stb_o = m2i_stb_i[grant] << selected_slave;
    // distribute the rest of signals, which are shared across all slaves
    assign i2s_cyc_o = {SLAVES_NUM{m2i_cyc_i[grant]}};
    assign i2s_adr_o = m2i_adr_i[`ADR_WIDTH*grant+:`ADR_WIDTH] & 12'hfff;
    assign i2s_dat_o = m2i_dat_i[`DAT_WIDTH*grant+:`DAT_WIDTH];
    assign i2s_sel_o = m2i_sel_i[`SEL_WIDTH*grant+:`SEL_WIDTH];
    assign i2s_we_o = m2i_we_i[grant];

    // distribute the ack and err signals coming back from the slave to the blessed master
    assign i2m_ack_o = s2i_ack_i[selected_slave] << grant;
    assign i2m_err_o = s2i_err_i[selected_slave] << grant;
    // distribute the output data of the selected slave to all masters
    assign i2m_dat_o = s2i_dat_i[`DAT_WIDTH*selected_slave+:`DAT_WIDTH];

    reg [7:0] n, i;
    reg found_next_master;

    always @* begin
        if (rst_i) begin
            selected_slave <= 0;
        end else begin
            if (granted_masters_adr_i >= 64'h0000800000000000 &&
                granted_masters_adr_i <  64'h0000800000000400)
                // ROM
                selected_slave <= 1;
            else
            if (granted_masters_adr_i >= 64'h0000800080000000 &&
                granted_masters_adr_i <  64'h0000800080000400)
                // RAM
                selected_slave <= 3;
            else
            if (granted_masters_adr_i >= 64'h0000800100000000 &&
                granted_masters_adr_i <  64'h0000800100400000)
                // SYSCON
                selected_slave <= 2;
            else
            if (granted_masters_adr_i >= 64'h0000801000000000 &&
                granted_masters_adr_i <  64'h0000801000000400)
                // UART
                selected_slave <= 0;
            else
                selected_slave <= 0;
        end
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            state <= `STATE_WAIT_FOR_BUS_CLAIM;
            grant <= 0;
        end else begin
            case (state)
                `STATE_WAIT_FOR_BUS_CLAIM: begin
                    // reduction OR - check if at least one bit is set
                    if (|m2i_cyc_i) begin
                        found_next_master = 0;
                        // find the next right-most bit, starting from 'grant' bit
                        i = grant;
                        for (n = 0; n < MASTERS_NUM && !found_next_master; n = n + 1) begin
                            if (m2i_cyc_i[i]) begin
                                found_next_master = 1;
                                state <= `STATE_WAIT_FOR_CYCLE_END;
                                grant <= i;
                            end

                            i = (i + 1) % MASTERS_NUM;
                        end
                    end
                end
                `STATE_WAIT_FOR_CYCLE_END: begin
                    if (~m2i_cyc_i[grant]) begin
                        state <= `STATE_WAIT_FOR_BUS_CLAIM;
                        grant <= (grant + 1) % MASTERS_NUM;
                    end
                end
            endcase
        end
    end

endmodule
