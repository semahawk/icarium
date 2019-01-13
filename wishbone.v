`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:23:18 01/10/2019 
// Design Name: 
// Module Name:    wishbone 
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

`ifndef __WISHBONE_V__
`define __WISHBONE_V__

`include "config.v"

`define WB_MASTER_PORT_SIGNALS(prefix) \
    output reg                  ``prefix``stb_o, \
    output reg                  ``prefix``cyc_o, \
    output reg                  ``prefix``we_o,  \
    output reg [`SEL_WIDTH-1:0] ``prefix``sel_o, \
    output reg [`ADR_WIDTH-1:0] ``prefix``adr_o, \
    output reg [`DAT_WIDTH-1:0] ``prefix``dat_o, \
    input      [`DAT_WIDTH-1:0] ``prefix``dat_i, \
    input                       ``prefix``ack_i, \
    input                       ``prefix``err_i

`define WB_MASTER_WIRE_SIGNALS(prefix) \
    wire                  ``prefix``stb_o; \
    wire                  ``prefix``cyc_o; \
    wire                  ``prefix``we_o;  \
    wire [`SEL_WIDTH-1:0] ``prefix``sel_o; \
    wire [`ADR_WIDTH-1:0] ``prefix``adr_o; \
    wire [`DAT_WIDTH-1:0] ``prefix``dat_o; \
    wire [`DAT_WIDTH-1:0] ``prefix``dat_i; \
    wire                  ``prefix``ack_i; \
    wire                  ``prefix``err_i

`define WB_SLAVE_PORT_SIGNALS(prefix) \
    input                   ``prefix``stb_i, \
    input                   ``prefix``cyc_i, \
    input                   ``prefix``we_i,  \
    input  [`SEL_WIDTH-1:0] ``prefix``sel_i, \
    input  [`ADR_WIDTH-1:0] ``prefix``adr_i, \
    input  [`DAT_WIDTH-1:0] ``prefix``dat_i, \
    output [`DAT_WIDTH-1:0] ``prefix``dat_o, \
    output                  ``prefix``ack_o, \
    output                  ``prefix``err_o

`define WB_SLAVE_WIRE_SIGNALS(prefix) \
    wire                  ``prefix``stb_i; \
    wire                  ``prefix``cyc_i; \
    wire                  ``prefix``we_i;  \
    wire [`SEL_WIDTH-1:0] ``prefix``sel_i; \
    wire [`ADR_WIDTH-1:0] ``prefix``adr_i; \
    wire [`DAT_WIDTH-1:0] ``prefix``dat_i; \
    wire [`DAT_WIDTH-1:0] ``prefix``dat_o; \
    wire                  ``prefix``ack_o; \
    wire                  ``prefix``err_o

`endif // __WISHBONE_V__
