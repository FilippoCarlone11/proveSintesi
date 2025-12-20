

```markdown
# ODE4EC - Fault Analysis & Scan Chain Insertion


## Introduction

The objective of this part is to analyze the operation of the **Fault** tool when applied to basic digital circuits.

To automate and standardize the file generation process, a bash script named `fault_commands.sh` has been developed. This script manages the synthesis flow and the insertion of scan chains.

### Configuration

Before using the script, you must configure the `config.cfg` file. This file must specify the local paths for:
* The Fault Virtual Machine.
* The 15nm and 130nm technology libraries.

### Usage

The script accepts three parameters:
1.  **Technology Node** (e.g., `130nm`)
2.  **Source File** (The Verilog circuit file)
3.  **Synthesis Script** (The Yosys script)

To run the synthesis flow and scan chain insertion, navigate to the directory containing your circuit and script, then execute:


./fault_commands.sh 130nm circuit.v synth.sh



### Outputs

The execution generates the following output files:

* `circuit.s.v`: The synthesized netlist.
* `circuit.sc.v`: The circuit with Scan Flip-Flops inserted (Scan Chain).

Additionally, an `img/` directory is created containing graphical representations of both the synthesized circuit and the version with the scan chain. These allow for visual analysis of the circuit behavior.

---

## Use Cases

The project analyzes the behavior of four basic sequential circuits. The complete project structure is available on the GitHub repository:
[https://github.com/FilippoCarlone11/proveSintesi](https://github.com/FilippoCarlone11/proveSintesi)

The analyzed circuits are:

1. **Single Flip-Flop**
2. **Cascaded Flip-Flop Pair**
3. **Counter**
4. **Finite State Machine (FSM)**

---

## Analysis

### 1. Single Flip-Flop

We started with a single Flip-Flop to understand Fault's behavior on a "minimal" circuit and to evaluate the added overhead.

**Overhead Analysis:**
Fault adds significant logic to the initial structure (which consisted of 1 Flip-Flop and 1 Inverter). The tool inserts:

* 2 Inverters
* 2 Flip-Flops
* 3 Multiplexers

**New I/O Signals:**
The following signals are added to the inputs and outputs:

* `sin`: **Scan In** - Serial input for loading test vectors into the chain.
* `sout`: **Scan Out** - Serial output for reading internal states.
* `shift`: **Scan Enable** - Enables shifting; when active, it configures Flip-Flops as a shift register.
* `tck`: **Test Clock** - Dedicated clock for test operations.
* `test`: **Test Mode** - Global signal to switch the circuit from functional mode to test mode.

**Behavior:**
Simulations were performed in "functional mode" (test off). The circuit operates correctly at both 15nm and 130nm nodes.

### 2. Cascaded Flip-Flop Pair

*(Analysis to be added)*

### 3. Counter

*(Analysis to be added)*

### 4. Finite State Machine (FSM)

*(Analysis to be added)*

```

```