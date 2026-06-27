# Neuron â€” Processing Element Node (Hardware Neural Network)

A hardware implementation of a single neuron processing element (PE) in Verilog HDL, designed as the fundamental compute unit for a systolic-array-based neural network accelerator.

> **Note:** The original repo has a typo in its name (`Procressing`). Rename it to `Neuron-Processing-Element-Node` via GitHub Settings â†’ Repository name.

---

## Overview

This project implements a fully parameterizable **hardware neuron** in Verilog â€” the core building block for a neural network inference accelerator. The neuron performs a **Multiply-Accumulate (MAC)** operation over `N` input-weight pairs, adds a bias term, then applies a non-linear **activation function** (either Sigmoid via ROM lookup, or ReLU).

The design supports:
- Parameterizable data width (default: 16-bit fixed-point)
- Configurable number of weights per neuron
- Selectable activation function: `"sigmoid"` or `"relu"`
- Pre-trained weight/bias loading from `.mif` files

---

## Neuron Architecture

```
 inputs (x)      weights (w)
     â”‚                â”‚
     â–¼                â–¼
 â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
 â”‚    Weight Memory       â”‚  â† Dual-port RAM (Weight_Memory.v)
 â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
             â”‚ w[i]
             â–¼
 â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
 â”‚  Multiply & Accumulate â”‚  â† x[i] Ã— w[i], accumulated over N cycles
 â”‚  (MAC with saturation) â”‚
 â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
             â”‚ sum
             â–¼
 â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
 â”‚    Bias Addition       â”‚  â† sum + bias (with overflow saturation)
 â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
             â”‚
             â–¼
 â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
 â”‚   Activation Function  â”‚  â† Sigmoid (ROM) or ReLU
 â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
             â”‚
             â–¼
           output
```

---

## File Descriptions

| File | Description |
|------|-------------|
| `nn.v` | Top-level neuron module â€” MAC engine, bias addition, activation selection |
| `weight_memory.v` | Dual-port weight RAM â€” loads weights either from `.mif` file or runtime |
| `sig_rom.v` | Sigmoid activation via ROM lookup table (pre-computed values) |
| `Relu.v` | ReLU activation â€” clips negative values to zero, scales positives |
| `include.v` | Shared parameter definitions and macros |
| `tb.v` | Testbench â€” drives inputs, checks output validity |

---

## Module Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `layerNo` | 0 | Layer index (for addressing in multi-layer networks) |
| `neuronNo` | 0 | Neuron index within the layer |
| `numWeight` | 8 | Number of input weights (= fan-in) |
| `dataWidth` | 16 | Bit-width for fixed-point arithmetic |
| `sigmoidSize` | 10 | Input bit-width for sigmoid ROM lookup |
| `weightIntWidth` | 1 | Integer bits in weight fixed-point format |
| `actType` | `"sigmoid"` | Activation: `"sigmoid"` or `"relu"` |
| `biasFile` | `b_1_15.mif` | MIF file for pre-trained bias |
| `weightFile` | `w_1_15.mif` | MIF file for pre-trained weights |

---

## Top-Level Ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock |
| `rst` | input | 1 | Synchronous reset |
| `myinputValid` | input | 1 | Input data valid strobe |
| `weightValid` | input | 1 | Weight loading valid strobe |
| `biasValid` | input | 1 | Bias loading valid strobe |
| `out` | output | dataWidth | Activation output |
| `outvalid` | output | 1 | Output valid strobe |

---

## Operation Sequence

1. **Weight Loading:** On `weightValid` high, weights are written sequentially into the weight RAM
2. **MAC Phase:** On `myinputValid` high, inputs are read and multiplied with stored weights, accumulated over `numWeight` cycles with overflow saturation
3. **Bias Addition:** After all products are accumulated, bias is added with saturation
4. **Activation:** The accumulated sum is passed through either the Sigmoid ROM or ReLU module
5. **Output:** `outvalid` pulses high when `out` is ready

---

## Timing Diagram (Conceptual)

```
clk          ___   ___   ___   ___   ___   ___
            /   \_/   \_/   \_/   \_/   \_/   \
myinputValid ____/â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾â€¾\_____
                 [x0]  [x1] ... [xN-1]
outvalid     __________________________________/â€¾\_
out          -------------------------------->[valid]
```

---

## How to Simulate

```bash
# Using Icarus Verilog
iverilog -o neuron_sim nn.v weight_memory.v sig_rom.v Relu.v include.v tb.v
vvp neuron_sim

# View waveform
gtkwave dump.vcd
```

---

## Compile Switch

To use pre-trained weights from `.mif` files instead of runtime loading:

```verilog
// In your simulator or Makefile
+define+pretrained
```

When `pretrained` is defined, the design reads `weightFile` and `biasFile` at elaboration time using `$readmemb`.

---

## What to Add Next

- [ ] Add `docs/neuron_architecture.png` â€” block diagram of the neuron
- [ ] Add `sim/waveform.png` â€” simulation output screenshot
- [ ] Add sample `.mif` weight files for testing
- [ ] Add multi-neuron layer instantiation example
- [ ] Set GitHub topics: `verilog` `neural-network` `hardware-ml` `mac` `systolic-array` `ai-hardware` `vlsi`

---

## Tools Used

| Tool | Purpose |
|------|---------|
| Verilog HDL | RTL Design |
| Icarus Verilog / Vivado | Simulation |
| GTKWave | Waveform analysis |

---

## License

MIT License
