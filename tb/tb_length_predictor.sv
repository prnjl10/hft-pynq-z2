//-----------------------------------------------------------------------------
// tb_length_predictor.sv
// Unit testbench for the ITCH 5.0 Length Predictor
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_length_predictor;

    //------ DUT signals ------
    logic       clk;
    logic       rst_n;
    logic [7:0] data_in;
    logic       valid_in;
    logic [7:0] data_out;
    logic       valid_out;
    logic       body_valid;

    //------ Instantiate the DUT ------
    itch_length_predictor dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .data_in    (data_in),
        .valid_in   (valid_in),
        .data_out   (data_out),
        .valid_out  (valid_out),
        .body_valid (body_valid)
    );

    //------ Clock generation: 100 MHz ------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //------ Helper task: send one byte over one clock cycle ------
    task send_byte(input logic [7:0] b);
        @(negedge clk);
        data_in  = b;
        valid_in = 1'b1;
        @(posedge clk);
    endtask

    //------ Helper task: idle one cycle (valid_in = 0) ------
    task idle;
        @(negedge clk);
        valid_in = 1'b0;
        @(posedge clk);
    endtask

    //------ Continuous monitor: prints whenever any of these signals change ------
    initial begin
        $monitor("t=%0t  data_in=%h valid_in=%b | body_valid=%b",
                 $time, data_in, valid_in, body_valid);
    end

    //------ MAIN STIMULUS ------
    initial begin

        // 1. Initialize and assert reset
        data_in  = 8'h00;
        valid_in = 1'b0;
        rst_n    = 1'b0;
        repeat (3) @(posedge clk);

        // 2. Release reset
        rst_n = 1'b1;
        @(posedge clk);

        // 3. Send first message: length=12, then 12 body bytes
        $display("--- Sending message 1: length=12 ---");
        send_byte(8'h00);   // length high
        send_byte(8'h0C);   // length low (12)
        send_byte(8'h53);   // body byte 1 (could be anything)
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h0A);
        send_byte(8'h2E);
        send_byte(8'h74);
        send_byte(8'hD4);
        send_byte(8'h56);
        send_byte(8'hA0);
        send_byte(8'h4F);   // body byte 12 (last)

        // 4. Send second message back-to-back: length=8, then 8 body bytes
        $display("--- Sending message 2: length=8 ---");
        send_byte(8'h00);   // length high
        send_byte(8'h08);   // length low (8)
        send_byte(8'hAA);
        send_byte(8'hBB);
        send_byte(8'hCC);
        send_byte(8'hDD);
        send_byte(8'hEE);
        send_byte(8'hFF);
        send_byte(8'h11);
        send_byte(8'h22);   // body byte 8

        // 5. Drop idle for a few cycles
        $display("--- Idle for 3 cycles ---");
        idle;
        idle;
        idle;

        // 6. Done
        $display("--- Test complete ---");
        #20;
        $finish;
    end

endmodule