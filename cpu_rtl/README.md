# RISC-V_MYTH_Workshop - RISC-V Pipelined CPU Design

# Files - Overview
1. [risc_v_cpu_core](./risc_v_cpu_core.v) - Single cycle RISC-V CPU Design.
2. [risc_v_cpu_pipelined](./risc_v_cpu_pipelined.v) - Pipelined version of the RISC-V CPU. Breaks down the CPU into 4 stages.
3. [risc_v_cpu_improved_cpi](./risc_v_cpu_improved_cpi.v) - 5 stage pipelined CPU with improved CPI (by dealing with pipeline hazards).
4. [risc_v_cpu_pipelined_jmp_incl](./risc_v_cpu_pipelined_jmp_incl.v) - 5 stage pipelined CPU implementation. Added support for load/ store, and Jump instructions as well.

# RISC-V CPU Core Implementation
## Overview
This repository contains a complete implementation of a RISC-V CPU core using Transaction-Level Verilog (TL-Verilog). The implementation was developed as part of the Microprocessor for You in Thirty Hours (MYTH) workshop, focusing on building a functional RV32I CPU from scratch.

TL-Verilog extends traditional HDLs with timing abstract modeling, allowing for easier design, maintenance, and timing closure of digital circuits. The timing-abstract approach separates behavior and timing, making it significantly easier to retarget designs to different timing constraints.

## Architecture
The implemented CPU features a 5-stage pipeline architecture:

1. **Fetch Stage (@0)**: Handles PC (Program Counter) logic and fetches instructions from instruction memory
2. **Decode Stage (@1)**: Decodes instructions and extracts fields like opcodes, register addresses, and immediates
3. **Register Read Stage (@3)**: Reads operands from the register file
4. **Execute Stage (@3)**: Performs ALU operations, branch condition evaluation, and jump target calculation 
5. **Writeback Stage (@4)**: Writes results back to the register file and handles memory operations

The CPU implements the RV32I base integer instruction set, supporting all core RISC-V instructions including arithmetic, logical, memory, branch, and jump operations.

## Key Features

### Instruction Support
The implementation supports the complete RV32I base instruction set:

- **R-type**: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
- **I-type**: ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI, JALR, and load instructions
- **S-type**: Store instructions (SB, SH, SW)
- **B-type**: Branch instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
- **U-type**: LUI, AUIPC
- **J-type**: JAL

### Pipeline Hazard Handling
The CPU includes several mechanisms to handle pipeline hazards:

1. **Data Hazards**: Implements forwarding (bypass) logic to handle read-after-write hazards
2. **Control Hazards**: Handles branch and jump instructions with branch prediction and pipeline flushing
3. **Load-Store Hazards**: Includes detection and handling of load-after-store hazards

### Memory Interface
- **Instruction Memory**: Implemented using `m4+imem` macro at stage 1
- **Data Memory**: Implemented using `m4+dmem` macro at stage 4
- **Register File**: 32 x 32-bit registers implemented using `m4+rf` macro with read at stage 3 and write at stage 4

### Visualization Support
The design leverages Makerchip's visualization capabilities through the `m4+cpu_viz` macro, providing an intuitive view of CPU operation during simulation.

## Implementation Details

### PC Logic
The Program Counter logic handles:
- Reset to address 0
- Sequential advancement (PC+4)
- Redirection for branches and jumps
- Support for both direct (JAL) and indirect (JALR) jumps

```verilog
$pc[31:0] = $reset ? 32'd0 : >>1$next_pc[31:0];
   
$next_pc[31:0] =
  $reset ? 32'd0 :
  $is_jal   ? $br_tgt_pc[31:0] :
  $is_jalr  ? $jalr_tgt_pc[31:0] :
  $taken_br ? $br_tgt_pc[31:0] :  
             $pc[31:0] + 32'd4;
```

### Instruction Decode
The decoder extracts all necessary fields from the 32-bit RISC-V instruction:
- Instruction type identification (R/I/S/B/U/J)
- Opcode, function code, and register address extraction
- Immediate value generation based on instruction type

```verilog
$is_u_instr = $instr[6:2] ==? 5'b0x101;
$is_i_instr = $instr[6:2] ==? 5'b0000x || 
              $instr[6:2] ==? 5'b001x0 || 
              $instr[6:2] == 5'b11001;
// ... other instruction type decoding
```

