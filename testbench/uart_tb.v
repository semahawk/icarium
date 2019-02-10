`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   20:17:20 02/09/2019
// Design Name:   uart
// Module Name:   /home/poliel/Code/fpga/icarium/testbench/uart_tb.v
// Project Name:  icarium
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: uart
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module uart_tb;

	// Inputs
	reg rst_i;
	reg clk_i;
	reg uart_rx;

	// Instantiate the Unit Under Test (UUT)
	uart uut (
		.rst_i(rst_i),
		.clk_i(clk_i),
		.uart_rx(uart_rx)
	);

	always begin
		#5 clk_i = ~clk_i;
	end

	initial begin
		// Initialize Inputs
		rst_i = 0;
		clk_i = 0;
		// put the RX into idle
		uart_rx = 1;

		// Wait 100 ns for global reset to finish
		#4340;

		// send an example byte of data to the receiver at 115200 baudrate
		// send the start bit
		#8680;
		uart_rx = 0;
		// start sending data
		#8680;
		uart_rx = 1;
		#8680;
		uart_rx = 0;
		#8680;
		uart_rx = 1;
		#8680;
		uart_rx = 0;
		#8680;
		uart_rx = 1;
		#8680;
		uart_rx = 0;
		#8680;
		uart_rx = 1;
		#8680;
		uart_rx = 0;
		// and the stop bit
		#8680;
		uart_rx = 1;
		// and the idle state
		#8680;
		uart_rx = 1;

		#1000;

		// send a second example byte
		// send the start bit
		#8680;
		uart_rx = 0;
		// start sending data
		#8680;
		uart_rx = 0;
		#8680;
		uart_rx = 0;
		#8680;
		uart_rx = 1;
		#8680;
		uart_rx = 1;
		#8680;
		uart_rx = 1;
		#8680;
		uart_rx = 1;
		#8680;
		uart_rx = 1;
		#8680;
		uart_rx = 1;
		// and the stop bit
		#8680;
		uart_rx = 1;
		// and the idle state
		#8680;
		uart_rx = 1;
	end

endmodule
