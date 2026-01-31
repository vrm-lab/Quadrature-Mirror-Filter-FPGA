# QMF + Gain Integration Results

This folder contains **integration-level validation results**
for the following signal chain:

QMF Analysis → Dual Gain (Low / High) → QMF Synthesis

The purpose of this integration test is to verify that:

- QMF subband signals can be independently processed
- Gain modules operate correctly inside a streaming QMF pipeline
- The reconstructed output reflects expected subband gain behavior
- AXI-Stream handshakes remain stable across multiple connected blocks

---

## Testbench Overview

**Testbench name**

tb_qmf_gain_system

**Signal flow**

Input  
→ QMF Analysis  
→ Low Band  → Gain (Boost)  
→ High Band → Gain (Cut)  
→ QMF Synthesis  
→ Final Output

**Configuration**

- QMF prototype: **Johnston 8A**
- FIR taps: **8**
- Low-band gain: **+6 dB (×2.0)**
- High-band gain: **−12 dB (×0.25)**
- Fixed-point arithmetic throughout
- Explicit AXI-Stream wiring (no implicit connections)

---

## Result Files

### Waveform Plot

- tb_data_qmf_gain_system.png

This plot visualizes:

- Input signal
- Low-band signal after gain
- High-band signal after gain
- Final reconstructed output

The waveform confirms that:

- Low-frequency components are amplified
- High-frequency components are attenuated
- Reconstruction remains stable and free of deadlock

---

### CSV Data

- tb_data_qmf_gain_system.csv

The CSV log is intended for **offline inspection only**.

Notes:

- Input samples are **not cycle-aligned** with output samples
- Pipeline latency is intentionally ignored
- Data is suitable for:
  - waveform visualization
  - relative comparison
  - sanity checking

Not intended for:

- automated metric extraction
- bit-exact alignment analysis

---

## Scope Statement

This integration result:

- ✅ Demonstrates correct **multi-module AXI-Stream composition**
- ✅ Confirms **subband-domain processing** inside QMF
- ✅ Validates **fixed-point DSP behavior** across blocks

- ❌ Does not claim audio quality optimization
- ❌ Does not include bitstreams or runtime software
- ❌ Does not serve as a generic verification framework

---

## Status

This integration test is considered **complete and stable**.

It exists to demonstrate **system-level correctness**,
not performance tuning or production readiness.