### ALU Implementation
The Arithmetic Logic Unit (ALU) is the computational heart of the CPU, responsible for executing all arithmetic and logical operations specified by the instruction set. In our RISC-V implementation, the ALU supports a diverse range of operations from basic arithmetic (addition, subtraction) to comparisons and bit manipulations.

The ALU design features a multiplexer-based architecture that selects the appropriate operation based on instruction decoding signals. For each supported instruction, a dedicated computational path produces the corresponding result. Special handling is implemented for signed vs. unsigned operations, particularly for comparison instructions like SLT/SLTU.

```verilog
$result[31:0] = 
  // Integer arithmetic operations
  $is_addi   ? $src1_value + $imm :
  $is_add    ? $src1_value + $src2_value :
  $is_sub    ? $src1_value - $src2_value :
  
  // Logical bitwise operations
  $is_andi   ? $src1_value & $imm :
  $is_ori    ? $src1_value | $imm :
  $is_xori   ? $src1_value ^ $imm :
  $is_and    ? $src1_value & $src2_value :
  $is_or     ? $src1_value | $src2_value :
  $is_xor    ? $src1_value ^ $src2_value :
  
  // Shift operations
  $is_slli   ? $src1_value << $imm[5:0] :
  $is_srli   ? $src1_value >> $imm[5:0] :
  $is_sll    ? $src1_value << $src2_value[4:0] :
  $is_srl    ? $src1_value >> $src2_value[4:0] :
  
  // Comparison operations with special handling for signed values
  $is_sltu   ? $sltu_rslt :
  $is_sltiu  ? $sltiu_rslt :
  $is_slt    ? ($src1_value[31] == $src2_value[31]) ? 
                 $sltu_rslt :
                 {31'b0, $src1_value[31]} :
  $is_slti   ? ($src1_value[31] == $imm[31]) ?
                 $sltiu_rslt : 
                 {31'b0, $src1_value[31]} :
                 
  // Arithmetic shift operations preserving sign bit
  $is_sra    ? $sra_rslt[31:0] :
  $is_srai   ? $srai_rslt[31:0] :
  
  // Upper immediate and PC operations
  $is_lui    ? {$imm[31:12], 12'b0} :
  $is_auipc  ? $pc + $imm :
  
  // Jump operations return PC+4 as result
  $is_jal    ? $pc + 32'd4 :
  $is_jalr   ? $pc + 32'd4 :
  
  // Memory operation address calculation
  $is_load ? $src1_value[31:0] + $imm[31:0] :  
  $is_s_instr ? $src1_value[31:0] + $imm[31:0] :
  
  // Default case
  32'b0;
```

This implementation handles the complete RV32I instruction set through careful design of each operation path. Special attention is given to signed comparison operations (SLT, SLTI) which require checking sign bits separately from magnitude to correctly handle two's complement arithmetic. The ALU also handles address generation for memory operations and return address calculation for jumps.

### Branch Logic
The branch logic module evaluates conditions for all six RISC-V branch instructions, determining whether control flow should change based on register values. It implements precise RISC-V semantics for both signed and unsigned comparisons.

For signed comparisons (BLT, BGE), the implementation properly handles two's complement arithmetic by separately checking sign bit differences before magnitude comparison. This approach correctly handles edge cases around sign bit representation in two's complement. Unsigned comparisons (BLTU, BGEU) directly use magnitude comparisons.

```verilog
$taken_br = (
  // Equality comparisons
  $is_beq  ? ($src1_value == $src2_value) :
  $is_bne  ? ($src1_value != $src2_value) :
  
  // Signed comparisons with special handling for sign bits
  $is_blt  ? (($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31])) :
  $is_bge  ? (($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31])) :
  
  // Unsigned comparisons (direct magnitude comparison)
  $is_bltu ? ($src1_value < $src2_value) :
  $is_bgeu ? ($src1_value >= $src2_value) :
  
  // Default case
  1'b0);
```

When a branch is taken, the `$taken_br` signal is set, causing the pipeline to flush in-flight instructions and redirect the program counter to the branch target address. The target address is calculated by adding the sign-extended immediate value to the current PC.

```verilog
$br_tgt_pc[31:0] = $pc[31:0] + $imm[31:0];
```

This branch implementation efficiently supports all RISC-V conditional control flow operations while correctly handling numerical edge cases.

### Memory Operations
The memory subsystem handles both instruction fetches and data accesses (loads and stores). While instruction memory is read-only, data memory supports both read and write operations. The implementation includes proper address calculation, data alignment, and hazard detection.

