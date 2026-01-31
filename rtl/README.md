# RTL Directory Overview

This directory contains the complete RTL implementation of the
**Quadrature Mirror Filter (QMF) analysis–synthesis filter bank**
used in this repository.

The RTL is intentionally organized to separate:
- pure DSP arithmetic
- AXI interface logic
- integration glue

This allows the QMF design to be reviewed, reused, and reasoned about
as a standalone DSP building block.

---

## Contents

### Core DSP Modules

- `qmf_analysis_core.v`  
  Implements the **analysis stage** of a two-channel QMF bank.
  Produces low-band and high-band subband signals using
  a prototype low-pass FIR filter and its quadrature mirror.

- `qmf_synthesis_core.v`  
  Implements the **synthesis stage** of the QMF bank.
  Reconstructs the full-band signal by filtering and summing
  the low-band and high-band inputs.

These modules contain **only arithmetic and control-local logic**.
They are free of AXI signaling, buffering, or system-level assumptions.

---

### AXI Wrapper Modules

- `qmf_analysis_axis.v`  
  AXI-Stream and AXI-Lite wrapper for `qmf_analysis_core`.
  Handles:
  - stereo stream splitting
  - AXI backpressure
  - coefficient register access
  - control signal alignment

- `qmf_synthesis_axis.v`  
  AXI-Stream and AXI-Lite wrapper for `qmf_synthesis_core`.
  Handles:
  - subband stream synchronization
  - stereo reconstruction
  - fixed-latency control pipelining

The AXI wrappers are intentionally thin and deterministic.
All DSP behavior resides in the core modules.

---

## FIR Core Dependency

The QMF implementation relies on a **parameterizable FIR core**
as its lower-level arithmetic primitive.

That FIR core is **not duplicated in this repository**.

Instead, it is treated as a **verified external building block**
and is maintained in a dedicated repository:

https://github.com/vrm-lab/FIR-Stereo-FPGA

This decision is intentional and follows two principles:

1. **Single source of truth**  
   The FIR implementation is maintained, reviewed, and validated
   in one place only.

2. **Clear design hierarchy**  
   - FIR core → arithmetic primitive  
   - QMF core → filter bank composition  
   - Higher-level systems → integration artifacts

By avoiding duplication, this repository focuses strictly on
**QMF-specific design decisions**, not reimplementation of
previously validated components.

---

## Notes on Validation Configuration

For RTL simulation and hardware validation, the FIR core is instantiated
with a fixed configuration (e.g. Johnston prototype, limited tap count).

This configuration is used **only as a reference point** for validation.
The underlying FIR core itself is parameterizable, but this repository
intentionally documents and validates **a single, fixed design choice**.

---

## Scope Reminder

This directory contains **reference RTL**, not a reusable framework.

It demonstrates:
- deterministic fixed-point DSP
- explicit latency management
- clean separation between arithmetic and interfaces

It does **not** attempt to expose every possible configuration
or usage scenario.

> This repository demonstrates design decisions, not design possibilities.
