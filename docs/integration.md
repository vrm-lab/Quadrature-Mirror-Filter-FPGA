# Integration Overview

This document describes the **system-level integration** of the
Quadrature Mirror Filter (QMF) pipeline combined with independent
subband gain processing.

The integration focuses on **architectural correctness**, not feature
completeness or performance tuning.

---

## Integrated Signal Chain

The integrated processing pipeline is:

Input Stream  
→ QMF Analysis  
→ Low Band  → Gain (independent control)  
→ High Band → Gain (independent control)  
→ QMF Synthesis  
→ Output Stream

Each block communicates exclusively via **AXI-Stream**, with control
handled through **AXI-Lite** where applicable.

---

## Architectural Intent

This integration exists to validate that:

- QMF analysis and synthesis can operate as a **stable streaming pair**
- Subband-domain processing can be inserted **without breaking timing**
- Multiple AXI-Stream blocks can be chained **without deadlock**
- Control-plane (AXI-Lite) and data-plane (AXI-Stream) interactions
  remain cleanly separated

The architecture is intentionally **explicit and verbose** to make
signal flow and handshake behavior unambiguous.

---

## Subband Gain Placement

Two independent gain modules are inserted:

- **Low-band gain**  
  Applied after QMF analysis low-pass output

- **High-band gain**  
  Applied after QMF analysis high-pass output

This placement demonstrates:

- True subband-domain processing
- Independent manipulation of spectral regions
- Correct recombination through QMF synthesis

No cross-band coupling or shared state exists between the gain blocks.

---

## Fixed-Point Discipline

All blocks operate using **explicit fixed-point formats**:

- No floating-point arithmetic
- No implicit bit growth
- Saturation behavior is handled inside each DSP block

The integration verifies that fixed-point constraints remain valid
across multiple connected modules.

---

## Testbench Strategy

Integration is validated using a **system-level RTL testbench** that:

- Streams synthetic audio signals through the full pipeline
- Programs QMF coefficients and gain values via AXI-Lite
- Exercises backpressure and handshake behavior
- Captures waveform data for offline inspection

The testbench prioritizes **robustness and clarity** over automation.

---

## Waveform Interpretation

Included waveform plots illustrate:

- Input signal composition
- Subband separation behavior
- Gain effects applied per band
- Final reconstructed output

Due to pipeline latency:

- Input and output samples are **not cycle-aligned**
- Visual comparison is qualitative, not sample-accurate

This behavior is expected and intentional.

---

## Scope and Limitations

This integration:

- ✅ Demonstrates correct multi-block AXI streaming
- ✅ Validates subband processing inside a QMF system
- ✅ Confirms clean separation of control and data paths

This integration does **not**:

- Optimize audio quality
- Provide bitstreams or software stacks
- Act as a reusable system framework

The scope is intentionally constrained.

---

## Design Philosophy

This integration reflects a deliberate engineering stance:

- Show **how** the system works, not how many features it has
- Favor explicit wiring over abstraction
- Prioritize correctness, determinism, and inspectability

The result is a **reference-quality integration**, not a product demo.

---

## Status

The integration design and its validation artifacts are considered
**complete**.

No further expansion is planned.
