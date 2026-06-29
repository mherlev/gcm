//======================================================================
//
// tb_gcm_ghash.v
// --------------
// Testbench for the gcm_ghash GF(2^128) GHASH module.
//
// Directly instantiates gcm_ghash and drives it with algebraically
// verified test vectors.  Expected outputs are derived from GF(2^128)
// polynomial arithmetic properties rather than a reference model, so
// they can be checked without running external software.
//
// GCM bit-ordering convention used throughout:
//   element "1" (multiplicative identity) = 128'h80000000_00000000_00000000_00000000
//   element "x"                           = 128'h40000000_00000000_00000000_00000000
//
// Author: Mathias Herlev
//======================================================================

//------------------------------------------------------------------
// Test module.
//------------------------------------------------------------------
module tb_gcm_ghash();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter CLK_HALF_PERIOD = 2;
  parameter CLK_PERIOD      = 2 * CLK_HALF_PERIOD;
  parameter TIMEOUT_CYCLES  = 200;

  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0] cycle_ctr;
  reg [31 : 0] error_ctr;
  reg [31 : 0] tc_ctr;

  reg           tb_clk;
  reg           tb_reset_n;
  reg           tb_init;
  reg           tb_next;
  reg  [127 : 0] tb_h;
  reg  [127 : 0] tb_block;
  wire           tb_ready;
  wire [127 : 0] tb_y;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  gcm_ghash dut(
    .clk     (tb_clk),
    .reset_n (tb_reset_n),
    .init    (tb_init),
    .next    (tb_next),
    .h       (tb_h),
    .block   (tb_block),
    .ready   (tb_ready),
    .y       (tb_y)
  );


  //----------------------------------------------------------------
  // clk_gen
  //----------------------------------------------------------------
  always begin : clk_gen
    #CLK_HALF_PERIOD tb_clk = !tb_clk;
  end


  //----------------------------------------------------------------
  // sys_monitor
  //----------------------------------------------------------------
  always begin : sys_monitor
    #(CLK_PERIOD);
    cycle_ctr = cycle_ctr + 1;
  end


  //----------------------------------------------------------------
  // init_sim()
  //----------------------------------------------------------------
  task init_sim;
    begin
      cycle_ctr  = 32'h0;
      error_ctr  = 32'h0;
      tc_ctr     = 32'h0;
      tb_clk     = 0;
      tb_reset_n = 0;
      tb_init    = 0;
      tb_next    = 0;
      tb_h       = 128'h0;
      tb_block   = 128'h0;
    end
  endtask


  //----------------------------------------------------------------
  // reset_dut()
  //----------------------------------------------------------------
  task reset_dut;
    begin
      $display("*** Toggle reset.");
      tb_reset_n = 0;
      #(4 * CLK_HALF_PERIOD);
      tb_reset_n = 1;
    end
  endtask


  //----------------------------------------------------------------
  // display_test_result()
  //----------------------------------------------------------------
  task display_test_result;
    begin
      if (error_ctr == 0)
        $display("*** All %02d test cases completed successfully.", tc_ctr);
      else begin
        $display("*** %02d test cases completed.", tc_ctr);
        $display("*** %02d errors detected during testing.", error_ctr);
      end
    end
  endtask


  //----------------------------------------------------------------
  // wait_ready()
  //
  // Wait for gcm_ghash to assert ready.  Prints a timeout message
  // if ready does not arrive within TIMEOUT_CYCLES clocks.
  //----------------------------------------------------------------
  task wait_ready;
    reg [31 : 0] wait_ctr;
    begin
      wait_ctr = 0;
      while (!tb_ready && wait_ctr < TIMEOUT_CYCLES) begin
        #(CLK_PERIOD);
        wait_ctr = wait_ctr + 1;
      end
      if (wait_ctr == TIMEOUT_CYCLES)
        $display("TIMEOUT: gcm_ghash.ready did not assert within %0d cycles.", TIMEOUT_CYCLES);
    end
  endtask


  //----------------------------------------------------------------
  // ghash_init()
  //
  // Assert init for one clock so the module latches H and resets
  // the accumulator.  No need to wait for ready afterwards since
  // init does not change the FSM state.
  //----------------------------------------------------------------
  task ghash_init(input [127 : 0] h_val);
    begin
      tb_h    = h_val;
      tb_init = 1'b1;
      #(CLK_PERIOD);
      tb_init = 1'b0;
    end
  endtask


  //----------------------------------------------------------------
  // ghash_next()
  //
  // Assert next for one clock to process one 128-bit GHASH block,
  // then wait for the GF(2^128) multiplication to complete.
  //----------------------------------------------------------------
  task ghash_next(input [127 : 0] block_val);
    begin
      tb_block = block_val;
      tb_next  = 1'b1;
      #(CLK_PERIOD);
      tb_next  = 1'b0;
      wait_ready();
    end
  endtask


  //----------------------------------------------------------------
  // check_output()
  //
  // Compare tb_y against expected and update counters.
  //----------------------------------------------------------------
  task check_output(input [127 : 0] expected);
    begin
      tc_ctr = tc_ctr + 1;
      if (tb_y !== expected) begin
        $display("TC%02d FAILED:", tc_ctr);
        $display("  expected: %h", expected);
        $display("  got:      %h", tb_y);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: y = %h", tc_ctr, tb_y);
    end
  endtask


  //----------------------------------------------------------------
  // ghash_tests()
  //
  // TC01–TC05: algebraically self-verifiable corner cases.
  //
  //   TC01: H=0 means v stays 0 through all GMUL rounds → Y=0
  //   TC02: block=0 means x=0 XOR 0=0, no bit set → Y=0
  //   TC03: H is the GCM multiplicative identity "1" = 0x80..0,
  //         so Y = block * 1 = block
  //   TC04: H="x"=0x40..0, block="1"=0x80..0 → Y = 1*x = "x"
  //   TC05: Multi-block with H="1": after two blocks
  //         Y = (Y1 XOR block2) * 1 = block1 XOR block2
  //
  // TC06–TC09: NIST SP 800-38D cross-check via nettle_ghash_ref model.
  //   Expected values produced by test_nettle_ghash_ref.c; TC06/TC08
  //   are back-verified as GHASH_final XOR E(K,J0) == published tag.
  //
  //   TC06: TC2 (AES-128) single ciphertext block through GHASH
  //         H=66e94bd4..., C1=0388dace...
  //         → 5e2ec746917062882c85b0685353deb7
  //   TC07: TC2 (AES-128) full GHASH: C1 then len block
  //         → f38cbb1ad69223dcc3457ae5b6b0f885
  //         (XOR E(K,J0)=58e2fcce... = TC2 tag ab6e47d4... ✓)
  //   TC08: TC14 (AES-256) single ciphertext block through GHASH
  //         H_256=dc95c078..., C1_256=cea7403d...
  //         → fd6ab7586e556dba06d69cfe6223b262
  //   TC09: TC14 (AES-256) full GHASH: C1 then len block
  //         → 83de425c5edc5d498f382c441041ca92
  //----------------------------------------------------------------
  task ghash_tests;
    begin
      $display("*** Testcases for gcm_ghash started.");

      // TC01: H=0, any block → Y=0 (v=0 throughout all GMUL rounds)
      ghash_init(128'h0);
      ghash_next(128'h0102030405060708090a0b0c0d0e0f10);
      check_output(128'h0);

      // TC02: H=real, block=0 → Y=0 (x = y_prev XOR 0 = 0, no bits set)
      ghash_init(128'h66e94bd4ef8a2c3b884cfa59ca342b2e);
      ghash_next(128'h0);
      check_output(128'h0);

      // TC03: H="1"=0x80..0 (GCM identity element) → Y = block
      ghash_init(128'h80000000000000000000000000000000);
      ghash_next(128'h0102030405060708090a0b0c0d0e0f10);
      check_output(128'h0102030405060708090a0b0c0d0e0f10);

      // TC04: H="x"=0x40..0, block="1"=0x80..0 → Y = "x"
      ghash_init(128'h40000000000000000000000000000000);
      ghash_next(128'h80000000000000000000000000000000);
      check_output(128'h40000000000000000000000000000000);

      // TC05: Multi-block with H="1"
      ghash_init(128'h80000000000000000000000000000000);
      ghash_next(128'h0102030405060708090a0b0c0d0e0f10);
      ghash_next(128'h1112131415161718191a1b1c1d1e1f20);
      check_output(128'h10101010101010101010101010101030);

      // TC06: NIST TC2 — GHASH(H, [C1]) (model-derived)
      // H = AES(K=0, 0^128) = 66e94bd4ef8a2c3b884cfa59ca342b2e
      // C1 = AES(K, J0+1) XOR P = 0388dace60b6a392f328c2b971b2fe78
      ghash_init(128'h66e94bd4ef8a2c3b884cfa59ca342b2e);
      ghash_next(128'h0388dace60b6a392f328c2b971b2fe78);
      check_output(128'h5e2ec746917062882c85b0685353deb7);

      // TC07: NIST TC2 — GHASH(H, [C1 || len_block])
      // len_block = {len(A)=0, len(C)=128 bits} = 0x00000000000000000000000000000080
      // Result XOR E(K,J0)=58e2fccefa7e3061367f1d57a4e7455a = TC2 tag ab6e47d4... ✓
      ghash_init(128'h66e94bd4ef8a2c3b884cfa59ca342b2e);
      ghash_next(128'h0388dace60b6a392f328c2b971b2fe78);
      ghash_next(128'h00000000000000000000000000000080);
      check_output(128'hf38cbb1ad69223dcc3457ae5b6b0f885);

      // TC08: NIST TC14 — GHASH(H_256, [C1_256]) (model-derived)
      // H_256 = AES-256(K=0, 0^128) = dc95c078a2408989ad48a21492842087
      // C1_256 = cea7403d4d606b6e074ec5d3baf39d18
      ghash_init(128'hdc95c078a2408989ad48a21492842087);
      ghash_next(128'hcea7403d4d606b6e074ec5d3baf39d18);
      check_output(128'hfd6ab7586e556dba06d69cfe6223b262);

      // TC09: NIST TC14 — GHASH(H_256, [C1_256 || len_block]) (model-derived)
      ghash_init(128'hdc95c078a2408989ad48a21492842087);
      ghash_next(128'hcea7403d4d606b6e074ec5d3baf39d18);
      ghash_next(128'h00000000000000000000000000000080);
      check_output(128'h83de425c5edc5d498f382c441041ca92);

      $display("*** Testcases for gcm_ghash completed.");
    end
  endtask


  //----------------------------------------------------------------
  // The main test functionality.
  //----------------------------------------------------------------
  initial begin : ghash_test
    $display("   -- Testbench for gcm_ghash started --");

    init_sim();
    reset_dut();
    ghash_tests();
    display_test_result();

    $display("   -- Testbench for gcm_ghash done. --");
    $finish;
  end

endmodule // tb_gcm_ghash

//======================================================================
// EOF tb_gcm_ghash.v
//======================================================================
