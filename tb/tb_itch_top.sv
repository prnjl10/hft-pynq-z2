`timescale 1ns/1ps

module tb_itch_top;

    logic clk;
    logic rst_n;
    logic [7:0] data_in;
    logic valid_in;
    
    // ???? Message type counters ????
    integer cnt_S = 0, cnt_A = 0, cnt_F = 0, cnt_E = 0;
    integer cnt_X = 0, cnt_D = 0, cnt_U = 0, cnt_P = 0;
    
    // S decoder (5 outputs)
    logic [15:0] s_stock_locate;
    logic [15:0] s_tracking_number;
    logic [47:0] s_timestamp;
    logic [7:0]  s_event_code;
    logic        s_decoded_valid;

    // A decoder (9 outputs)
    logic [15:0] a_stock_locate;
    logic [15:0] a_tracking_number;
    logic [47:0] a_timestamp;
    logic [63:0] a_order_ref_num;
    logic [7:0]  a_buy_sell;
    logic [31:0] a_shares;
    logic [63:0] a_stock;
    logic [31:0] a_price;
    logic        a_decoded_valid;

    // F decoder (10 outputs)
    logic [15:0] f_stock_locate;
    logic [15:0] f_tracking_number;
    logic [47:0] f_timestamp;
    logic [63:0] f_order_ref_num;
    logic [7:0]  f_buy_sell;
    logic [31:0] f_shares;
    logic [63:0] f_stock;
    logic [31:0] f_price;
    logic [31:0] f_attribution;
    logic        f_decoded_valid;

    // E decoder (7 outputs)
    logic [15:0] e_stock_locate;
    logic [15:0] e_tracking_number;
    logic [47:0] e_timestamp;
    logic [63:0] e_order_ref_num;
    logic [31:0] e_executed_shares;
    logic [63:0] e_match_number;
    logic        e_decoded_valid;

    // X decoder (6 outputs)
    logic [15:0] x_stock_locate;
    logic [15:0] x_tracking_number;
    logic [47:0] x_timestamp;
    logic [63:0] x_order_ref_num;
    logic [31:0] x_cancelled_shares;
    logic        x_decoded_valid;

    // D decoder (5 outputs)
    logic [15:0] d_stock_locate;
    logic [15:0] d_tracking_number;
    logic [47:0] d_timestamp;
    logic [63:0] d_order_ref_num;
    logic        d_decoded_valid;

    // U decoder (8 outputs)
    logic [15:0] u_stock_locate;
    logic [15:0] u_tracking_number;
    logic [47:0] u_timestamp;
    logic [63:0] u_original_order_ref;
    logic [63:0] u_new_order_ref;
    logic [31:0] u_shares;
    logic [31:0] u_price;
    logic        u_decoded_valid;

    // P decoder (10 outputs)
    logic [15:0] p_stock_locate;
    logic [15:0] p_tracking_number;
    logic [47:0] p_timestamp;
    logic [63:0] p_order_ref_num;
    logic [7:0]  p_buy_sell;
    logic [31:0] p_shares;
    logic [63:0] p_stock;
    logic [31:0] p_price;
    logic [63:0] p_match_number;
    logic        p_decoded_valid;
    
    itch_top dut (
    .clk                (clk),
    .rst_n              (rst_n),
    .data_in            (data_in),
    .valid_in           (valid_in),
     
     // S decoder (5 outputs)
    .s_stock_locate     (s_stock_locate),
    .s_tracking_number  (s_tracking_number),
    .s_timestamp        (s_timestamp),
    .s_event_code       (s_event_code),
    .s_decoded_valid    (s_decoded_valid),
    
    // A decoder (9 outputs)
    .a_stock_locate     (a_stock_locate),
    .a_tracking_number  (a_tracking_number),
    .a_timestamp        (a_timestamp),
    .a_order_ref_num    (a_order_ref_num),
    .a_buy_sell         (a_buy_sell),
    .a_shares           (a_shares),
    .a_stock            (a_stock),
    .a_price            (a_price),
    .a_decoded_valid    (a_decoded_valid),
    
    // F decoder (10 outputs)
    .f_stock_locate     (f_stock_locate),
    .f_tracking_number  (f_tracking_number),
    .f_timestamp        (f_timestamp),
    .f_order_ref_num    (f_order_ref_num),
    .f_buy_sell         (f_buy_sell),
    .f_shares           (f_shares),
    .f_stock            (f_stock),
    .f_price            (f_price),
    .f_attribution      (f_attribution),
    .f_decoded_valid    (f_decoded_valid),
    
    // E decoder (7 outputs)
    .e_stock_locate     (e_stock_locate),
    .e_tracking_number  (e_tracking_number),
    .e_timestamp        (e_timestamp),
    .e_order_ref_num    (e_order_ref_num),
    .e_executed_shares  (e_executed_shares),
    .e_match_number     (e_match_number),
    .e_decoded_valid    (e_decoded_valid),
    
    // X decoder (6 outputs)
    .x_stock_locate     (x_stock_locate),
    .x_tracking_number  (x_tracking_number),
    .x_timestamp        (x_timestamp),
    .x_order_ref_num    (x_order_ref_num),
    .x_cancelled_shares (x_cancelled_shares),
    .x_decoded_valid    (x_decoded_valid),
    
    // D decoder (5 outputs)
    .d_stock_locate     (d_stock_locate),
    .d_tracking_number  (d_tracking_number),
    .d_timestamp        (d_timestamp),
    .d_order_ref_num    (d_order_ref_num),
    .d_decoded_valid    (d_decoded_valid),
    
    // U decoder (8 outputs)
    .u_stock_locate     (u_stock_locate),
    .u_tracking_number  (u_tracking_number),
    .u_timestamp        (u_timestamp),
    .u_original_order_ref(u_original_order_ref),
    .u_new_order_ref    (u_new_order_ref),
    .u_shares           (u_shares),
    .u_price            (u_price),
    .u_decoded_valid    (u_decoded_valid),
    
    // P decoder (10 outputs)
    .p_stock_locate     (p_stock_locate),
    .p_tracking_number  (p_tracking_number),
    .p_timestamp        (p_timestamp),
    .p_order_ref_num    (p_order_ref_num),
    .p_buy_sell         (p_buy_sell),
    .p_shares           (p_shares),
    .p_stock            (p_stock),
    .p_price            (p_price),
    .p_match_number     (p_match_number),
    .p_decoded_valid    (p_decoded_valid)
    );
    
    task send_byte(input logic [7:0] b);
        @(negedge clk);
        data_in = b;
        valid_in = 1'b1;
        @(posedge clk);
    endtask
    
    task idle();
        @(negedge clk)
        valid_in = 1'b0;
        @(posedge clk);
    endtask
    
    // ???? Monitor blocks (now also count) ????
    
    always @(posedge clk) begin
        if (s_decoded_valid) begin
            cnt_S = cnt_S + 1;
            // Uncomment next line if you want every S message printed
            // $display("[%0t] S decoded: stock_locate=%h tracking=%h timestamp=%h event_code=%h",$time, s_stock_locate, s_tracking_number, s_timestamp, s_event_code);
        end
    end
    
    always @(posedge clk) begin
        if (a_decoded_valid) begin
            cnt_A = cnt_A + 1;
            // $display("[%0t] A decoded: stock_locate=%h tracking=%h timestamp=%h order_ref_num=%h buy_sell=%h shares=%h stock=%h price=%h",$time, a_stock_locate, a_tracking_number, a_timestamp, a_order_ref_num, a_buy_sell, a_shares, a_stock, a_price);
        end
    end
    
    always @(posedge clk) begin
        if (f_decoded_valid) begin
            cnt_F = cnt_F + 1;
            // $display("[%0t] F decoded: stock_locate=%h tracking=%h timestamp=%h order_ref_num=%h buy_sell=%h shares=%h stock=%h price=%h attribution=%h",$time, f_stock_locate, f_tracking_number, f_timestamp, f_order_ref_num, f_buy_sell, f_shares, f_stock, f_price, f_attribution);
        end
    end
    
    always @(posedge clk) begin
        if (e_decoded_valid) begin
            cnt_E = cnt_E + 1;
            // $display("[%0t] E decoded: stock_locate=%h tracking=%h timestamp=%h order_ref_num=%h executed_shares=%h match_number=%h",$time, e_stock_locate, e_tracking_number, e_timestamp, e_order_ref_num, e_executed_shares, e_match_number);
        end
    end
    
    always @(posedge clk) begin
        if (x_decoded_valid) begin
            cnt_X = cnt_X + 1;
            // $display("[%0t] X decoded: stock_locate=%h tracking=%h timestamp=%h order_ref_num=%h cancelled_shares=%h",$time, x_stock_locate, x_tracking_number, x_timestamp, x_order_ref_num, x_cancelled_shares);
        end
    end
    
    always @(posedge clk) begin
        if (d_decoded_valid) begin
            cnt_D = cnt_D + 1;
            // $display("[%0t] D decoded: stock_locate=%h tracking=%h timestamp=%h order_ref_num=%h",$time, d_stock_locate, d_tracking_number, d_timestamp, d_order_ref_num);
        end
    end
    
    always @(posedge clk) begin
        if (u_decoded_valid) begin
            cnt_U = cnt_U + 1;
            // $display("[%0t] U decoded: stock_locate=%h tracking=%h timestamp=%h original_order_ref=%h new_order_ref=%h shares=%h price=%h",$time, u_stock_locate, u_tracking_number, u_timestamp, u_original_order_ref, u_new_order_ref, u_shares, u_price);
        end
    end
    
    always @(posedge clk) begin
        if (p_decoded_valid) begin
            cnt_P = cnt_P + 1;
            // $display("[%0t] P decoded: stock_locate=%h tracking=%h timestamp=%h order_ref_num=%h buy_sell=%h shares=%h stock=%h price=%h match_number=%h",$time, p_stock_locate, p_tracking_number, p_timestamp, p_order_ref_num, p_buy_sell, p_shares, p_stock, p_price, p_match_number);
        end
    end

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        // 1. Declare variables
        integer fd;              // file descriptor returned by $fopen
        integer r;               // return value from $fread (bytes read; 0 if EOF)
        integer msg_count;       // counts messages processed
        integer i;               // loop index for body bytes
        logic [7:0] len_hi;      // first length byte (high)
        logic [7:0] len_lo;      // second length byte (low)
        logic [15:0] msg_len;    // 16-bit message length
        logic [7:0] byte_buf;    // single byte buffer for $fread

        // 2. Initialize and assert reset
        data_in  = 8'h00;
        valid_in = 1'b0;
        rst_n    = 1'b0;
        repeat (3) @(posedge clk);

        // 3. Release reset
        rst_n = 1'b1;
        @(posedge clk);

        // 4. Open the decompressed ITCH file (binary read mode)
        fd = $fopen("C:/projects/hft-pynq-z2/data/20190730.BX_ITCH_50", "rb");
        if (fd == 0) begin
            $display("ERROR: could not open ITCH file");
            $finish;
        end
        $display("--- ITCH file opened. Starting decode... ---");

        msg_count = 0;

        // 5. Main loop: read length prefix, then body bytes, for each message
        while (!$feof(fd) && msg_count < 50000) begin
            // 5a. Read the 2-byte length prefix
            r = $fread(len_hi, fd);
            if (r == 0) break;
            r = $fread(len_lo, fd);
            if (r == 0) break;

            msg_len = {len_hi, len_lo};

            // 5b. Forward the 2 framing bytes to the DUT
            send_byte(len_hi);
            send_byte(len_lo);

            // 5c. Read and forward msg_len body bytes
            for (i = 0; i < msg_len; i = i + 1) begin
                r = $fread(byte_buf, fd);
                if (r == 0) break;
                send_byte(byte_buf);
            end

            idle(); idle();
            msg_count = msg_count + 1;

            // Progress indicator every 5000 messages
            if (msg_count % 5000 == 0) begin
                $display("--- Processed %0d messages so far ---", msg_count);
            end
        end

        // 6. Wrap up
        $fclose(fd);
        $display("--- Processed %0d total messages ---", msg_count);
        repeat (10) idle();

        // 7. Print final summary
        $display("=== Message Type Counts ===");
        $display("  S (System Event)     = %0d", cnt_S);
        $display("  A (Add Order)        = %0d", cnt_A);
        $display("  F (Add Order MPID)   = %0d", cnt_F);
        $display("  E (Order Executed)   = %0d", cnt_E);
        $display("  X (Order Cancel)     = %0d", cnt_X);
        $display("  D (Order Delete)     = %0d", cnt_D);
        $display("  U (Order Replace)    = %0d", cnt_U);
        $display("  P (Trade)            = %0d", cnt_P);
        $display("  Total decoded        = %0d", cnt_S + cnt_A + cnt_F + cnt_E + cnt_X + cnt_D + cnt_U + cnt_P);
        $display("  Unsupported (R,H,L,...) = %0d", msg_count - (cnt_S + cnt_A + cnt_F + cnt_E + cnt_X + cnt_D + cnt_U + cnt_P));
        $display("--- Test complete ---");
        $finish;
    end

endmodule