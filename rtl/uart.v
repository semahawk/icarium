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

`define UART_STAT 8'h00
`define UART_CTRL 8'h08
`define UART_DATA 8'h10

// states of the Wishbone slave
`define STATE_IDLE 0
`define STATE_WAIT_FOR_PHASE_END 1

// states of the receiver device
`define STATE_RX_IDLE       0
`define STATE_RX_RECV_DATA  1
`define STATE_RX_RECV_STOP  2

// states of the transmitter device
`define STATE_TX_IDLE       0
`define STATE_TX_SEND_DATA  1
`define STATE_TX_SEND_STOP  2

module uart (
    input rst_i,
    input clk_i,

    `WB_SLAVE_PORT_SIGNALS(uart_),

    output [7:0] uart_out,

    // the actual signals going in/out of the peripheral
    input uart_rx_i,
    output uart_tx_o
);

    // Wishbone signals
    reg [`DAT_WIDTH-1:0] r_dat_i;
    reg [`DAT_WIDTH-1:0] r_dat_o;
    reg r_ack = 1'h0;
    reg r_err = 1'h0;

    //
    // the device's registers
    //
    reg [`DAT_WIDTH-1:0] uart_ctrl;

    // internal state of the Wishbone slave
    reg [1:0] uart_state = `STATE_IDLE;


    //
    // receiver
    //
    // internal state of the receiver
    reg [4:0] uart_rx_state = `STATE_RX_IDLE;
    // this is the sampling clock of the receiver (32x the baudrate)
    // this is only used to detect the start bit
    reg uart_rx_sample_clk = 1'd0;
    // this is the clock which is used for sampling at 32x the baudrate
    reg [31:0] uart_rx_sample_counter = 32'd0;
    // this is the divided clock which the receiver uses to probe the characters with
    reg uart_rx_baud_clk = 1'd0;
    // increments on every clk_i, resets down to zero after every 115200 clocks
    reg [31:0] uart_rx_baud_counter = 32'd0;
    reg uart_rx_baud_is_running = 1'd0;
    // the receiver will store the data which it read right here
    reg [7:0] uart_rx_buf = 8'h0;
    // control signal to the receiver to start clocking in the data in uart_rx
    reg uart_rx_start = 1'b0;
    // index of the next bit to be sent
    reg [3:0] uart_rx_bit_idx = 4'h0;
    // indicates whether the receiver has sucessfully read a byte
    reg uart_rx_data_ready = 1'b0;
    reg uart_last_rx = 1'b1;

    //
    // transmitter
    //
    // internal state of the transmitter
    reg [4:0] uart_tx_state = `STATE_TX_IDLE;
    // this is the divided clock which the transmitter uses to send characters with
    reg uart_tx_baud_clk = 1'd0;
    // increments on every clk_i, resets down to zero after every 115200 clocks
    reg [31:0] uart_tx_baud_counter = 32'd0;
    // the data-to-be-sent will be latched into this shift-register
    reg [7:0] uart_tx_buf = 8'h0;
    // index of the next bit to be sent
    reg [3:0] uart_tx_bit_idx = 4'h0;
    reg uart_tx_start = 1'd0;
    // signals going in/out of the peripheral
    reg r_uart_tx = 1'd1;
    // used for synchronization between the control and the transmit parts
    wire uart_tx_transmitting_data;

    assign uart_tx_transmitting_data =
        (uart_tx_state != `STATE_TX_IDLE) || uart_tx_start ? 1'b1 : 1'b0;

    reg [7:0] r_uart_out;

    // Wishbone signals
    assign uart_ack_o = uart_stb_i ? r_ack : 1'b0;
    assign uart_err_o = uart_stb_i ? r_err : 1'b0;
    assign uart_dat_o = r_dat_o;
    // the actual signals going in/out of the peripheral
    assign uart_tx_o = uart_tx_state == `STATE_TX_IDLE ? 1'h1 : r_uart_tx;
    // just some debug output
    assign uart_out = r_uart_out;

    reg uart_rx_start_last;
    always @(posedge clk_i)
        uart_rx_start_last <= uart_rx_start;

    // baud-clock generation logic
    always @(posedge clk_i) begin
        if (rst_i) begin
            uart_rx_sample_clk <= 1'h0;
            uart_rx_sample_counter <= 32'h0;
            uart_rx_baud_clk <= 1'h0;
            uart_rx_baud_counter <= 32'h0;
            uart_rx_baud_is_running <= 1'd0;
            uart_tx_baud_clk <= 1'h0;
            uart_tx_baud_counter <= 32'h0;
        end else begin
            // 100MHz reference input clock / 115200 baudrate = 868
            // but the clock needs to toggle twice as fast
            // and we want to sample 32x
            if (uart_rx_sample_counter < (868 / 32 / 2) - 1) begin
                uart_rx_sample_counter <= uart_rx_sample_counter + 1;
            end else begin
                uart_rx_sample_counter <= 32'h0;
                uart_rx_sample_clk <= ~uart_rx_sample_clk;
            end

            // reset the receiver's baud clock every time we detect a start condition
            // this is to make sure that we sample each bit of every character
            // at known offsets (that we sample it in the middle of the bit)
            if (uart_rx_start_last == 1'b0 && uart_rx_start == 1'b1) begin
                // offset the clock so that the edge rises in the middle of
                // the received character
                // this is due to the fact that there is a small delay between
                // the time when start bit is transmitted by the other end,
                // and when it's detected by this receiver
                uart_rx_baud_counter <= 32'd64;
                uart_rx_baud_clk <= 1'd0;
                uart_rx_baud_is_running <= 1'd1;
            end else begin
                // TODO this clock is running even if it doesn't need to
                // eg. even if there was no start condition yet
                // it probably doesn't hurt, but it unnecessarily triggers the 'always'
                // block of the receiver
                if (uart_rx_baud_counter < (868 / 2) - 1) begin
                    uart_rx_baud_counter <= uart_rx_baud_counter + 1;
                end else begin
                    uart_rx_baud_counter <= 32'h0;
                    uart_rx_baud_clk <= ~uart_rx_baud_clk;
                end
            end

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

    // the control block (the Wishbone slave interface)
    always @(posedge clk_i) begin
        if (rst_i) begin
            r_ack <= 1'b0;
            r_err <= 1'b0;
            r_dat_o <= {`DAT_WIDTH{1'h0}};
        end else begin
            case (uart_state)
                `STATE_IDLE: begin
                    if (uart_stb_i) begin
                        uart_state <= `STATE_WAIT_FOR_PHASE_END;

                        r_ack <= 1'b1;
                        r_err <= 1'b0;

                        if (uart_we_i) begin
                            case (uart_adr_i[7:0])
                                `UART_STAT: begin
                                    // nop
                                    // writing to UART_STAT is ignored
                                end // `UART_STAT
                                `UART_CTRL: begin
                                    uart_ctrl <= uart_dat_i;
                                end // `UART_CTRL
                                `UART_DATA: begin
                                    if (!uart_tx_transmitting_data) begin
                                        // trigger the transmitter to actually start transmitting
                                        uart_tx_start <= 1'd1;
                                        // latch in the data to be sent
                                        uart_tx_buf <= uart_dat_i[7:0];
                                    end
                                end // `UART_DATA
                                default: begin
                                    // unknown register
                                    // assert err_o
                                    r_ack <= 1'b0;
                                    r_err <= 1'b1;
                                end
                            endcase
                        end else begin
                            case (uart_adr_i[7:0])
                                `UART_STAT: begin
                                    r_dat_o <= {
                                        {62{1'h0}},
                                        uart_rx_data_ready,
                                        uart_tx_transmitting_data
                                    };
                                end // `UART_STAT
                                `UART_CTRL: begin
                                    r_dat_o <= uart_ctrl;
                                end // `UART_CTRL
                                `UART_DATA: begin
                                    r_dat_o <= { {56{1'h0}}, uart_rx_buf };
                                end // `UART_DATA
                                default: begin
                                    // unknown register
                                    // assert err_o
                                    r_ack <= 1'b0;
                                    r_err <= 1'b1;
                                end
                            endcase
                        end
                    end
                end // `STATE_IDLE
                `STATE_WAIT_FOR_PHASE_END: begin
                    if (~uart_stb_i) begin
                        uart_state <= `STATE_IDLE;
                        r_ack <= 1'h0;
                        r_err <= 1'h0;
                    end
                end // `STATE_WAIT_FOR_PHASE_END
            endcase

            if (uart_tx_state != `STATE_TX_IDLE)
                // we have to disable the tx trigger, so it doesn't
                // continuously send the same byte over and over
                uart_tx_start <= 1'd0;
        end
    end

    reg r_uart_rx, r_uart_rx_0;

    always @(posedge uart_rx_sample_clk)
        r_uart_rx_0 <= uart_rx_i;
    always @(posedge uart_rx_sample_clk)
        r_uart_rx <= r_uart_rx_0;

    // the receiver's sampling block
    always @(posedge uart_rx_sample_clk) begin
        if (uart_last_rx == 1'b1 && r_uart_rx == 1'b0) begin
            uart_rx_start <= 1'b1;
        end

        uart_last_rx <= r_uart_rx;

        // reset the receiver start signal so it doesn't read continuously
        if (uart_rx_state != `STATE_RX_IDLE)
            uart_rx_start <= 1'b0;
    end

    // the receive block
    always @(posedge uart_rx_baud_clk) begin
        case (uart_rx_state)
            `STATE_RX_IDLE: begin
                if (uart_rx_start) begin
                    uart_rx_data_ready <= 1'b0;
                    uart_rx_state <= `STATE_RX_RECV_DATA;
                    uart_rx_bit_idx <= 4'h0;
                end
            end // `STATE_RX_IDLE
            `STATE_RX_RECV_DATA: begin
                if (uart_rx_bit_idx < 8) begin
                    uart_rx_bit_idx <= uart_rx_bit_idx + 1;
                    uart_rx_buf <= { r_uart_rx, uart_rx_buf[7:1] };
                end else begin
                    uart_rx_state <= `STATE_RX_RECV_STOP;
                end
            end // `STATE_RX_RECV_DATA
            `STATE_RX_RECV_STOP: begin
                // let the stop bit clock in
                // FIXME any sanity checking that the stop bit really was a 1?
                uart_rx_state <= `STATE_RX_IDLE;
                uart_rx_data_ready <= 1'b1;

                // this goes to the on-board LEDs
                // let's have some debug
                r_uart_out <= uart_rx_buf;
            end // `STATE_RX_RECV_STOP
        endcase
    end

    // the transmit block
    always @(posedge uart_tx_baud_clk) begin
        case (uart_tx_state)
            `STATE_TX_IDLE: begin
                if (uart_tx_start) begin
                    uart_tx_state <= `STATE_TX_SEND_DATA;
                    // output the start bit
                    r_uart_tx <= 1'h0;
                    uart_tx_bit_idx <= 4'h0;
                end else begin
                    // output high when idle
                    r_uart_tx <= 1'h1;
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
            end // `STATE_TX_SEND_STOP
        endcase
    end

endmodule
