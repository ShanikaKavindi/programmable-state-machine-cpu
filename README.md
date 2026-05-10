# Programmable State Machine CPU Design

## Overview

This project presents the design and implementation of a programmable state machine CPU using SystemVerilog. The processor solves a student group elimination problem by processing marks, calculating averages, identifying minimum scores, and selecting the eliminated group using custom hardware logic.

The system processes 20 student marks divided into four groups:

* Group A
* Group B
* Group C
* Group D

Each group contains 5 students.

## Features

* Custom 16-bit Instruction Set Architecture (ISA)
* 16 General-Purpose Registers
* Instruction Memory (IMEM)
* Data Memory (DMEM)
* One Instruction Execution per Clock Cycle
* Arithmetic and Logical Operations
* LOAD and STORE Instructions
* MIN-Based Tie-Breaking Logic
* HALT Control Instruction
* SystemVerilog RTL Design
* Full Testbench Verification

---

## Implemented Instructions

| Opcode | Instruction | Function                |
| ------ | ----------- | ----------------------- |
| 0x0    | ADD         | Addition                |
| 0x1    | SUB         | Subtraction             |
| 0x2    | SLL         | Shift Left Logical      |
| 0x3    | SRL         | Shift Right Logical     |
| 0x4    | MUL         | Multiplication          |
| 0x5    | DIV         | Division                |
| 0x6    | MIN         | Minimum Value Selection |
| 0x7    | AND         | Bitwise AND             |
| 0x8    | LOAD        | Load from Data Memory   |
| 0x9    | STORE       | Store to Data Memory    |
| 0xA    | MOV         | Register Move           |
| 0xF    | HALT        | Stop Program Execution  |

---

## Project Functionality

The processor:

1. Reads student marks from data memory
2. Computes group sums
3. Calculates averages
4. Finds minimum marks
5. Generates elimination keys
6. Determines the eliminated group automatically

Tie-breaking is handled using minimum individual marks.

## Simulation Results

### Group Results

* Group A → Average = 79, Minimum = 69
* Group B → Average = 86, Minimum = 79
* Group C → Average = 79, Minimum = 65
* Group D → Average = 84, Minimum = 78

### Eliminated Group

✔ Group C

Group C was eliminated because it had the lowest individual score among groups with the same average.

## Technologies Used

* SystemVerilog
* RTL Design
* Computer Architecture
* Digital System Design
* Hardware Verification

---

## Files

* `eliminator.sv` → CPU Design
* `eliminator_tb.sv` → Testbench
* `marks.txt` → Input Marks
* `waveforms` → Simulation Results
* `report.pdf` → Project Report

---

## Learning Outcomes

This project improved my understanding of:

* Processor Architecture
* Custom ISA Design
* RTL Development
* Register and Memory Operations
* Simulation and Waveform Analysis
* Hardware-Based Algorithm Design
