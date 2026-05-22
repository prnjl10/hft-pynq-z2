# Phase 1 RTL Architecture — ITCH 5.0 Hardware Decoder

## Document scope

This document is the complete architectural specification for the Phase 1 SystemVerilog implementation of a NASDAQ ITCH 5.0 market-data decoder on the Xilinx Zynq-7020 (PYNQ-Z2). It captures both **what** we are building and **why** we made each design choice.

This document is the source of truth for the implementation. Any deviation discovered during coding should result in an update here.

## Project context

Phase 1 of a two-phase HFT system reference design. The full project arc:

- **Phase 1 (this document):** Pipelined RTL decoder for NASDAQ ITCH 5.0, packaged as a reusable AXI-Stream IP. Producing portfolio + paper foundation.
- **Phase 2 (separate proposal):** Hardware order book integrated with this decoder + ARM Cortex-A9 software baseline + quantitative HW vs SW benchmark. Submission target: IEEE FCCM, FPL, or FPT.

---

# Part 1 — Design Decisions and Rationale

Every architectural choice in this project was made deliberately. This section captures the reasoning so a reader (recruiter, reviewer, or future-you) can understand the engineering tradeoffs.

## 1. Strategic / scoping decisions

### 1.1 Why an HFT decoder on FPGA at all?

**Decision.** Build a low-latency, deterministic hardware decoder for a real market-data protocol on FPGA.

**Alternatives considered.**
- Software (CPU) ITCH parser: easy, but the goal isn't to demonstrate a parser — it's to demonstrate FPGA-accelerated protocol processing.
- GPU-based parser: completely unsuited (designed for throughput on big batches, not single-message latency).
- ASIC: too expensive and slow to develop for a portfolio project.

**Rationale.** HFT is the canonical domain where FPGA-style determinism wins decisively over CPUs:
- CPUs suffer non-deterministic latency from OS jitter, cache misses, branch mispredictions. Worst-case latency events cluster precisely during high-volatility market windows — when accuracy and speed matter most.
- GPUs trade latency for throughput; their kernel-launch overhead alone (microseconds) exceeds an FPGA's whole tick-to-trade path.
- FPGAs eliminate every CPU pain point — no OS, no caches, no branch predictor — and produce deterministic, cycle-counted behavior with parallel hardware.

This project's "story" — *latency is alpha; only FPGAs deliver deterministic low latency* — is what makes it interesting to recruiters and reviewers.

### 1.2 Phase 1 / Phase 2 split

**Decision.** Phase 1 = decoder only. Phase 2 = order book + benchmark + paper.

**Alternatives considered.**
- Build the entire system (decoder + book + strategy + benchmark) as one phase. Estimated 8–12 weeks.
- Build only the decoder, skip the paper. Faster but weaker portfolio.

**Rationale.** A two-phase split:
- Produces a usable artifact (the decoder + golden reference) after Phase 1, even if Phase 2 stalls.
- Gives a natural mid-project checkpoint and resume bullet.
- Keeps each phase tractable (~3 weeks Phase 1, ~5 weeks Phase 2).
- Aligns with how published FPGA papers are structured (sub-system contribution + integrated benchmark).

### 1.3 Sub-component focus vs full system

**Decision.** Phase 1 builds *only* the protocol decoder, not market makers / order books / risk checks.

**Alternatives considered.**
- Full HFT pipeline (decoder → book → strategy → order generator).
- Single sub-component (just decoder) with rigorous benchmarking — this option.
- Whole system but each block trivial.

**Rationale.** Resume / paper ROI considerations:
- A well-engineered single block with quantitative HW vs SW comparison is more publishable than a sprawling system with trivial blocks.
- Decoder + book is the part of HFT that's most cleanly FPGA-favorable. Strategy logic is software-friendly; including it dilutes the story.
- A novel decoder + benchmark hits two of the four "publishability angles" we identified (concrete metric of speedup + open educational artifact).

### 1.4 Realistic framing for PYNQ-Z2

**Decision.** Don't try to beat production HFT FPGAs on absolute latency. Frame the project as an *architectural demonstration* + *HW vs SW speedup* on accessible hardware.

**Alternatives considered.**
- Claim production-grade tick-to-trade latency numbers (impossible on PYNQ-Z2).
- Use a more expensive FPGA card (out of budget, raises barrier to reproducibility).

