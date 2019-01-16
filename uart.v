`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:12:27 01/10/2019 
// Design Name: 
// Module Name:    uart 
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

`define STATE_TX_IDLE       0
`define STATE_TX_SEND_DATA  1
`define STATE_TX_SEND_STOP  2

module uart (
    input rst_i,
    input clk_i,

    `WB_SLAVE_PORT_SIGNALS(uart_),

    output [7:0] uart_out,

    // the actual signals going in/out of the peripheral
    output uart_tx
);

    // Wishbone signals
    reg [`DAT_WIDTH-1:0] r_dat_i;
    reg [`DAT_WIDTH-1:0] r_dat_o;
    reg r_ack = 1'h0;
    reg r_err = 1'h0;

    // internal state of the transmitter
    reg [4:0] uart_tx_state = `STATE_TX_IDLE;
    // the data-to-be-sent will be latched into this shift-register
    reg [7:0] uart_tx_buf = 8'h0;
    // index of the next bit to be sent
    reg [3:0] uart_tx_bit_idx = 4'h0;
    // this is the divided clock which the transmitter uses
    reg uart_tx_baud_clk = 1'd0;
    // increments on every clk_i, resets down to zero after every 9600 clocks
    reg [31:0] uart_tx_baud_counter = 32'd0;
    // used for synchronization between the control and the transmit parts
    reg uart_tx_transmitting_data = 1'd0;
    reg uart_tx_start = 1'd0;
    // signals going in/out of the peripheral
    reg r_uart_tx = 1'd1;

    reg [4:0] tx_wait_clocks = 4'd10;

    reg [7:0] r_uart_out;

    // Wishbone signals
    assign uart_ack_o = uart_stb_i ? r_ack : 1'b0;
    assign uart_err_o = uart_stb_i ? r_err : 1'b0;
    assign uart_dat_o = r_dat_o;
    // the actual signals going in/out of the peripheral
    assign uart_tx = uart_tx_state == `STATE_TX_IDLE ? 1'h1 : r_uart_tx;
    // just some debug output
    assign uart_out = r_uart_out;

    // tx baud-clock generation logic
    always @(posedge clk_i) begin
        if (rst_i) begin
            uart_tx_baud_clk <= 1'h0;
            uart_tx_baud_counter <= 32'h0;
        end else begin
            // 100MHz reference input clock / 115200 baudrate = 868
            // but the clock needs to toggle twice as fast
            if (uart_tx_baud_counter < (868 / 2) - 1) begin
                uart_tx_baud_counter <= uart_tx_baud_counter + 1;
            end else begin
                uart_tx_baud_counter <= 32'h0;
                uart_tx_baud_clk <= ~uart_tx_baud_clk;
            end
        end
    end

    // the control block
    always @(posedge clk_i) begin
        if (rst_i) begin
            r_ack <= 1'b0;
            r_err <= 1'b0;
            r_dat_o <= 64'hdeadbabe;
        end else begin
            if (uart_stb_i) begin
                r_ack <= 1'b1;
                r_err <= 1'b0;

                if (uart_we_i) begin
                    if (!uart_tx_transmitting_data) begin
                        // trigger the transmitter to actuall start transmitting
                        uart_tx_start <= 1'd1;
                        // latch in the data to be sent
                        uart_tx_buf <= uart_dat_i[7:0];
                        // also this thing
                        r_uart_out <= uart_dat_i[7:0];
                    end
                end
            end

            if (uart_tx_state == `STATE_TX_SEND_DATA)
                // we have to disable the tx trigger, so it doesn't
                // continuously send the same byte over and over
                uart_tx_start <= 1'd0;
        end
    end

    // the transmit block
    always @(posedge uart_tx_baud_clk) begin
        case (uart_tx_state)
            `STATE_TX_IDLE: begin
                if (tx_wait_clocks > 0) begin
                    tx_wait_clocks <= tx_wait_clocks - 1;
                end else begin
                    if (uart_tx_start) begin
                        uart_tx_state <= `STATE_TX_SEND_DATA;
                        // output the start bit
                        r_uart_tx <= 1'h0;
                        uart_tx_transmitting_data <= 1'd1;
                        uart_tx_bit_idx <= 4'h0;
                    end else begin
                        // output high when idle
                        r_uart_tx <= 1'h1;
                    end
                end
            end // `STATE_TX_IDLE
            `STATE_TX_SEND_DATA: begin
                if (uart_tx_bit_idx < 8) begin
                    r_uart_tx <= uart_tx_buf[uart_tx_bit_idx+:1];
                    uart_tx_bit_idx <= uart_tx_bit_idx + 1;
                end else begin
                    uart_tx_state <= `STATE_TX_SEND_STOP;
                    // send the first (and only?) stop bit
                    r_uart_tx <= 1'h1;
                end
            end // `STATE_TX_SEND_DATA
            `STATE_TX_SEND_STOP: begin
                // just let the stop bit clock in
                uart_tx_state <= `STATE_TX_IDLE;
                uart_tx_transmitting_data <= 1'd0;
            end // `STATE_TX_SEND_STOP
        endcase
    end

endmodule
