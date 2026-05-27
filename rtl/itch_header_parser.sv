/*
Header Parser / Dispatcher (Block 2)

PURPOSE: The ITCH Header Parser routes incoming bytes from the Length Predictor 
to the matching per-type decoder by asserting one of 8 valid_X output signals 
(one per supported message type: S, A, F, E, X, D, U, P).

INPUTS:
- rst_n: synchronous active-low reset
- clk: clock (100 MHz target)
- data_in [7:0]: the 8-bit byte coming from the Length Predictor's data_out
- valid_in: the Length Predictor's valid_out, indicating data_in is meaningful 
  this cycle (vs. idle)
- body_valid_in: from the Length Predictor - HIGH when data_in is a message body
  byte, LOW when it's part of the 2-byte length-prefix framing or idle

OUTPUTS:
- data_dec [7:0]: the byte passed through to all 8 decoders. The data bus is 
  SHARED - every decoder sees the same bus. Routing is done by the valid_X 
  signals, not by having separate data buses.
- valid_S, valid_A, valid_F, valid_E, valid_X, valid_D, valid_U, valid_P: 
  one per decoder. At most one is HIGH at any cycle, indicating which decoder 
  should consume the current byte on data_dec.

INTERNAL STATE:
- FSM has 2 states:
    * WAIT_TYPE: the parser is between messages, waiting for body_valid_in to 
      rise, which marks the arrival of a new message's type byte.
    * ROUTE: the parser is currently routing a message's body bytes to the 
      decoder identified by current_type.
- State variables: `state` (the FF register) and `next_state` (the combinational 
  wire). Standard two-process FSM pattern.
- Register: `current_type [7:0]` - stores the latched type byte ('S', 'A', etc.) 
  so subsequent body bytes can be routed to the right decoder.

HOW IT WORKS:
On every clock cycle, the parser tracks whether it's waiting for a new body 
(WAIT_TYPE) or routing bytes within one (ROUTE). When body_valid_in rises in 
WAIT_TYPE, the byte arriving on data_in IS the message type byte - the parser 
asserts the matching valid_X for that cycle (so the type byte itself flows to 
the right decoder), latches data_in into current_type, and transitions to ROUTE. 
While in ROUTE, the parser keeps asserting the same valid_X (now driven by 
current_type) for every body byte. When body_valid_in falls (the body ended), 
the parser returns to WAIT_TYPE, ready for the next message.

DATA FLOW: 
Bytes arrive from the Length Predictor on data_in. Inside the block, data_dec 
is a pure passthrough of data_in (no transformation). The new annotations are 
the 8 valid_X outputs, each derived from a combination of the FSM state, 
body_valid_in, and either data_in (for the first body byte) or current_type 
(for subsequent body bytes). The annotated stream then fans out to all 8 
decoders downstream - but only one decoder pays attention at a time, based on 
which valid_X is asserted.

KEY DESIGN DECISIONS:
1. **2-state FSM.** Only two modes are needed: looking for the next type byte 
   (WAIT_TYPE) or routing a body in progress (ROUTE). Body boundaries are 
   already signaled by body_valid_in from the Length Predictor, so the parser 
   doesn't need to track body length itself.

2. **Broadcast data bus + per-decoder valid signals.** Instead of giving each 
   decoder its own data bus (8 separate buses, lots of routing), we share one 
   data bus and let each decoder watch its own valid signal. Cheaper in routing 
   area; one-hot valid pattern is natural for FPGA.

3. **Latch current_type instead of recomputing.** Once we identify the type at 
   the first body byte, we store it in current_type so we don't have to "remember" 
   data_in across cycles (it changes every cycle). This is the same shift-and-store 
   pattern used everywhere in stream-decoding hardware.

4. **Two-case valid_X expression.** Each valid_X has two conditions joined by OR - 
   one for WAIT_TYPE (compare against data_in) and one for ROUTE (compare against 
   current_type). The WAIT_TYPE case is needed because on the FIRST body byte, 
   current_type hasn't been latched yet (it'll be latched at the END of that 
   cycle's edge). Without this, the type byte itself wouldn't reach its decoder.

EDGE CASES:
- **Unknown type bytes.** If an unsupported type arrives (e.g., 'R' for Stock 
  Directory), no valid_X gets asserted, since none of the 8 letter comparisons 
  match. The body bytes flow through data_dec but no decoder consumes them - 
  effectively dropped. This is intentional for v1.

- **Idle cycles.** When valid_in is low, the Length Predictor doesn't assert 
  body_valid_in, so the parser stays put in its current state. No state 
  advance on idle.

- **Reset behavior.** On rst_n LOW, state forces to WAIT_TYPE and current_type 
  clears to 0x00. No valid_X gets asserted spuriously during reset.

- **Latency.** Zero pipeline stages added - outputs respond combinationally to 
  current state and inputs. Adding the block doesn't increase end-to-end latency.: ?
*/

