# 32-bit IEEE 754 Multiplier with Design for Testability (DFT)

## Overview

This project presents a complete implementation of a 32-bit floating-point multiplier conforming to the IEEE 754 standard, incorporating Design for Testability (DFT) methodologies. The work was developed as part of the course **Test Structures in Physical Design of Integrated Circuits**, demonstrating the application of advanced testability concepts in the design of complex digital circuits.

## Objectives

- Implement a full IEEE 754 floating-point multiplier in SystemVerilog.
- Apply Design for Testability (DFT) techniques.
- Perform logic synthesis analysis for different operating frequencies.
- Evaluate quality metrics such as area, power, and timing.
- Compare the performance of different implementations (10MHz).
- Demonstrate proficiency in workflow automation for verification and testing.

## Multiplier Architecture

The implemented IEEE 754 multiplier features:

- **State Machine**: 5 main states controlling the execution flow.
- **Interface**: Standard input/output signals with handshake-based control.
- **Full Compliance**: Supports all special cases of the IEEE 754 standard:
  - Normalized and denormalized numbers.
  - Special values (NaN, infinity, zero).
  - Proper handling of exceptions.

## Methodology

The project followed a structured methodology:

1. **RTL Description**: Implementation in SystemVerilog with a focus on testability.
2. **Functional Verification**: Comprehensive testbench with test cases for full coverage.
3. **Logic Synthesis**: Using Cadence Genus with GPDK045 (45nm) technology.
4. **Design for Testability**: Implementation of scan chains and boundary scan.
5. **Automatic Test Pattern Generation (ATPG)**: Test pattern generation using Cadence Modus.
6. **Physical Analysis**: Layout, floorplanning, and routing.
7. **Timing Analysis**: Static Timing Analysis (STA) verification.
8. **Power Analysis**: Power estimation under different operating conditions.

## Results

### Logic Synthesis

Two versions of the multiplier were implemented for different target frequencies:

| Parameter       | 10MHz Version | 
|------------------|--------------
| Total Area       | 7537 µm²      | 
| Cells            | 1753          | 
| Slack            | 86.4ns        | 
| Power            | TBD           |