**Rationale.** The PYNQ-Z2 has structural limitations that make production-grade latency impossible:
- Its Ethernet port wires to the PS-side ARM, not directly to the PL. So bytes traverse ARM/Linux/DMA before reaching FPGA logic. This adds microseconds.
- Real HFT cards (e.g., Solarflare, AMD Alveo) route Ethernet straight into the PL via SFP+ transceivers.

By choosing to feed the decoder from **DDR via DMA** (rather than live Ethernet), we sidestep this limitation entirely and benchmark the *processing latency* of the PL design itself — which is what an architectural paper actually measures. The result generalizes: a decoder that processes one byte per cycle on a Zynq-7020 will process the same way on an Alveo, just at higher clock and connected to faster I/O.

## 2. Protocol and data decisions

### 2.1 NASDAQ ITCH 5.0

**Decision.** Use NASDAQ ITCH 5.0 as the target protocol.

**Alternatives considered.**
- NYSE OpenBook / Arca.
- IEX TOPS.
- A simplified or invented protocol.

**Rationale.**
- Public spec, publicly available sample data.
- The most widely-used protocol in academic FPGA-HFT papers — makes the project's results easily comparable.
- Binary format with mixed integer and ASCII fields — exercises every common decoder pattern.
- Spec is concise (8 message types we care about) and well-documented.

### 2.2 Nasdaq BX sample file vs Nasdaq main

**Decision.** Use the Nasdaq BX sample file (`20190730.BX_ITCH_50.gz`, ~391 MB compressed).

**Alternatives considered.**
- Nasdaq main exchange file (~4 GB compressed).
- Nasdaq PSX file.
- Synthetic test data.

**Rationale.**
- Nasdaq BX uses the *exact same* ITCH 5.0 protocol as Nasdaq main, but the files are smaller and process faster during development iteration.
- Public, free, and from a representative trading day (July 30 2019 — normal Tuesday, no special events).
- All 8 target message types appear in the file.

### 2.3 The 8 target message types

**Decision.** Decode `S`, `A`, `F`, `E`, `X`, `D`, `U`, `P`. Tally but don't decode `R`, `H`, `L`, `N`, `V`, `Y`, `I`, etc.

**Alternatives considered.**
- Decode all ~20 message types. Way more RTL.
- Decode only the most common 2–3.

**Rationale.** The chosen 8 cover the full *order lifecycle* needed for an order book in Phase 2:
- `S` (System Event) — session control.
- `A`, `F` (Add Order with/without MPID) — order insertion.
- `E`, `X` (Order Executed, Order Cancel) — partial modifications.
- `D` (Order Delete) — order removal.
- `U` (Order Replace) — atomic cancel-and-add.
- `P` (Trade non-cross) — non-order-book matches.

The skipped message types (Stock Directory, Trading Action, NOII, etc.) don't affect the order book; they're metadata or administrative. A Phase 1 decoder that handles the 8 listed types is functionally complete for downstream order book work in Phase 2.

### 2.4 Process the first 100,000 messages during development

**Decision.** Cap MAX_MESSAGES at 100,000 for daily iteration; uncapped for final verification.

**Rationale.** A full BX file has ~50 million messages. Iterating against the whole file for every code change is impractical. The first 100k messages cover all 8 target message types with realistic volume and finish in seconds.

## 3. Architecture decisions

### 3.1 Streaming pipeline pattern

**Decision.** Use a multi-stage pipeline where each stage processes one byte per cycle and forwards to the next.

**Alternatives considered.**
- Buffer the whole message in memory, then decode (mirrors the Python approach).
- Big single combinational block.

**Rationale.** The pipeline pattern is the canonical hardware design for stream processing:
- Different stages work on different messages simultaneously — once primed, the pipeline produces one decoded message per the time of its slowest stage, regardless of total path length.
- Throughput is independent of pipeline depth (latency = N cycles, throughput = 1 result per cycle).
- Each stage is small and verifiable in isolation.

Buffering would require multi-KB BRAM per channel and a large central state machine — wasteful and harder to verify.

### 3.2 Datapath width: 1 byte / cycle

**Decision.** The pipeline consumes 1 byte per clock cycle.

**Alternatives considered.**
- 8 bytes/cycle (64-bit, common AXI-Stream width).
- 64 bytes/cycle (production HFT, on much bigger chips).

