cd /c/projects/hft-pynq-z2/rtl
/*=============================================================================
 * itch_length_predictor.sv
 *
 * Block 1 of the ITCH 5.0 hardware decoder pipeline.
 *
 * Watches the incoming byte stream and asserts `body_valid` for exactly the
 * bytes that are message-body content (not the 2-byte length prefix framing).
 *
 * Stream layout:
 *     [LEN_HI] [LEN_LO] [body1] [body2] ... [bodyN]   [LEN_HI] [LEN_LO] ...
 *
 * body_valid timing for a length=12 message:
 *     Cycle 1: data=LEN_HI    body_valid=0
 *     Cycle 2: data=LEN_LO    body_valid=0
 *     Cycle 3: data=body1     body_valid=1
 *     ...
 *     Cycle 14: data=body12   body_valid=1
 *     Cycle 15: (next message's LEN_HI) body_valid=0
 *
 * See: docs/phase1_rtl_architecture.md, Section 9
 *===========================================================================*/

module itch_length_predictor (
    input  logic       clk,
    input  logic       rst_n,      // Active-low synchronous reset

    /* ----- INPUT stream (from DMA) ----- */
    input  logic [7:0] data_in,    // One byte per cycle
    input  logic       valid_in,   // Is this byte real, or just idle?

    /* ----- OUTPUT stream (to dispatcher) ----- */
    output logic [7:0] data_out,   // Byte passed through
    output logic       valid_out,  // Valid passed through
    output logic       body_valid  // NEW: 1=body data, 0=framing
);

    /*-------------------------------------------------------------------------
     * FSM STATE DECLARATION
     *
     * We have three possible modes. `state_t` is a named 2-bit type so we can
     * write `state == WAIT_LEN_HI` instead of `state == 2'b00`. The compiler
     * picks the bit encoding automatically (00, 01, 10).
     *-----------------------------------------------------------------------*/
    typedef enum logic [1:0] {
        WAIT_LEN_HI,  // Expecting upper byte of a length prefix
        WAIT_LEN_LO,  // Expecting lower byte of a length prefix
        STREAM_BODY   // Streaming body bytes through; counter is active
    } state_t;

    /*-------------------------------------------------------------------------
     * Two variables of state_t — read carefully:
     *
     *   state       = the actual FLIP-FLOP. Stores the current mode.
     *                 Only changes at clock edges (sequential).
     *
     *   next_state  = a pure WIRE. Continuously computes "what state should
     *                 we be in next cycle?" based on current state + inputs.
     *                 Changes the instant any input changes (combinational).
     *
     * The two-variable pattern is the standard "two-process FSM" style:
     *   - One always_comb computes next_state from current state + inputs.
     *   - One always_ff copies next_state into state on the clock edge.
     *-----------------------------------------------------------------------*/
    state_t state, next_state;

    /*-------------------------------------------------------------------------
     * INTERNAL REGISTERS
     *
     * These store extra data beyond the FSM state.
     *-----------------------------------------------------------------------*/
    logic [15:0] length_reg;
    /* length_reg: where we assemble the 16-bit length byte-by-byte as it
     * arrives. After both length bytes arrive, this holds the full length. */

    logic [15:0] bytes_remaining;
    /* bytes_remaining: countdown counter. Loaded with the message length
     * when entering STREAM_BODY. Each valid body byte decrements it by 1.
     * When it reaches 1 on the last body byte, we know the message ends. */

    /*=========================================================================
     * OUTPUT BLOCK 1: Pass-throughs (pure wires)
     *
     * Continuous assignments. No clock, no flip-flop. The output value tracks
     * the input value at all times, with effectively zero delay.
     *=======================================================================*/
    assign data_out  = data_in;
    assign valid_out = valid_in;

    /*=========================================================================
     * OUTPUT BLOCK 2: body_valid (also a pure wire — combinational)
     *
     * body_valid is HIGH whenever BOTH of these are true RIGHT NOW:
     *   - The FSM is currently in the STREAM_BODY state, AND
     *   - The current incoming byte is valid (valid_in = 1).
     *
     * time. The moment `state` becomes STREAM_BODY (at a clock edge),
    assign body_valid = (state == STREAM_BODY) && valid_in;

    /*=========================================================================
     * at posedge clk.
     *
     *
     * After this edge:
     *   - state has its new value
     *   - everything combinational that depends on state immediately
     *     re-evaluates (including body_valid and the next_state computation)
     *=======================================================================*/
    always_ff @(posedge clk) begin
        if (!rst_n)
            state <= WAIT_LEN_HI;   // Reset behavior
        else
            state <= next_state;    // Normal: advance per combo logic
    end

    /*=========================================================================
     * COMBINATIONAL BLOCK 1: Next-state logic
     *
     * Pure logic — no clock, no flip-flop. It continuously computes what
     * `next_state` should be, as a function of the current state and the
     * current input signals. Re-evaluates instantly whenever inputs change.
     *
     * The default at the top says "if nothing else applies, stay in the
     * current state." Then the case statement adds the transition rules.
     *
     * Every transition is GATED by `valid_in`. If no valid byte arrives this
     * cycle, we stay put — we don't advance the FSM on idle cycles.
     *=======================================================================*/
    always_comb begin
        next_state = state;  // Default: stay where we are

        case (state)

            /*-----------------------------------------------------------------
             * Mode 1: WAIT_LEN_HI — waiting for the upper length byte.
             * When a valid byte arrives, advance to wait for the lower byte.
             *---------------------------------------------------------------*/
            WAIT_LEN_HI: begin
                if (valid_in) next_state = WAIT_LEN_LO;
            end

            /*-----------------------------------------------------------------
             * Mode 2: WAIT_LEN_LO — waiting for the lower length byte.
             * When a valid byte arrives, we have the full length, so advance
             * to streaming the body bytes.
             *---------------------------------------------------------------*/
            WAIT_LEN_LO: begin
                if (valid_in) next_state = STREAM_BODY;
            end

            /*-----------------------------------------------------------------
             * Mode 3: STREAM_BODY — streaming body bytes.
             * Stay here on every valid body byte. When the countdown hits 1
             * and another valid byte arrives (= the LAST body byte), the
             * message is ending — go back to waiting for the next message.
             *---------------------------------------------------------------*/
            STREAM_BODY: begin
                if (valid_in && (bytes_remaining == 16'd1))
                    next_state = WAIT_LEN_HI;
            end

        endcase
    end

    /*=========================================================================
     * SEQUENTIAL BLOCK 2: The data registers (length_reg + bytes_remaining)
     *
     * Also flip-flops, updating at posedge clk. They only do anything when a
     * valid byte is arriving (valid_in = 1).
     *
     * What happens at each clock edge:
     *
     *   STATE = WAIT_LEN_HI:
     *     Capture the incoming byte as the UPPER half of length_reg.
     *     (Lower half remains whatever it was — we'll overwrite next cycle.)
     *
     *   STATE = WAIT_LEN_LO:
     *     Capture the incoming byte as the LOWER half of length_reg.
     *     Simultaneously load bytes_remaining with the full length.
     *
     *     IMPORTANT: We can't just write `bytes_remaining <= length_reg;`
     *     here. Because of non-blocking assignment semantics, both lines in
     *     this block evaluate their right-hand sides using the OLD value of
     *     length_reg (the new lower byte hasn't been latched yet).
     *
     *     So we manually construct the new full length value as:
     *         { existing upper byte, current data_in }
     *
     *   STATE = STREAM_BODY:
     *     Decrement bytes_remaining (as long as it's still > 0). This counter
     *     was loaded with the length when we entered STREAM_BODY, and ticks
     *     down once per valid body byte.
     *=======================================================================*/
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            /* Reset: clear both registers */
            length_reg      <= 16'd0;
            bytes_remaining <= 16'd0;

        end else if (valid_in) begin
            /* Only update when a real byte is arriving */
            case (state)

                WAIT_LEN_HI: begin
                    /* First length byte → save as upper half of length_reg */
                    length_reg[15:8] <= data_in;
                end

                WAIT_LEN_LO: begin
                    /* Second length byte → save as lower half of length_reg.
                     * ALSO load the countdown counter with the full length.
                     *
                     * We can't read length_reg directly here (its lower byte
                     * hasn't been updated yet on this edge) — so we manually
                     * construct the value from:
                     *   length_reg[15:8] = already-stored upper byte
                     *   data_in          = currently-arriving lower byte */
                    length_reg[7:0] <= data_in;
                    bytes_remaining <= {length_reg[15:8], data_in};
                end

                STREAM_BODY: begin
                    /* Body byte arriving → decrement the counter by 1.
                     * Guard against underflow if counter is already 0
                     * (shouldn't happen in normal operation). */
                    if (bytes_remaining > 16'd0)
                        bytes_remaining <= bytes_remaining - 16'd1;
                end

            endcase
        end
    end

endmodule     * At every rising clock edge:
     *   - If reset is active (rst_n=0), force state to WAIT_LEN_HI
     *   - Otherwise, capture whatever next_state currently is
     * SEQUENTIAL BLOCK 1: The state register
     *
     * This is the actual flip-flop that holds the FSM state. It updates ONLY
     * body_valid goes HIGH in the same instant — aligned with the byte that
     * caused the transition. There is NO 1-cycle delay.
     *=======================================================================*/


