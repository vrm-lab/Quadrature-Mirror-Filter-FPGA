# Quadrature Mirror Filter (QMF) (AXI-Stream) on FPGA

This repository provides a **reference RTL implementation** of a
**two-channel Quadrature Mirror Filter (QMF) analysis/synthesis filter bank**
implemented in **Verilog** and integrated with **AXI-Stream**.

Target platform: **AMD Kria KV260**  
Focus: **RTL architecture, fixed-point DSP decisions, and AXI correctness**

---

## Overview

This module implements:

* **Function**: QMF-based subband analysis and synthesis
* **Data type**: Fixed-point (Q15)
* **Scope**: Minimal, single-purpose DSP building block

The design is intentionally **not generic** and **not feature-rich**.  
It exists to demonstrate **how a QMF filter bank is implemented in hardware**,  
not to provide a turnkey audio codec or framework.

---

## Key Characteristics

* RTL written in **Verilog**
* **AXI-Stream** data interface
* **AXI-Lite** control interface for coefficient loading and enable
* Fixed-point arithmetic with explicit bit-width control
* Deterministic, cycle-accurate behavior
* Designed and verified for **real-time audio streaming**
* No runtime software included

---

## Architecture

High-level structure:

```
AXI-Stream In
|
v
+----------------------+
| QMF Analysis Core |
| (FIR-based) |
+----------------------+
|
| Low / High Subbands
|
+----------------------+
| QMF Synthesis Core |
| (FIR-based) |
+----------------------+
|
v
AXI-Stream Out
```

---


Design notes:

* Analysis and synthesis stages are implemented as **separate RTL cores**
* FIR filtering is used explicitly for clarity and determinism
* Coefficients are programmable at runtime via AXI-Lite
* No hidden buffering or implicit multirate logic is used

---

## Data Format

* AXI-Stream width: **32-bit**
* Fixed-point format: **Q1.15**
* Channel layout:
  * `[15:0]`   → Left channel (signed)
  * `[31:16]`  → Right channel (signed)

At the core level, all processing is performed using signed 16-bit samples.

---

## Latency

* **Fixed processing latency**
* Latency is:
  * deterministic
  * constant
  * independent of input signal characteristics

This behavior is intentional and suitable for streaming DSP pipelines where
predictable timing is required.

---

## Verification & Validation

Verification was performed at two levels.

### 1. RTL Simulation

Dedicated testbenches validate:

* Subband separation behavior
* Reconstruction correctness
* Fixed-point numerical stability
* AXI-Stream handshake correctness
* AXI-Lite register read/write behavior

Simulation outputs are logged to CSV files for **offline waveform inspection**.

---

### 2. Hardware Validation

The design was **tested on real FPGA hardware**.

> **Tested on FPGA hardware via PYNQ overlay**

PYNQ was used strictly as:
* a signal stimulus source
* an observability/debug tool

No PYNQ software, Python scripts, or runtime dependencies are included
in this repository.

---

## Reference Filter

This implementation uses the **Johnston 8A QMF prototype filter**
as a validation reference:

> James D. Johnston,  
> *A filter family designed for use in quadrature mirror filter banks*,  
> IEEE ICASSP, 1980.

The filter is used to:
* validate subband separation
* observe reconstruction behavior
* evaluate fixed-point implementation quality

It is **not presented as an optimal or modern design**.

---

## What This Repository Is

* A **clean RTL reference**
* A demonstration of:
  * DSP reasoning
  * fixed-point trade-offs
  * AXI-Stream / AXI-Lite integration
* A building block for larger FPGA audio pipelines

---

## What This Repository Is Not

* ❌ A complete audio system
* ❌ A codec or compression framework
* ❌ A parameter-heavy generic IP
* ❌ A software-driven demonstration

The scope is intentionally constrained.

---

## Design Rationale (Summary)

Key design decisions include:

* FIR-based QMF for explicit and debuggable behavior
* Johnston 8A coefficients for literature-backed validation
* Fixed-point arithmetic with explicit scaling
* Separate core and AXI wrapper layers for clarity

These choices reflect **engineering trade-offs**, not missing features.

---

## Project Status

This repository is considered **complete**.

* RTL is stable
* Functional verification is complete
* Hardware validation has been performed
* No further feature expansion is planned

The design is published as a **reference implementation**.

---

## License

Licensed under the MIT License.  
Provided as-is, without warranty.

---

> **This repository demonstrates design decisions, not design possibilities.**