**Rationale (the alignment problem).** Wider datapaths force a *byte aligner* at the input, because ITCH messages are variable length (12–44 bytes) and don't align to power-of-2 boundaries. With 8 bytes/cycle, one wide word can carry the tail of one message and the head of the next — requiring a barrel-shifter, alignment FIFO, and significantly more verification surface.

1 byte/cycle eliminates this complication entirely. Every byte is its own clean unit. The pipeline maps almost 1:1 to the Python parser.

**Cost.** Lower raw throughput:
- 100 MHz × 1 byte = 100 MB/s
- 125 MHz × 1 byte = 125 MB/s ≈ GigE line rate

For this project, that's fine — we're feeding from DDR via DMA, not from a 10/40 GbE wire, so the line-rate constraint doesn't bite. And we'll still demonstrate the architectural pattern and show massive HW vs SW speedup in Phase 2 (since the ARM Cortex-A9 SW baseline runs at ~1–2 MB/s anyway).

**Future work.** v2 could widen to 4 or 8 bytes/cycle with an alignment stage. Common pattern in published FPGA work: simple v1, optimized v2.

### 3.3 Clock target: 100 MHz initial, 150 MHz stretch

**Decision.** Design for 100 MHz timing closure initially. After functional correctness, tighten constraint toward 150 MHz with light pipelining.

**Alternatives considered.**
- 200 MHz from the start.
- 50 MHz for maximum safety.

**Rationale.** 100 MHz is well within easy timing closure for Zynq-7020. Any reasonable RTL closes the first time. This lets us focus on correctness, not fight the synthesis tools.

150 MHz is achievable with one register stage added between major blocks — modest additional engineering, real performance gain.

200 MHz requires aggressive pipelining (8–12 stages instead of 5–6) and is genuinely challenging on Zynq-7020. The development cost (2–5 extra days) isn't worth it for the throughput delta.

**This is also how real engineers work.** You don't pre-commit to a clock — you design with sensible practices and report the achieved Fmax.

### 3.4 Input source: DDR → DMA → PL (not Ethernet)

**Decision.** Feed the decoder from PS-side DDR memory via DMA, presented as an AXI-Stream into the PL.

**Alternatives considered.**
- Live Ethernet input on the PL side (impossible — PYNQ-Z2 wires Ethernet to the PS).
- Live Ethernet through PS, then forward to PL (adds ARM/Linux latency).

**Rationale.** Feeding from DDR cleanly isolates the metric we want to measure (PL processing latency) from network-stack latency that's structurally outside our control. It also matches the industry-standard practice for FPGA HFT prototyping: replay PCAP files into the FPGA from memory.

### 3.5 Output: 8 separate streams (one per decoder)

**Decision.** Each of the 8 decoders has its own output bundle and `decoded_valid` signal. No mux, no tagged unified stream.

**Alternatives considered.**
- Unified tagged stream (single wide bus + 4-bit type tag).
- 8 separate DMA channels.

**Rationale.**
- Matches our verification strategy: 8 golden CSVs from Python → 8 RTL CSVs from testbench monitors → 8 diffs.
- Zero "output packaging" logic needed in v1 — fewer blocks to design, fewer to verify.
- Adding a mux later (if downstream needs a single AXI-Stream port) is a 30-minute exercise on top of working RTL.

**Cost.** More top-level output pins (8 wide buses instead of 1). Acceptable for an internal IP block; would be redesigned for an external interface.

### 3.6 AXI-Stream-style interfaces

**Decision.** Inter-block interfaces use AXI-Stream-style signaling (`data`, `valid`) — without the full `ready/last/keep` handshake in v1.

**Alternatives considered.**
- Full AXI-Stream (`tdata`, `tvalid`, `tready`, `tlast`, `tkeep`, etc.).
- Custom ad-hoc interfaces.

**Rationale.**
- AXI-Stream is the de facto standard for streaming on Xilinx FPGAs — makes the IP composable with off-the-shelf Vivado IP (DMA, FIFOs, etc.).
- For v1, omitting `tready` (backpressure) simplifies the design since we control the entire pipeline and can guarantee downstream is always ready.
- We use the subset that's strictly necessary; expanding to full AXI-Stream is trivial when needed.

## 4. Block-level decisions

### 4.1 Length Predictor: 3-state FSM

**Decision.** Use a 3-state FSM: `WAIT_LEN_HI`, `WAIT_LEN_LO`, `STREAM_BODY`.

