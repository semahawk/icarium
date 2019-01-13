`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:48:12 01/10/2019 
// Design Name: 
// Module Name:    soc 
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

module soc (
    input soc_rst_i,
    input soc_clk_i
);

    `WB_MASTER_WIRE_SIGNALS(cpu_);
    `WB_SLAVE_WIRE_SIGNALS(rom_);
    `WB_SLAVE_WIRE_SIGNALS(uart_);

    // shared data input wires for all the masters
    wire [`DAT_WIDTH-1:0] masters_dat_i;

    // signals shared across all slaves
    wire slave_cyc_i;
    wire [`ADR_WIDTH-1:0] slave_adr_i;
    wire [`DAT_WIDTH-1:0] slave_dat_i;
    wire [`SEL_WIDTH-1:0] slave_sel_i;
    wire slave_we_i;

    cpu cpu (
        .rst_i(soc_rst_i),
        .clk_i(soc_clk_i),
        .cpu_stb_o(cpu_stb_o),
        .cpu_cyc_o(cpu_cyc_o),
        .cpu_we_o(cpu_we_o),
        .cpu_sel_o(cpu_sel_o),
        .cpu_adr_o(cpu_adr_o),
        .cpu_dat_o(cpu_dat_o),
        .cpu_dat_i(masters_dat_i),
        .cpu_ack_i(cpu_ack_i),
        .cpu_err_i(cpu_err_i)
    );

    intercon #(
        .MASTERS_NUM(1),
        .SLAVES_NUM(2)
    ) intercon (
        .rst_i(soc_rst_i),
        .clk_i(soc_clk_i),
        .m2i_cyc_i({ cpu_cyc_o }),
        .m2i_stb_i({ cpu_stb_o }),
        .m2i_we_i({ cpu_we_o }),
        .m2i_adr_i({ cpu_adr_o }),
        .m2i_dat_i({ cpu_dat_o }),
        .m2i_sel_i({ cpu_sel_o }),
        .i2m_ack_o({ cpu_ack_i }),
        .i2m_err_o({ cpu_err_i }),
        .i2m_dat_o({ masters_dat_i }),
        .s2i_ack_i({ rom_ack_o, uart_ack_o }),
        .s2i_err_i({ rom_err_o, uart_err_o }),
        .s2i_dat_i({ rom_dat_o, uart_dat_o }),
        .i2s_stb_o({ rom_stb_i, uart_stb_i }),
        .i2s_cyc_o({ slave_cyc_i }),
        .i2s_adr_o({ slave_adr_i }),
        .i2s_dat_o({ slave_dat_i }),
        .i2s_sel_o({ slave_sel_i }),
        .i2s_we_o({ slave_we_i })
    );

    rom #(
        .INSTRUCTIONS(8)
    ) rom (
        .rst_i(soc_rst_i),
        .clk_i(soc_clk_i),
        .rom_stb_i(rom_stb_i),
        .rom_cyc_i(slave_cyc_i),
        .rom_we_i(slave_we_i),
        .rom_sel_i(slave_sel_i),
        .rom_adr_i(slave_adr_i),
        .rom_dat_i(slave_dat_i),
        .rom_dat_o(rom_dat_o),
        .rom_ack_o(rom_ack_o),
        .rom_err_o(rom_err_o)
    );

    uart uart (
        .rst_i(soc_rst_i),
        .clk_i(soc_clk_i),
        .uart_stb_i(uart_stb_i),
        .uart_cyc_i(slave_cyc_i),
        .uart_we_i(slave_we_i),
        .uart_sel_i(slave_sel_i),
        .uart_adr_i(slave_adr_i),
        .uart_dat_i(slave_dat_i),
        .uart_dat_o(uart_dat_o),
        .uart_ack_o(uart_ack_o),
        .uart_err_o(uart_err_o)
    );

endmodule
