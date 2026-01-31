# AXI-Lite Address Map

This document describes the AXI-Lite register layout
used by both QMF Analysis and Synthesis wrappers.

---

## Register Overview

| Offset | Name            | Access | Description |
|------:|-----------------|--------|-------------|
| 0x00  | CONTROL         | R/W    | Enable bit |
| 0x04  | COEF[0]         | R/W    | FIR coefficient 0 |
| 0x08  | COEF[1]         | R/W    | FIR coefficient 1 |
| ...   | ...             | ...    | ... |
| 0x04 + 4×(N-1) | COEF[N-1] | R/W | FIR coefficient N-1 |

---

## Control Register (0x00)

| Bit | Name   | Description |
|----:|--------|-------------|
| 0   | ENABLE | Enables internal processing |

All other bits are reserved and must be written as zero.

---

## Coefficient Registers

- 16-bit signed coefficient stored in lower halfword
- Upper 16 bits are ignored
- Coefficients are interpreted as Q15

---

## Notes

- Analysis and Synthesis cores use identical maps
- No runtime protection is enforced
- Writes take effect immediately

This interface is intentionally simple and transparent.