**Alternatives considered.**
- 2-state FSM with a sub-counter for the length-byte phase.
- Single state with multiple counters.

**Rationale.** 3 states maps cleanly to the three distinct phases:
- Reading the upper length byte.
- Reading the lower length byte.
- Streaming body bytes.

Each state's behavior is small and obvious. The state-based design is more readable than a counter-only design, and verification of each state is straightforward.

### 4.2 Length Predictor: separate length register and countdown counter

**Decision.** Use `length_reg[15:0]` to assemble the 2-byte length, copy into `bytes_remaining[15:0]` for countdown.

**Alternatives considered.**
- One register that's loaded then decremented in place.

**Rationale.** Conceptually cleaner to separate the two roles. Synthesis tools will optimize redundancy if they're equivalent — and treating them as separate makes the design more readable. Negligible area cost.

### 4.3 Dispatcher: 2-state FSM + broadcast bus + per-decoder valids

**Decision.** Broadcast `data_out` to all 8 decoders simultaneously. Activate exactly one decoder via its per-decoder `valid_X` signal.

**Alternatives considered.**
- Broadcast bus + tag (decoder self-filters by type).
- 8 separate data buses (full physical demux).

**Rationale.**
- Broadcast + per-decoder valid is the cheapest in routing area — a single 8-bit bus fans out to all decoders.
- Each decoder is stateless about routing — it only acts when its valid is high.
- Other invalid decoders ignore the bus entirely (no spurious state updates).
- This pattern is also how every published streaming-protocol decoder is architected.

### 4.4 Per-decoder pattern: byte counter + shift registers

**Decision.** Each decoder uses a `byte_count` register plus one shift register per multi-byte field. Each cycle, route the incoming byte to the appropriate field shift register based on `byte_count`.

**Alternatives considered.**
- Buffer N bytes in a wide register, then unpack at the end (mirrors Python `struct.unpack`).
- One state per byte position (a 36-state FSM for Add Order, etc.).

**Rationale (the shift-register elegance).**
- Multi-byte fields naturally assemble big-endian via left-shift:
  `field <= { field[width-9:0], data_in }` — N cycles of this leaves N bytes in correct order with zero extra logic.
- Big-endian byte ordering falls out for free; no explicit reordering needed.
- Eliminates the 6-byte timestamp problem entirely. In Python we had to split the timestamp into `H + I` because `struct` lacked a 6-byte type. In hardware, a 48-bit register absorbing 6 bytes via shift works perfectly.
- Same template applies to every multi-byte field across all 8 decoders — write the pattern once.

Buffering whole messages and unpacking at the end would require holding 44 bytes of state per decoder plus a wide combinational unpacking step at the end. Wasteful in area and creates a long combinational path.

### 4.5 8 separate decoder modules vs one parameterized module

**Decision.** Write 8 separate `itch_decoder_<type>.sv` files. Don't generalize.