For data memory operations, the system:
1. Calculates memory addresses using register + immediate offset
2. Controls read/write enables based on instruction type
3. Manages data transfer between registers and memory
4. Detects and handles memory access hazards

```verilog
// Memory address calculation (using bits [5:2] for word-aligned access)
$dmem_addr[3:0] = $result[5:2];

// Write enable active only for store instructions
$dmem_wr_en = $valid && $is_s_instr;

// Store the value from the second source register
$dmem_wr_data[31:0] = $src2_value;

// Read enable active only for load instructions
$dmem_rd_en = $valid && $is_load;
```

The implementation also includes special handling for load-after-store hazards, where a load operation accesses the same address as a recent store:

```verilog
// Detect load-after-store hazard
$load_after_store = $valid && $is_load && 
                   (>>1$valid && >>1$is_s_instr) && 
                   ($result[5:2] == >>1$result[5:2]);

// Forward stored data directly to load result when hazard detected
$ld_data[31:0] = $load_after_store ? >>1$src2_value : $dmem_rd_data;
```

This memory system design ensures correct program execution by maintaining memory coherence even with out-of-order memory accesses in the pipeline.

### Pipeline Control
The pipeline control logic orchestrates the flow of instructions through the CPU's stages while maintaining architectural correctness. It handles synchronization, hazard detection, and pipeline flushes to ensure that the processor's operation adheres to the sequential programming model despite parallel execution.

The control logic maintains a `$valid` signal that tracks which instructions should continue execution through the pipeline. Instructions must be invalidated after branches and jumps are taken to prevent incorrect execution of instructions that were fetched from the wrong path.

```verilog
// Validity control for pipeline stages
$valid = $reset ? 1'b0 :  // Reset invalidates all instructions
         $start ? 1'b1 :  // Start begins valid instruction flow
         
         // Invalidate after branch/jump redirections
         (>>1$valid_taken_br || >>2$valid_taken_br || 
          >>1$valid_jump || >>2$valid_jump) ? 1'b0 : 
         
         // Otherwise maintain validity
         1'b1;
```

The pipeline control tracks special conditions like `$valid_taken_br` (valid taken branch) and `$valid_jump` (valid jump instruction) to properly manage control flow changes. It also creates signals like `$valid_load` to track load instructions that will need register writeback in later cycles.

This control logic is critical for maintaining correct program execution in the pipelined architecture, especially when handling control hazards that could otherwise lead to incorrect instruction execution.

### Data Forwarding
Data forwarding (also called bypassing) is a critical feature that resolves data hazards in the pipeline by routing execution results directly to dependent instructions before they are written back to the register file. This mechanism allows back-to-back dependent instructions to execute without pipeline stalls.

The implementation detects situations where an instruction needs a register value that is still being computed by a previous instruction. Instead of waiting for the write to complete, it forwards the value directly from where it's available:

```verilog
// Source register values with forwarding from previous ALU result
$src1_value[31:0] = (>>1$rf_wr_en && (>>1$rd == $rs1)) ? >>1$result : $rf_rd_data1;
$src2_value[31:0] = (>>1$rf_wr_en && (>>1$rd == $rs2)) ? >>1$result : $rf_rd_data2;
```

This logic checks if:
1. The previous instruction will write to the register file (`>>1$rf_wr_en`)
2. The destination register of that instruction (`>>1$rd`) matches the source register of the current instruction (`$rs1` or `$rs2`)

If both conditions are true, the ALU result from the previous instruction (`>>1$result`) is forwarded directly to the current instruction's input, bypassing the register file access. Otherwise, the value is read normally from the register file.

The data forwarding logic dramatically improves pipeline efficiency by eliminating stalls that would otherwise be required for dependent instructions. This implementation focuses on the most common forwarding path (ALU result to ALU input), which resolves the majority of data hazards in typical code.

## Test Program
The implementation includes a test program to verify functionality, which computes the sum of integers from 1 to 9 and validates the result.

## Usage
This CPU implementation can be simulated in the Makerchip IDE:

1. Visit [makerchip.com](https://www.makerchip.com/)
2. Import the code from this repository
3. Compile and simulate
4. Explore CPU behavior using the visualization pane

## References
- [TL-Verilog Documentation](https://www.redwoodeda.com/tl-verilog)
- [RISC-V Specification](https://riscv.org/specifications/)
- [Makerchip IDE](https://www.makerchip.com/)
- [MYTH Workshop](https://github.com/stevehoover/RISC-V_MYTH_Workshop)