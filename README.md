# RISCV-Tomasulu
Implementation of a single-issue RISC-V processor which reads in the instructions in memory and runs the instructions out of order. Follows the RISC-V instruction encodings as in the RISC-V specification. The out of order processor implements the Tomasulo algorithm with an 8-entry re-order buffer.
There is one execution unit for ADD, one for MUL/DIV (They are pipelined)
1. Issue and Write take one cycle each. So, if data is written to CDB in clock cycle `a', the data is
read from the reservation station or register in the next clock cycle `a+1'
2. Similarly, if execution completes in cycle `a', it is written to CDB in cycle `a+1' 
3. Latency: Add: 1 cycle. Mult: 10 cycles. Divide: 40 cycles, Load: 5 cycles
The MUL and DIV are part of the `M' extensions of RISC-V. Number of stages in the pipeline is 4.
The Tomasulo structure includes Reorder Buffer, RAT, also CDB is an important component of the design.

The Tomasulo algorithm based RISCV processor was implemented in Verilog.
The language provides the advantage of controlling the execution 
ow with inherit clock signal, also
the modeule can be synthesised , and programmed on FPGA without any extra coding constraint.
To model the Reservation stations, Load buer, Reorder Buer, Instruction memory, Architec-
tural registers, RAT using the classical memory dening technique reg [wordsize : 0]array name[0 :
arraysize]

The initial values of ARF and the instructions are loaded using rst input to the processor.
All the specications in the assignment are met!
1)If execution completes in cycle `a', it is written to CDB in cycle `a+1'
2)Latency: Add : 1 cycle. Mult: 10 cycles. Divide: 40 cycles, Load: 5 cycles
3)Issue and Write take one cycle each. So, if data is written to CDB in clock cycle `a', the data is
read from the reservation station or register in the next clock cycle `a+1'
4)single-issue RISC-V processor which reads in the instructions shown in the table and runs the
instructions out of order
5)Follow the RISC-V instruction encodings as in the RISC-V Specication.
6)RAT also needs to be a part of the design.
I have also made it easy to change the number of Reservation stations,ROB entries,ARF's,main
memory length.
The main memory is 8bit wide, 4*sizeOfMemory depth. And source value in LW results to 16 in
my case as I have loaded main memory[16] with 16
The instructions are decoded manually as :
LW R3, 0(R2) to 0000 0000 0000 0001 0010 0001 1000 0011
DIV R2, R3, R4 to 0000 0010 0100 0001 1100 0001 0011 0011
MUL R1, R5, R6 to 0000 0010 0110 0010 1000 0000 1011 0011
ADD R3, R7, R8 to 0000 0000 1000 0011 1000 0001 1011 0011
MUL R1, R1, R3 to 0000 0010 0011 0000 1000 0000 1011 0011
SUB R4, R1, R5 to 0100 0000 0101 0000 1000 0010 0011 0011
ADD R1, R4, R2 to 0000 0000 0010 0010 0000 0000 1011 0011

Clearly there is out of order execution scenario as rst MUL can be executed before the previous
instruction. Also the number of reservation stations is enough to not stall any instruction.
For obtaining the latency specied in the questions, counters are used to track number of clock cycles.
After every block I have added registers to store the intermediate results, inturn making use of
a pipelined structure.
I have also put in logic to stall the instruction fetch if reservation stations are full. But this condition
does not arise in our set of instructions.
Instructions fetch,decode and issue is done by a dispatch block. The lling of reservation stations is
also done here.
When the values of the instruction are available directly from ARF or after execute(from CDB) the
reservation station block recognises it, stores it in value column.
After considering the specied latency, the result is pushed to the CDB.
CDB is like a universal bus which holds the result of an execution. Any block which is anticipating
this result can read it from the CDB based on dest tag.
ROB is implemented as a circular buer, but with head and tail pointers. New entries are made at
the head. The instructions whose values are have been calculated and entered into ROB are written
into ARF using tail pointer, in order (in order write commit).
After hand calculation, the expected nal ARF content :
The result after commit for all instructions matches the calculated.

