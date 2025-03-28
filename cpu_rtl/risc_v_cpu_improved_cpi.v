\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/RISC-V_MYTH_Workshop
   
   m4_include_lib(['https://raw.githubusercontent.com/BalaDhinesh/RISC-V_MYTH_Workshop/master/tlv_lib/risc-v_shell_lib.tlv'])
\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV
   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program for MYTH Workshop to test RV32I
   // Add 1,2,3,...,9 (in that order).
   //
   // Regs:
   //  r10 (a0): In: 0, Out: final sum
   //  r12 (a2): 10
   //  r13 (a3): 1..10
   //  r14 (a4): Sum
   // 
   // External to function:
   m4_asm(ADD, r10, r0, r0)             // Initialize r10 (a0) to 0.
   // Function:
   m4_asm(ADD, r14, r10, r0)            // Initialize sum register a4 with 0x0
   m4_asm(ADDI, r12, r10, 1010)         // Store count of 10 in register a2.
   m4_asm(ADD, r13, r10, r0)            // Initialize intermediate sum register a3 with 0
   // Loop:
   m4_asm(ADD, r14, r13, r14)           // Incremental addition
   m4_asm(ADDI, r13, r13, 1)            // Increment intermediate register by 1
   m4_asm(BLT, r13, r12, 1111111111000) // If a3 is less than a2, branch to label named <loop>
   m4_asm(ADD, r10, r14, r0)            // Store final result to register a0 so that it can be read by main program
   // Test the Load & Store instructions
   m4_asm(SW, r0, r10, 10000)
   m4_asm(LW, r17, r0, 10000)
   
   // Optional:
   // m4_asm(JAL, r7, 00000000000000000000) // Done. Jump to itself (infinite loop). (Up to 20-bit signed immediate plus implicit 0 bit (unlike JALR) provides byte address; last immediate bit should also be 0)
   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)
   |cpu
      @0
         $reset = *reset;
         
         // Start signal remains here
         $start = >>1$reset && !$reset;
         
         // Next PC computation (moved before PC assignment to avoid circular dependency)
         $inc_pc[31:0] = $pc[31:0] + 32'd4;
         
         // PC logic - Modified to include load redirect
         $pc[31:0] = $reset ? 32'd0 :
                     >>3$valid_taken_br ? >>3$br_tgt_pc :
                     >>1$inc_pc;
      
      @1
         // Instruction Fetch
         $imem_rd_en = !$reset;
         $imem_rd_addr[M4_IMEM_INDEX_CNT-1:0] = $pc[M4_IMEM_INDEX_CNT+1:2];
         $instr[31:0] = $imem_rd_data[31:0];
         
         // Instruction Decode
         // Instruction type decode
         $is_u_instr = $instr[6:2] ==? 5'b0x101;
         
         $is_i_instr = $instr[6:2] ==? 5'b0000x ||
                       $instr[6:2] ==? 5'b001x0 ||
                       $instr[6:2] == 5'b11001;
         
         $is_r_instr = $instr[6:2] == 5'b01011 ||
                       $instr[6:2] == 5'b01100 ||
                       $instr[6:2] == 5'b01110 ||
                       $instr[6:2] == 5'b10100;
         
         // Use only one assignment for s_instr
         $is_s_instr = $instr[6:2] ==? 5'b0100x;
         
         $is_b_instr = $instr[6:2] == 5'b11000;
         
         $is_j_instr = $instr[6:2] == 5'b11011;
         
         // Instruction field extraction
         $funct7[6:0] = $instr[31:25];
         $funct3[2:0] = $instr[14:12];
         $rs1[4:0] = $instr[19:15];
         $rs2[4:0] = $instr[24:20];
         $rd[4:0] = $instr[11:7];
         $opcode[6:0] = $instr[6:0];
         
         // Field validity signals
         $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
         $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
         $rd_valid = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
         $imm_valid = $is_i_instr || $is_s_instr || $is_b_instr || $is_u_instr || $is_j_instr;
         
         // Immediate value creation based on instruction type
         $imm[31:0] = $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } :
                      $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7] } :
                      $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0 } :
                      $is_u_instr ? { $instr[31:12], 12'b0 } :
                      $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0 } :
                                     32'b0;
         
         // Decode specific instructions
         $dec_bits[10:0] = {$funct7[5], $funct3, $opcode};
         
         // Complete instruction decode for RV32I Base Instruction Set
         
         // U-type
         $is_lui   = $dec_bits ==? 11'bx_xxx_0110111;
         $is_auipc = $dec_bits ==? 11'bx_xxx_0010111;
         
         // J-type
         $is_jal   = $dec_bits ==? 11'bx_xxx_1101111;
         
         // I-type - Jump
         $is_jalr  = $dec_bits ==? 11'bx_000_1100111;
         
         // I-type - Arithmetic
         $is_addi  = $dec_bits ==? 11'bx_000_0010011;
         $is_slti  = $dec_bits ==? 11'bx_010_0010011;
         $is_sltiu = $dec_bits ==? 11'bx_011_0010011;
         $is_xori  = $dec_bits ==? 11'bx_100_0010011;
         $is_ori   = $dec_bits ==? 11'bx_110_0010011;
         $is_andi  = $dec_bits ==? 11'bx_111_0010011;
         
         // I-type - Shifts
         $is_slli  = $dec_bits ==? 11'b0_001_0010011;
         $is_srli  = $dec_bits ==? 11'b0_101_0010011;
         $is_srai  = $dec_bits ==? 11'b1_101_0010011;
         
         // R-type - Arithmetic
         $is_add   = $dec_bits ==? 11'b0_000_0110011;
         $is_sub   = $dec_bits ==? 11'b1_000_0110011;
         $is_sll   = $dec_bits ==? 11'b0_001_0110011;
         $is_slt   = $dec_bits ==? 11'b0_010_0110011;
         $is_sltu  = $dec_bits ==? 11'b0_011_0110011;
         $is_xor   = $dec_bits ==? 11'b0_100_0110011;
         $is_srl   = $dec_bits ==? 11'b0_101_0110011;
         $is_sra   = $dec_bits ==? 11'b1_101_0110011;
         $is_or    = $dec_bits ==? 11'b0_110_0110011;
         $is_and   = $dec_bits ==? 11'b0_111_0110011;
         
         // B-type - Branches
         $is_beq   = $dec_bits ==? 11'bx_000_1100011;
         $is_bne   = $dec_bits ==? 11'bx_001_1100011;
         $is_blt   = $dec_bits ==? 11'bx_100_1100011;
         $is_bge   = $dec_bits ==? 11'bx_101_1100011;
         $is_bltu  = $dec_bits ==? 11'bx_110_1100011;
         $is_bgeu  = $dec_bits ==? 11'bx_111_1100011;
         
         // Loads - identify based on opcode only (all load instructions)
         $is_load  = $opcode ==? 7'b0000011;
         
      @3
         // Register File Read
         $rf_rd_en1 = $rs1_valid;
         $rf_rd_index1[4:0] = $rs1;
         $rf_rd_en2 = $rs2_valid;
         $rf_rd_index2[4:0] = $rs2;
         
         // Define $rf_wr_en here, before it's referenced in Stage 3
         $rf_wr_en = ($valid && $rd_valid && ($rd != 5'b0)) ||  // Normal write for valid instructions
                     (>>2$valid_load);                          // Or write for load data 2 cycles later
         
         // Source register values with bypass logic
         $src1_value[31:0] = (>>1$rf_wr_en && (>>1$rd == $rs1)) ? >>1$result : $rf_rd_data1;
         $src2_value[31:0] = (>>1$rf_wr_en && (>>1$rd == $rs2)) ? >>1$result : $rf_rd_data2;
         
      @3
         // Updated valid logic - Clear in the shadow of a load or a branch
         $valid = $reset ? 1'b0 : 
                  $start ? 1'b1 :
                  (>>1$valid_taken_br || >>2$valid_taken_br) ? 1'b0 : 
                  1'b1;
         
         // Mark a valid load instruction
         $valid_load = $valid && $is_load;
         
         // Intermediate result signals as specified in the slide
         $sltu_rslt[31:0] = {31'b0, ($src1_value < $src2_value)};
         $sltiu_rslt[31:0] = {31'b0, ($src1_value < $imm)};
         
         // ALU - Implementing exactly as shown in the slide
         $result[31:0] = 
           // I-type arithmetic
           $is_andi  ? $src1_value & $imm :
           $is_ori   ? $src1_value | $imm :
           $is_xori  ? $src1_value ^ $imm :
           $is_addi  ? $src1_value + $imm :
           $is_slli  ? $src1_value << $imm[5:0] :
           $is_srli  ? $src1_value >> $imm[5:0] :
           
           // R-type logical/arithmetic
           $is_and   ? $src1_value & $src2_value :
           $is_or    ? $src1_value | $src2_value :
           $is_xor   ? $src1_value ^ $src2_value :
           $is_add   ? $src1_value + $src2_value :
           $is_sub   ? $src1_value - $src2_value :
           $is_sll   ? $src1_value << $src2_value[4:0] :
           $is_srl   ? $src1_value >> $src2_value[4:0] :
           
           // SLT/SLTI/SLTU/SLTIU operations using intermediate signals
           $is_sltu  ? $sltu_rslt :
           $is_sltiu ? $sltiu_rslt :
           $is_slt   ? ($src1_value[31] == $src2_value[31]) ? $sltu_rslt : {31'b0, $src1_value[31]} :
           $is_slti  ? ($src1_value[31] == $imm[31]) ? $sltiu_rslt : {31'b0, $src1_value[31]} :
           
           // Arithmetic shift operations
           $is_srai  ? { {32{$src1_value[31]}}, $src1_value} >> $imm[4:0] :
           $is_sra   ? { {32{$src1_value[31]}}, $src1_value} >> $src2_value[4:0] :
           
           // U-type, J-type, and I-type jump
           $is_lui   ? {$imm[31:12], 12'b0} :
           $is_auipc ? $pc + $imm :
           $is_jal   ? $pc + 4 :
           $is_jalr  ? $pc + 4 :
           
           // Load/Store address calculation (same as addi)
           $is_load || $is_s_instr ? $src1_value + $imm :
                      
           32'b0;  // Default
         
         // Branch Logic
         $taken_br = (
            $is_beq  ? ($src1_value == $src2_value) :
            $is_bne  ? ($src1_value != $src2_value) :
            $is_blt  ? (($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31])) :
            $is_bge  ? (($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31])) :
            $is_bltu ? ($src1_value < $src2_value) :
            $is_bgeu ? ($src1_value >= $src2_value) :
                       1'b0);
         
         // Valid taken branch signal
         $valid_taken_br = $valid && $taken_br;
         
         // Branch Target PC
         $br_tgt_pc[31:0] = $pc[31:0] + $imm[31:0];
         
         // Remove unused $jalr_tgt_pc or add it to BOGUS_USE
         
         // DMem signals
         $dmem_addr[3:0] = $result[5:2];  // Use address bits [5:2] for the data memory
         $dmem_wr_en = $valid && $is_s_instr;  // Enable write for store instructions
         $dmem_wr_data[31:0] = $src2_value;    // Store rs2 value
         $dmem_rd_en = $valid && $is_load;     // Enable read for load instructions
         
         // Add detection for store-to-load hazard
         $load_after_store = $valid && $is_load && 
                             (>>1$valid && >>1$is_s_instr) && 
                             ($result[5:2] == >>1$result[5:2]);
         
      @4
         // Data memory read with forwarding logic
         $ld_data[31:0] = $load_after_store ? >>1$src2_value : $dmem_rd_data;
         
         // Track load data and destination for writeback
         $valid_ld_data = $valid_load;
         $ld_rd[4:0] = $rd;
         
         // Register File Write with improved load handling
         $rf_wr_index[4:0] = >>2$valid_ld_data ? >>2$ld_rd : $rd;
         $rf_wr_data[31:0] = >>2$valid_ld_data ? >>2$ld_data : $result;
         
         // Until instructions are implemented, quiet down the warnings
         `BOGUS_USE($funct7 $opcode $imm_valid)
      
      // Note: Because of the magic we are using for visualisation, if visualisation is enabled below,
      //       be sure to avoid having unassigned signals (which you might be using for random inputs)
      //       other than those specifically expected in the labs. You'll get strange errors for these.
   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = |cpu/xreg[17]>>5$value == (1+2+3+4+5+6+7+8+9);
   *failed = 1'b0;
   
   // Macro instantiations for:
   //  o instruction memory
   //  o register file
   //  o data memory
   //  o CPU visualization
   |cpu
      m4+imem(@1)    // Args: (read stage)
      m4+rf(@3, @4)  // Args: (read stage, write stage) - read in stage 3, write in stage 4
      m4+dmem(@4)    // Args: (read/write stage)
   m4+cpu_viz(@4)    // For visualisation, argument should be at least equal to the last stage of CPU logic. @4 would work for all labs.
\SV
   endmodule