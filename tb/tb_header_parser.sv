//-----------------------------------------------------------------------------
// tb_header_parser.sv
// Unit testbench for the ITCH 5.0 Header Parser
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_header_parser;

logic clk;
logic rst_n;
logic [7:0] data_in;
logic valid_in;
logic body_valid_in;
logic [7:0] data_dec;
logic valid_S;
logic valid_A;
logic valid_F;
logic valid_E;
logic valid_X;
logic valid_D;
logic valid_U;
logic valid_P;

//Connecting DUT
itch_header_parser dut (.clk(clk), .rst_n(rst_n), .data_in(data_in), .valid_in(valid_in), .body_valid_in(body_valid_in), .data_dec(data_dec),
                         .valid_S(valid_S), .valid_A(valid_A), .valid_F(valid_F), .valid_E(valid_E), .valid_X(valid_X), .valid_D(valid_D), .valid_U(valid_U),
                         .valid_P(valid_P) );


task send_framing(input logic [7:0] b);
    @(negedge clk);
    data_in = b;
    valid_in = 1'b1;
    body_valid_in = 1'b0;
    @(posedge clk);
endtask

task send_body(input logic [7:0] b);
    @(negedge clk);
    data_in = b;
    valid_in = 1'b1;
    body_valid_in = 1'b1;
    @(posedge clk);
endtask

task idle;
    @(negedge clk);
    valid_in = 1'b0;
    body_valid_in = 1'b0;
    @(posedge clk);
endtask

initial begin
    // 1. Initialize and assert reset
        data_in  = 8'h00;
        valid_in = 1'b0;
        rst_n    = 1'b0;
        body_valid_in = 1'b0;
        repeat (3) @(posedge clk);

        // 2. Release reset
        rst_n = 1'b1;
        @(posedge clk);
        
        // 3. Send first message: 
        $display("--- Sending message 1 ---");
        send_framing(8'h00);   // length high
        send_framing(8'h0C);   // length low (12)
        send_body("S");   
        send_body(8'h17);
        send_body(8'h7);
        send_body(8'h26);
        
        $display("--- Sending message 2 ---");
        send_framing(8'h00);   // length high
        send_framing(8'h0C);   // length low (12)
        send_body("A");   
        send_body(8'h17);
        send_body(8'h7);
        send_body(8'h26);
        
        
        //4. Send second meassage:
        $display("--- Sending unkown type R message ---");
        send_framing(8'h00);   // length high
        send_framing(8'h0C);   // length low (12)
        send_body("R");   
        send_body(8'h10);
        send_body(8'h11);
        send_body(8'h2);
        
        //5. Idle cycles
        $display("--- Idle for 3 cycles ---");
        idle;
        idle;
        idle;
        
        //6. Finishing simulation
        $display("--- Test complete ---");
        #20;
        $finish;
        
end

initial begin 
    $monitor("t=%0t  in: data=%h valid=%b bv=%b | out: dec=%h vS=%b vA=%b vF=%b vE=%b vX=%b vD=%b vU=%b vP=%b",
         $time, data_in, valid_in, body_valid_in,data_dec, valid_S, valid_A, valid_F, valid_E, valid_X, valid_D, valid_U, valid_P);
end

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end




endmodule