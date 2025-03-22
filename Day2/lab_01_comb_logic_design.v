\m5_TLV_version 1d: tl-x.org
\m5
   
   // =================================================
   // Welcome!  New to Makerchip? Try the "Learn" menu.
   // =================================================
   
   //use(m5-1.0)   /// uncomment to use M5 macro library.
\SV
   // Macro providing required top-level module definition, random
   // stimulus support, and Verilator config.
   m5_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV
   $reset = *reset;
   
   // SIMPLE COMB LOGIC
   $out_inv = !$in1; // inverter design
   $out_and = $in1 && $in2; // AND gate design
   $out_or  = $in1 || $in2; // OR gate design
   $out_xor = $in1 ^ $in2;  // XOR gate design
   
   // DEALING WITH VECTORS
   $out_vec[4:0] = $in_vec1[3:0] + $in_vec2[3:0];
   
   // MUX DESIGN
   $out_mux = $sel ? $in1 : $in2;
   $mux_out_vec[3:0] = $sel ? $in_vec1[3:0] : $in_vec2[3:0];
   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
\SV
   endmodule
