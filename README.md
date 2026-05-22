# HFT System on PYNQ-Z2

An FPGA-accelerated High-Frequency Trading reference design on the Xilinx Zynq-7020 (PYNQ-Z2), with a quantitative comparison against an ARM Cortex-A9 software baseline.

## Project Phases

- **Phase 1 (in progress):** Pipelined RTL decoder for the NASDAQ ITCH 5.0 market data protocol, packaged as a reusable AXI-Stream IP.
- **Phase 2 (planned):** Hardware order book integrated with the decoder; HW-vs-SW benchmark.

## Repository Structure

| Folder | Contents |
|---|---|
| `docs/` | Project documentation, specifications, design notes |
| `golden_model/` | Python reference parser (verification golden model) |
| `rtl/` | SystemVerilog source for the FPGA design |
| `tb/` | SystemVerilog testbenches |
| `scripts/` | Build / simulation / utility scripts |
| `vivado/` | Vivado project files (gitignored) |
| `data/` | ITCH sample data files (gitignored) |

## Hardware / Tools

- Board: PYNQ-Z2 (Xilinx Zynq-7020)
- Toolchain: Vivado 2022.2, PYNQ 3.0/3.1
- Languages: SystemVerilog, Python 3

## Status

Phase 1: ITCH 5.0 decoder design.

