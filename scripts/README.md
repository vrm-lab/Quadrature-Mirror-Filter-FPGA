# Scripts Directory

This directory contains **auxiliary Tcl scripts** used to recreate
the **Vivado Block Design (BD)** required for validating the QMF system
integration on Zynq UltraScale+ platforms (e.g. KV260).

The scripts in this folder are **intentionally minimal** and focus on:

- AXI-Stream dataflow connectivity  
- AXI-Lite control integration  
- Deterministic address mapping  

They are **not** intended to fully reproduce a GUI-generated Vivado project.

---

## `bd_qmf.tcl`

This Tcl script creates a **connectivity-focused block design** consisting of:

- Zynq UltraScale+ Processing System
- AXI DMA (MM2S / S2MM)
- QMF Analysis AXI module
- QMF Synthesis AXI module
- Two Gain AXI modules (Low / High subbands)
- AXI interconnects and reset logic

### Design Philosophy

The block design is deliberately kept **portable and readable**:

- ❌ No DDR timing configuration
- ❌ No MIO / board preset noise
- ❌ No performance or throughput claims
- ❌ No software runtime assumptions

- ✅ Clear AXI-Stream signal flow
- ✅ Explicit AXI-Lite control paths
- ✅ Stable and review-friendly address map

This approach aligns with the **RTL-centric philosophy** of this repository.

---

## Relationship to Other Repositories

The Gain blocks instantiated in this design correspond to the standalone
Gain module published separately:

- https://github.com/vrm-lab/Audio-Gain-Module-FPGA

That repository documents the **Gain AXI module in isolation**,
while this QMF repository demonstrates **system-level integration**
of Analysis → Gain → Synthesis using the same RTL blocks.

This separation avoids duplication and keeps each repository focused.

---

## Usage Notes

- These scripts are provided for **reference and validation only**
- They are useful for:
  - Recreating the block design quickly
  - Understanding AXI interconnect topology
  - Inspecting how DSP blocks are composed at system level

- They are **not** intended to be:
  - A production-ready platform design
  - A drop-in turnkey Vivado project
  - A replacement for proper system integration work

---

## Status

The scripts in this directory are considered **complete and frozen**.

They exist to support clarity, reproducibility, and review,
not ongoing feature expansion.
