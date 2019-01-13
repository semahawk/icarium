`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:   15:08:42 01/12/2019
// Design Name:   rom
// Module Name:   /home/poliel/Code/fpga/icarium/testbench/rom_tb.v
// Project Name:  icarium
// Target Device:
// Tool versions:
// Description:
//
// Verilog Test Fixture created by ISE for module: rom
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
////////////////////////////////////////////////////////////////////////////////

`include "wishbone.v"
`include "utils.v"

module rom_tb;

	// inputs
	reg rst_i;
	reg clk_i;
	reg stb_i;
	reg cyc_i;
	reg we_i;
	reg [7:0] sel_i;
	reg [63:0] adr_i;
	reg [63:0] dat_i;

	// outputs
	wire [63:0] dat_o;
	wire ack_o;
	wire err_o;

	// variables
	reg [31:0] i;

	// Instantiate the Unit Under Test (UUT)
	rom #(
		.INSTRUCTIONS(8)
	) uut (
		.rst_i(rst_i),
		.clk_i(clk_i),
		.stb_i(stb_i),
		.cyc_i(cyc_i),
		.we_i(we_i),
		.sel_i(sel_i),
		.adr_i(adr_i),
		.dat_i(dat_i),
		.dat_o(dat_o),
		.ack_o(ack_o),
		.err_o(err_o)
	);

	always begin
		#10 clk_i = ~clk_i;
	end

	initial begin
		// initialize Inputs
		rst_i = 0;
		clk_i = 0;
		stb_i = 0;
		cyc_i = 0;
		we_i = 0;
		sel_i = 8'hff;

		// wait 100 ns for global reset to finish
		#100;

		// reset the slave
		rst_i = 1;
		#100;
		rst_i = 0;

		adr_i = 64'h0;
		// read every address
		for (i = 0; i < 16; i = i + 1) begin
			@(posedge clk_i);

			// setup the inputs
			stb_i = 1;
			cyc_i = 1;

			@(posedge ack_o or posedge err_o);

			if (ack_o) begin
				$display("addr %04x -> %016x", adr_i, dat_o);
			end else begin
				$display("err reading addr %04x!", adr_i);
			end

			stb_i = 0;
			cyc_i = 0;

			adr_i = adr_i + (`DAT_WIDTH / 8);
		end

	end

endmodule
