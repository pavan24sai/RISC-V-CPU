# RISC-V_MYTH_Workshop - RISC-V Emulator

# RISC-V GNU Toolchain and Emulation
This repository demonstrates how to use the GNU Compiler Toolchain for RISC-V to compile, debug, and run RISC-V programs without physical hardware. The toolchain provides a complete environment for developing and testing RISC-V software.

## Toolchain Components and Emulation Process
The RISC-V GNU Toolchain enables development through:

1. **Cross-compilation** - Building RISC-V binaries on non-RISC-V hosts
2. **ISA simulation** - SPIKE provides cycle-accurate simulation
3. **System call emulation** - The proxy kernel translates between RISC-V and host OS
4. **Memory/register modeling** - Simulates RISC-V memory spaces and register states

The toolchain consists of these major components:
- **GCC Cross-Compiler** - Translates C/C++ to RISC-V assembly and machine code
- **Binutils** - Includes assembler, linker, and object file utilities
- **SPIKE Simulator** - Emulates a RISC-V processor
- **Proxy Kernel (pk)** - Provides system call services

## Compilation Workflow Example: Sum of Numbers 1 to 9
Let's walk through the compilation process using a simple example program:
```c
// sum1to9.c - Program to find the sum of numbers from 1 to 9
#include <stdio.h>

int main() {
    int sum = 0;
    for (int i = 1; i <= 9; i++) {
        sum += i;
    }
    printf("Sum of numbers 1 to 9: %d\n", sum);
    return 0;
}
```
### Compilation Steps
1. **Preprocessing** - Expands includes, resolves macros, removes comments:
   ```bash
   riscv64-unknown-elf-gcc -E sum1to9.c -o sum1to9.i
   ```
2. **Compilation to Assembly** - Translates C code to RISC-V assembly:
   ```bash
   riscv64-unknown-elf-gcc -S sum1to9.i -o sum1to9.s
   ```
3. **Assembly to Object Code** - Creates relocatable machine code:
   ```bash
   riscv64-unknown-elf-gcc -c sum1to9.s -o sum1to9.o
   ```
4. **Linking** - Combines objects with libraries for final executable:
   ```bash
   riscv64-unknown-elf-gcc sum1to9.o -o sum1to9
   ```
5. **All-in-One Command** - Typical usage with optimization:
   ```bash
   riscv64-unknown-elf-gcc -O2 -mabi=lp64 -march=rv64i -o sum1to9 sum1to9.c
   ```
### Key Compiler Flags
- **Optimization flags**: `-O0` (none), `-O1`, `-O2`, `-O3` (maximum), `-Os` (size), `-Ofast` (aggressive)
- **Architecture specifiers**: `-march=rv32i` (32-bit), `-march=rv64i` (64-bit), `-march=rv64g` (with extensions)
- **ABI specifiers**: `-mabi=ilp32` (for RV32), `-mabi=lp64` (for RV64)

## Running Programs with SPIKE
The SPIKE simulator emulates a RISC-V processor with:

```bash
spike pk sum1to9
```

This loads the executable into simulated memory and executes instructions, producing:
```
Sum of numbers 1 to 9: 45
```

### Execution Process
During execution:
1. SPIKE loads program code and data into simulated memory
2. Instructions are fetched, decoded, and executed
3. Register values change according to instructions
4. Memory is read/written as needed
5. System calls are handled through the proxy kernel

## Debugging with SPIKE
SPIKE includes a built-in debugger accessed with:

```bash
spike -d pk sum1to9
```

### Common Debug Commands
- **Run to location**: `until pc 0 10098`
- **View registers**: `reg 0` (all) or `reg 0 a0` (specific)
- **Examine memory**: `mem 0 2020`
- **View program counter**: `pc 0`
- **Single-step**: `step`
- **Disassemble**: `disasm 0 10098 20`

### Debug Workflow Example
Tracing through our sum1to9 loop:

```
# Find the loop
(spike) disasm 0 10098 20

# Set breakpoint at loop comparison
(spike) until pc 0 100a8

# Examine variables
(spike) reg 0 s0    # sum variable
(spike) reg 0 s1    # i variable

# Step through one iteration
(spike) step 10

# Continue to next iteration
(spike) until pc 0 100a8
```

## Advanced Usage
### Performance Analysis
Track instruction count and other metrics:

```bash
spike --ic pk sum1to9
```

### Multi-file Projects
For larger programs with multiple source files:

```bash
# Compile individual files
riscv64-unknown-elf-gcc -c -O2 -march=rv64i file1.c -o file1.o
riscv64-unknown-elf-gcc -c -O2 -march=rv64i file2.c -o file2.o

# Link all objects
riscv64-unknown-elf-gcc file1.o file2.o -o program
```

---

This toolchain enables us to develop and test RISC-V software without physical hardware, making it ideal for exploring CPU architecture concepts and testing custom RISC-V CPU core implementations.