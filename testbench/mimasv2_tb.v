`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   23:38:29 01/14/2019
// Design Name:   mimasv2
// Module Name:   /home/poliel/Code/fpga/icarium/testbench/mimasv2_tb.v
// Project Name:  icarium
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: mimasv2
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module mimasv2_tb;

	// Inputs
	reg Mv2_CLK;

	// Outputs
	wire [7:0] Mv2_LED;

	// Instantiate the Unit Under Test (UUT)
	mimasv2 uut (
		.Mv2_CLK(Mv2_CLK),
		.Mv2_LED(Mv2_LED)
	);

	always begin
		#5 Mv2_CLK = ~Mv2_CLK;
	end

	initial begin
		// Initialize Inputs
		Mv2_CLK = 0;

		// Wait 100 ns for global reset to finish
		#100;

		// Add stimulus here
		#2000;
	end

endmodule

