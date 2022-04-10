# RISCV-Tomasulu
Implementation of a single-issue RISC-V processor which reads in the instructions in memory and runs the instructions out of order. Follows the RISC-V instruction encodings as in the RISC-V specification. The out of order processor implements the Tomasulo algorithm with an 8-entry re-order buffer.
There is one execution unit for ADD, one for MUL/DIV (They are pipelined)
1. Issue and Write take one cycle each. So, if data is written to CDB in clock cycle `a', the data is
read from the reservation station or register in the next clock cycle `a+1'
2. Similarly, if execution completes in cycle `a', it is written to CDB in cycle `a+1' 
3. Latency: Add: 1 cycle. Mult: 10 cycles. Divide: 40 cycles, Load: 5 cycles
The MUL and DIV are part of the `M' extensions of RISC-V. Number of stages in the pipeline is 4.
The Tomasulo structure includes Reorder Buffer, RAT, also CDB is an important component of the design.