**Alternatives considered.**
- One generic parameterized decoder module with a format-string parameter (similar to Python's `struct.unpack` format string).

**Rationale.**
- Parameterized SystemVerilog with field-mapping parameters is *complex* — requires `generate` blocks, parameterized structs, possibly preprocessor macros.
- The marginal cost of 8 separate modules is low: each is ~50–80 lines of repetitive SystemVerilog following the same template.
- Easier to debug per-type behavior in waveform when each is its own module.

**Cost.** Some code duplication. Mitigated by treating one decoder as canonical and copy-modifying the others.

**Future work.** Phase 2 could refactor to a parameterized template if there's time.

### 4.6 Output packaging deferred to top-level wiring

**Decision.** No dedicated "output packaging" block in v1. The 8 decoders' output bundles are exposed directly as top-level module outputs.

**Alternatives considered.**
- A muxing block that combines all decoder outputs into a single tagged stream.

**Rationale.** With 8 separate output streams (decision 3.5), there's nothing to package — the wires go straight out. Skipping this block saves design, simulation, and verification effort with zero functional cost.

## 5. Methodology decisions

### 5.1 Architecture-first, then implementation

**Decision.** Complete architectural specification of every block (this document) before writing any SystemVerilog.

**Alternatives considered.**
- Vertical: implement block 1 fully → block 2 fully → etc.
- Big-bang: design and code simultaneously.

**Rationale.**
- Architectural mistakes are cheap to fix on paper, expensive to fix in code.
- Interface mismatches between blocks surface during architecture, not after RTL is written.
- Implementation becomes mechanical once architecture is locked.
- This is standard practice in real-world RTL projects.

### 5.2 Python golden reference parser before RTL

**Decision.** Implement the parser fully in Python, validate against real data, then implement in RTL.

**Alternatives considered.**
- Skip Python; go straight to RTL.
- Write Python after RTL is done as a "spec."

**Rationale.**
- Forces complete understanding of the protocol at the byte level before writing any RTL.
- Produces the *golden reference output* against which RTL is verified — critical for catching off-by-one errors and field-ordering bugs.
- Python parser is the executable spec: when the RTL output diffs against the Python output, the diff *is* the bug.
- The Python parser becomes a portfolio artifact in its own right.

### 5.3 Per-type CSV verification

**Decision.** Verify RTL correctness by writing per-type CSV files from both Python and RTL, then diffing them.

**Alternatives considered.**
- Cycle-accurate behavioral comparison (UVM scoreboard style).
- Compare wide decoded buses cycle-by-cycle.
- Sample-based spot checks.

**Rationale.**
- Per-type CSV diffs are simple, fast, and reveal field-level mismatches immediately.
- One CSV per type means each decoder is independently verifiable.
- Format is human-readable — useful for debugging unexpected diffs.
- No UVM infrastructure to build for v1 (UVM is overkill for this scope).

A more thorough Phase 2 verification might use UVM, but per-type CSV diff covers 100% of functional correctness for our purposes.

### 5.4 Vertical-slice implementation order

**Decision.** Implement Length Predictor + Dispatcher + ONE decoder (System Event), integrate, end-to-end test. Then crank through the remaining 7 decoders.

**Alternatives considered.**
- All blocks individually first, integrate at the end.
- All 8 decoders before any integration.

**Rationale.**
- Vertical slice (minimum viable system) catches integration issues early.
- Gives a quick "first end-to-end pass" milestone for motivation.
- Once the first decoder works, the others are mechanical — quickly added.
- Reduces risk of discovering an architectural problem only after writing 8 decoders.

## 6. Simplifying assumptions (v1)

Each assumption here is a deferred problem, not an oversight. They are revisited in Phase 2 or v2.

### 6.1 No backpressure (`tready` not implemented)

**Assumption.** Downstream is always ready to accept data.

**Rationale.** With our internal-test-only scope, we control all consumers. If a downstream FIFO ever needs to apply backpressure, the design will silently drop data — acceptable for v1 since we don't have such a consumer.

**Cost.** Not production-ready as drop-in IP. Adding `tready` is straightforward when needed.

### 6.2 No malformed-message handling

**Assumption.** Input ITCH data is well-formed.

**Rationale.** Public Nasdaq sample data is well-formed. In production, malformed data is rare and typically handled at the SoupBinTCP / MoldUDP64 layer below ITCH. Out of scope for Phase 1.

**Cost.** A truncated or corrupt file may put the decoder into an undefined state.

### 6.3 Single clock domain

**Assumption.** All blocks run on one clock (`clk`).

**Rationale.** No CDC (clock-domain crossing) needed → no async FIFOs, no metastability handling, no constraint-driven CDC analysis. Simpler.

**Cost.** Cannot trivially mix high-speed I/O at a different rate without adding CDC. Acceptable since our input is DDR via DMA, also synchronous to the same clock.

### 6.4 Synchronous active-low reset

**Decision.** All registers use synchronous active-low reset (`rst_n`).

**Rationale.** Xilinx FPGAs prefer synchronous resets — they map well to register reset inputs and don't disturb async paths. Active-low matches the Vivado IP convention.

### 6.5 1-byte datapath (no alignment)

**Decision.** Already covered in 3.2. Repeated here for completeness.

---

# Part 2 — Technical Specification

## 7. Design parameters (locked)

| Parameter | Value | Decision section |
|---|---|---|
| Datapath width | 1 byte / cycle | 3.2 |
| Initial target clock | 100 MHz | 3.3 |
| Stretch target clock | 150 MHz | 3.3 |
| Input source | DDR → DMA → PL (AXI-Stream) | 3.4 |
| Output strategy | 8 separate output streams | 3.5 |
| Backpressure | Not implemented in v1 | 6.1 |
| Reset polarity | Active-low synchronous | 6.4 |

## 8. Top-level block diagram

```
                    INPUT (from DDR via DMA)
                          data_in[7:0]
                          valid_in
                              │
                              ▼
        ┌─────────────────────────────────────────────┐
        │       1. LENGTH PREDICTOR                   │
        │  States:  WAIT_LEN_HI, WAIT_LEN_LO,         │
        │           STREAM_BODY                       │
        │  Regs:    length_reg[15:0]                  │
        │           bytes_remaining[15:0]             │
        └────────────────────┬────────────────────────┘
                             │  data, valid, body_valid
                             ▼
        ┌─────────────────────────────────────────────┐
        │       2. HEADER PARSER / DISPATCHER         │
        │  States:  WAIT_TYPE, ROUTE                  │
        │  Reg:     current_type[7:0]                 │
        │  Combo:   type → valid_X mapping            │
        └──┬──┬──┬──┬──┬──┬──┬──┬─────────────────────┘
           │  │  │  │  │  │  │  │  data_dec, valid_{S,A,F,E,X,D,U,P}
           ▼  ▼  ▼  ▼  ▼  ▼  ▼  ▼
       ┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐
       │ S ││ A ││ F ││ E ││ X ││ D ││ U ││ P │   3. PER-MESSAGE DECODERS
       │dec││dec││dec││dec││dec││dec││dec││dec│   (×8 instances)
       │12B││36B││40B││31B││23B││19B││35B││44B│
       └─┬─┘└─┬─┘└─┬─┘└─┬─┘└─┬─┘└─┬─┘└─┬─┘└─┬─┘
         ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼
       o_S  o_A  o_F  o_E  o_X  o_D  o_U  o_P   4. OUTPUT (per type)
       vld  vld  vld  vld  vld  vld  vld  vld
```

## 9. Block 1 — Length Predictor

**Purpose.** Detect message boundaries in the incoming byte stream. Consume the 2-byte wire-framing length prefix and assert `body_valid` for exactly that many subsequent body bytes, then loop.

**Inputs**

| Signal | Width | Description |
|---|---|---|
| `clk` | 1 | Positive-edge clock |
| `rst_n` | 1 | Active-low synchronous reset |
| `data_in` | 8 | Byte from upstream (DMA) |
| `valid_in` | 1 | `data_in` is valid this cycle |

**Outputs**

| Signal | Width | Description |
|---|---|---|
| `data_out` | 8 | Passed through from `data_in` |
| `valid_out` | 1 | Passed through from `valid_in` |
| `body_valid` | 1 | High when `data_out` is an ITCH body byte (not framing) |

**State machine**

- `WAIT_LEN_HI` — sample byte into `length_reg[15:8]` when valid. Next state: `WAIT_LEN_LO`.
- `WAIT_LEN_LO` — sample byte into `length_reg[7:0]` when valid. Copy `length_reg` to `bytes_remaining`. Next state: `STREAM_BODY`.
- `STREAM_BODY` — `body_valid = 1` while valid. Decrement `bytes_remaining` each valid cycle. Return to `WAIT_LEN_HI` when `bytes_remaining == 0`.

**Internal registers**

- `state[1:0]` — current FSM state
- `length_reg[15:0]` — assembled length
- `bytes_remaining[15:0]` — countdown of body bytes left

**Latency.** 0 or 1 cycle, depending on whether we register the outputs. Recommend registering for clean timing.

---

## 10. Block 2 — Header Parser / Dispatcher

**Purpose.** Look at the type byte at the start of each body and route the entire body to the matching per-type decoder via per-decoder `valid_X` signals.

**Inputs**

| Signal | Width | Description |
|---|---|---|
| `clk` | 1 | Clock |
| `rst_n` | 1 | Reset |
| `data_in` | 8 | Byte from Length Predictor |
| `valid_in` | 1 | `data_in` valid |
| `body_valid_in` | 1 | This byte is an ITCH body byte |

**Outputs**

| Signal | Width | Description |
|---|---|---|
| `data_dec` | 8 | Shared decoder bus (`data_in` passed through) |
| `valid_S, valid_A, valid_F, valid_E, valid_X, valid_D, valid_U, valid_P` | 1 each | Per-decoder valid signals; at most one is high per cycle |

**State machine**

- `WAIT_TYPE` — watching for first body byte. When `body_valid_in` rises, this byte is the type. Compare to known type chars (`'S'`, `'A'`, etc.) and assert the matching `valid_X` this cycle. Latch `current_type`. Next state: `ROUTE`.
- `ROUTE` — while `body_valid_in == 1`, assert the same `valid_X` that matches `current_type`. When `body_valid_in` falls, return to `WAIT_TYPE`.

**Internal registers**

- `state[0:0]` — current FSM state
- `current_type[7:0]` — latched message-type byte

**Handling unknown types.** If `current_type` doesn't match any of the 8 supported types, no `valid_X` is asserted. The body bytes pass through but no decoder consumes them. Equivalent to the Python `else: skip` branch.

**Latency.** 0 cycles for the type-byte dispatch (combinational on `data_in`); 0 cycles for subsequent body bytes (combinational on `current_type`).

---

## 11. Block 3 — Per-Message Decoders (×8)

**Purpose.** Take an N-byte stream (where N is the message-type-specific length) and emit a structured set of decoded field values plus a `decoded_valid` pulse.

**Common interface (all 8 decoders share this template)**

**Inputs**

| Signal | Width | Description |
|---|---|---|
| `clk` | 1 | Clock |
| `rst_n` | 1 | Reset |
| `data_in` | 8 | Shared dispatcher bus |
| `valid_in` | 1 | This decoder's `valid_X` signal |

**Outputs**

| Signal | Width | Description |
|---|---|---|
| `o_<fields>` | varies | Field-specific output bundles (see per-type tables below) |
| `o_decoded_valid` | 1 | High for exactly 1 cycle when the message is fully decoded |

**Common internal state**

- `byte_count[5:0]` — counts 0 .. (N−1) within a message, wraps to 0 after message ends
- One register per field — see per-type tables below

**Common pattern**

```
on every clock cycle:
    if (valid_in) begin
        // Route data_in to the correct field register based on byte_count
        case (byte_count)
            0:                <field at byte 0>  <= data_in;
            1, 2:             <2-byte field>     <= { reg[7:0], data_in };  // shift in
            3, 4:             <2-byte field>     <= { reg[7:0], data_in };
            ... (per-type byte→field map)
        endcase

        // Advance counter; pulse decoded_valid on last byte
        if (byte_count == LAST_BYTE) begin
            byte_count       <= 0;
            o_decoded_valid  <= 1;
        end else begin
            byte_count       <= byte_count + 1;
            o_decoded_valid  <= 0;
        end
    end else begin
        o_decoded_valid <= 0;
    end
```

### 11.1 Per-type byte → field maps

#### S — System Event (12 bytes)

| Byte(s) | Field | Width | Register |
|---|---|---|---|
| 0 | type | 8 | `r_type` |
| 1–2 | stock_locate | 16 | `r_stock_locate` |
| 3–4 | tracking_number | 16 | `r_tracking_number` |
| 5–10 | timestamp | 48 | `r_timestamp` |
| 11 | event_code | 8 | `r_event_code` (last byte → pulse decoded_valid) |

Output bundle width: 8+16+16+48+8 = **96 bits + valid**

#### A — Add Order (36 bytes)

| Byte(s) | Field | Width |
|---|---|---|
| 0 | type | 8 |
| 1–2 | stock_locate | 16 |
| 3–4 | tracking_number | 16 |
| 5–10 | timestamp | 48 |
| 11–18 | order_ref_number | 64 |
| 19 | buy_or_sell | 8 |
| 20–23 | shares | 32 |
| 24–31 | stock | 64 (ASCII) |
| 32–35 | price | 32 (last byte → decoded_valid) |

Output bundle width: 8+16+16+48+64+8+32+64+32 = **288 bits + valid**

#### F — Add Order with MPID (40 bytes)

Identical to `A` plus:

| Byte(s) | Field | Width |
|---|---|---|
| 36–39 | attribution (MPID) | 32 (ASCII) |

Output bundle width: 288 + 32 = **320 bits + valid**

#### E — Order Executed (31 bytes)

| Byte(s) | Field | Width |
|---|---|---|
| 0 | type | 8 |
| 1–2 | stock_locate | 16 |
| 3–4 | tracking_number | 16 |
| 5–10 | timestamp | 48 |
| 11–18 | order_ref_number | 64 |
| 19–22 | executed_shares | 32 |
| 23–30 | match_number | 64 |

Output bundle width: 8+16+16+48+64+32+64 = **248 bits + valid**

#### X — Order Cancel (23 bytes)

| Byte(s) | Field | Width |
|---|---|---|
| 0 | type | 8 |
| 1–2 | stock_locate | 16 |
| 3–4 | tracking_number | 16 |
| 5–10 | timestamp | 48 |
| 11–18 | order_ref_number | 64 |
| 19–22 | cancelled_shares | 32 |

Output bundle width: 8+16+16+48+64+32 = **184 bits + valid**

#### D — Order Delete (19 bytes)

| Byte(s) | Field | Width |
|---|---|---|
| 0 | type | 8 |
| 1–2 | stock_locate | 16 |
| 3–4 | tracking_number | 16 |
| 5–10 | timestamp | 48 |
| 11–18 | order_ref_number | 64 |

Output bundle width: 8+16+16+48+64 = **152 bits + valid**

#### U — Order Replace (35 bytes)

| Byte(s) | Field | Width |
|---|---|---|
| 0 | type | 8 |
| 1–2 | stock_locate | 16 |
| 3–4 | tracking_number | 16 |
| 5–10 | timestamp | 48 |
| 11–18 | original_order_ref | 64 |
| 19–26 | new_order_ref | 64 |
| 27–30 | shares | 32 |
| 31–34 | price | 32 |

Output bundle width: 8+16+16+48+64+64+32+32 = **280 bits + valid**

#### P — Trade (44 bytes)

| Byte(s) | Field | Width |
|---|---|---|
| 0 | type | 8 |
| 1–2 | stock_locate | 16 |
| 3–4 | tracking_number | 16 |
| 5–10 | timestamp | 48 |
| 11–18 | order_ref_number | 64 |
| 19 | buy_or_sell | 8 |
| 20–23 | shares | 32 |
| 24–31 | stock | 64 |
| 32–35 | price | 32 |
| 36–43 | match_number | 64 |

Output bundle width: 8+16+16+48+64+8+32+64+32+64 = **352 bits + valid**

---

## 12. Block 4 — Output Packaging

In v1, no dedicated block is needed. The 8 decoders' output bundles are directly exposed as top-level outputs. A testbench monitor (or downstream IP) routes each to its own CSV.

If a later version needs a single AXI-Stream output, add a small mux block at the top that combines all 8 outputs (priority encoder + type tag).

---

## 13. File organization

```
rtl/
├── itch_top.sv                  Top-level wrapper, instantiates everything
├── itch_length_predictor.sv     Block 1
├── itch_header_parser.sv        Block 2
├── itch_decoder_s.sv            Block 3a — System Event decoder
├── itch_decoder_a.sv            Block 3b — Add Order decoder
├── itch_decoder_f.sv            Block 3c — Add Order MPID decoder
├── itch_decoder_e.sv            Block 3d — Order Executed decoder
├── itch_decoder_x.sv            Block 3e — Order Cancel decoder
├── itch_decoder_d.sv            Block 3f — Order Delete decoder
├── itch_decoder_u.sv            Block 3g — Order Replace decoder
└── itch_decoder_p.sv            Block 3h — Trade decoder

tb/
├── itch_top_tb.sv               Top-level testbench
├── tb_byte_feeder.sv            Reads ITCH file, feeds bytes into DUT
├── tb_monitor_s.sv              Monitors S decoder output, writes CSV
├── tb_monitor_a.sv              Monitors A decoder output, writes CSV
... (one monitor per decoder)
```

---

## 14. Implementation order

Following the architecture-first, vertical-slice-implementation pattern (decision 5.4):

1. **Length Predictor first.** Simplest FSM, foundational. Write + unit test.
2. **Header Parser / Dispatcher.** Second simplest. Write + unit test.
3. **One decoder (System Event).** Pick the smallest to validate the decoder pattern. Write + unit test.
4. **Integrate** Length Predictor + Dispatcher + System Event decoder. End-to-end test against a tiny ITCH file.
5. **Implement remaining 7 decoders.** Same pattern, mechanical work.
6. **Full system test.** Run the BX sample file through. Diff RTL CSVs against Python golden CSVs.
7. **Synthesis.** Vivado synth + place-and-route. Check timing at 100 MHz, then push toward 150 MHz.
8. **On-board bring-up.** Load to PYNQ-Z2, exercise via PS-side ARM.
9. **Documentation and resource report.** Final polish, contribute to Phase 2 paper.