module itch_header_parser (

    input logic rst_n, clk,
    input logic [7:0] data_in,
    input logic valid_in,
    input logic body_valid_in,
    
    output logic [7:0] data_dec,
    output logic valid_S, 
    output logic valid_A, 
    output logic valid_F, 
    output logic valid_E, 
    output logic valid_X, 
    output logic valid_D, 
    output logic valid_U, 
    output logic valid_P
);


typedef enum logic [0:0] {
    WAIT_TYPE,
    ROUTE
} state_t;

state_t state, next_state;

logic [7:0] current_type;


//ASSIGN SATEMENTS
assign data_dec = data_in;

assign valid_S = ((state == WAIT_TYPE) && body_valid_in && (data_in == "S")) || ((state == ROUTE) && body_valid_in && (current_type == "S"));
assign valid_A = ((state == WAIT_TYPE) && body_valid_in && (data_in == "A")) || ((state == ROUTE) && body_valid_in && (current_type == "A"));
assign valid_F = ((state == WAIT_TYPE) && body_valid_in && (data_in == "F")) || ((state == ROUTE) && body_valid_in && (current_type == "F"));
assign valid_E = ((state == WAIT_TYPE) && body_valid_in && (data_in == "E")) || ((state == ROUTE) && body_valid_in && (current_type == "E"));
assign valid_X = ((state == WAIT_TYPE) && body_valid_in && (data_in == "X")) || ((state == ROUTE) && body_valid_in && (current_type == "X"));
assign valid_D = ((state == WAIT_TYPE) && body_valid_in && (data_in == "D")) || ((state == ROUTE) && body_valid_in && (current_type == "D"));
assign valid_U = ((state == WAIT_TYPE) && body_valid_in && (data_in == "U")) || ((state == ROUTE) && body_valid_in && (current_type == "U"));
assign valid_P = ((state == WAIT_TYPE) && body_valid_in && (data_in == "P")) || ((state == ROUTE) && body_valid_in && (current_type == "P"));

//STATE REGISTER
always_ff @(posedge clk) begin
    if (!rst_n)
        state <= WAIT_TYPE;
    else
        state <= next_state; 
end


//NEXT STATE LOGIC

    
    /*
    1: FSM should tranisition from WAIT_TYPE to ROUTE after cycle 1 and cycle 2 when the length bytes are recieved, with body_valid_in being the signal to trigger the change.

2: The FSM transitions from ROUTE to WAIT_TYPE again after cycle 15 when the body_valid_bit transitions back to 0

3: At cycle 3, the dispatcher latches current_type = S at posedege

4: Valid_S should be high when current_type ==S and body_valid_in is 1
    */

always_comb begin
    next_state = state; //stay where we are

    case(state)
    
        WAIT_TYPE: begin 
            if (body_valid_in == 1)
                next_state = ROUTE;
        end
        
        ROUTE: begin
            if (body_valid_in == 0)
                next_state = WAIT_TYPE;
        end

    endcase
end


always_ff @(posedge clk)  begin

    if (!rst_n)
        current_type <= 8'h00;
    else if (state == WAIT_TYPE && body_valid_in == 1)
        current_type <= data_in;
        
end

endmodule 