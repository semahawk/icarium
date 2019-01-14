`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:   20:16:19 01/13/2019
// Design Name:   soc
// Module Name:   /home/poliel/Code/fpga/icarium/testbench/soc_tb.v
// Project Name:  icarium
// Target Device:
// Tool versions:
// Description:
//
// Verilog Test Fixture created by ISE for module: soc
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
////////////////////////////////////////////////////////////////////////////////

module soc_tb;

	// Inputs
	reg soc_rst_i;
	reg soc_clk_i;

	// Instantiate the Unit Under Test (UUT)
	soc uut (
		.soc_rst_i(soc_rst_i),
		.soc_clk_i(soc_clk_i)
	);

	always begin
		#10 soc_clk_i = ~soc_clk_i;
	end

	initial begin
		// Initialize Inputs
		soc_rst_i = 0;
		soc_clk_i = 0;

		// Wait 100 ns for global reset to finish
		#100;

		// Add stimulus here
		#1000;
	end

endmodule
