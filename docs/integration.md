## Integration Validation (QMF + Gain)

This repository also includes an **integration-level validation**
combining multiple RTL building blocks into a single streaming pipeline:

QMF Analysis → Dual Gain (Low / High) → QMF Synthesis

The integration test demonstrates that:

- QMF subbands can be processed **independently** in the frequency domain
- Gain modules operate correctly inside a **multi-stage AXI-Stream pipeline**
- The reconstructed output reflects expected **subband gain behavior**
- AXI-Stream handshakes remain stable with no deadlock or data loss

The `docs/integration` directory contains:

- a high-level architecture diagram
- representative waveform captures from RTL simulation

This integration is provided **for functional validation only**.
It does not aim to optimize audio quality or serve as a reusable system design.

The focus remains on **RTL correctness, fixed-point discipline,
and composability of DSP building blocks**.
