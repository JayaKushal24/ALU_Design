# N-Bit Parameterized ALU – RTL Design & Verification

A parameterized **N-bit Arithmetic Logic Unit (ALU)** designed in **Verilog HDL** with a complete **self-checking verification environment** using **Siemens Questa SIM**.

This project focuses on:
- RTL design
- Functional verification
- Pipeline timing validation
- Multi-cycle operations
- Coverage-driven verification

---

# 📌 Features

## Arithmetic Operations
- ADD / SUB
- ADD with Carry / SUB with Carry
- Increment / Decrement
- Signed ADD / Signed SUB
- Compare
- Multi-cycle Multiply operations

## Logical Operations
- AND / OR / XOR
- NAND / NOR / XNOR
- NOT
- Shift Left / Right
- Rotate Left / Right

---

# 🏗️ Architecture

The ALU is implemented as a **2-stage pipelined synchronous design**.

### Stage 1 – Input Register
Captures:
- OPA
- OPB
- CMD
- MODE
- CIN
- INP_VALID

### Stage 2 – Execute & Output
Generates:
- RES
- COUT
- OFLOW
- G / E / L
- ERR

---

# ⏱️ Timing Behaviour

## Standard Operations
- Inputs sampled at Clock Edge 1
- Outputs valid at Clock Edge 2
- 1-cycle latency

## Multi-Cycle Operations
Operations:
- `INC_MUL`
- `LSH_MUL`

Behavior:
- Edge 1 → Inputs sampled
- Edge 2 → Output invalid (`X`)
- Edge 3 → Final result valid

---

# 🚩 Status Flags

| Flag | Description |
|------|-------------|
| COUT | Carry Out |
| OFLOW | Overflow |
| G | Greater Than |
| E | Equal |
| L | Less Than |
| ERR | Invalid operation / operands |

---

# 🧪 Verification Environment

The project includes a complete **self-checking testbench** with:

- Driver
- Monitor
- Scoreboard
- Golden Reference Model

Verification includes:
- Directed tests
- Random stimulus
- Corner-case testing
- Overflow validation
- Pipeline latency checks
- Multi-cycle operation validation

---

# 📊 Coverage Results

## My ALU Design
| Coverage Type | Coverage |
|---|---|
| Statements | 99.13% |
| Branches | 97.05% |
| Expressions | 100% |
| Toggles | 98.58% |
| **Overall Coverage** | **98.69%** |


---


# 🛠️ Tools Used

| Tool | Purpose |
|---|---|
| Xilinx Vivado | RTL elaboration & lint checks |
| Siemens Questa SIM | Simulation & coverage |

