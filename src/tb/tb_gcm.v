//======================================================================
//
// tb_gcm.v
// --------
// Testbench for the GCM core top level wrapper.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2016, Secworks Sweden AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================


//------------------------------------------------------------------
// Test module.
//------------------------------------------------------------------
module tb_gcm();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG = 0;

  parameter CLK_HALF_PERIOD = 2;
  parameter CLK_PERIOD = 2 * CLK_HALF_PERIOD;

  parameter TIMEOUT_CYCLES = 10000;

  // The address map.
  parameter ADDR_NAME0       = 8'h00;
  parameter ADDR_NAME1       = 8'h01;
  parameter ADDR_VERSION     = 8'h02;

  parameter ADDR_CTRL        = 8'h08;
  parameter CTRL_INIT_VALUE  = 8'h01;
  parameter CTRL_NEXT_VALUE  = 8'h02;
  parameter CTRL_DONE_VALUE  = 8'h04;

  parameter ADDR_STATUS      = 8'h09;
  parameter STATUS_READY_BIT = 0;
  parameter STATUS_VALID_BIT = 1;

  parameter ADDR_CONFIG      = 8'h0a;

  parameter ADDR_KEY0        = 8'h10;
  parameter ADDR_KEY1        = 8'h11;
  parameter ADDR_KEY2        = 8'h12;
  parameter ADDR_KEY3        = 8'h13;
  parameter ADDR_KEY4        = 8'h14;
  parameter ADDR_KEY5        = 8'h15;
  parameter ADDR_KEY6        = 8'h16;
  parameter ADDR_KEY7        = 8'h17;

  parameter ADDR_BLOCK0      = 8'h20;
  parameter ADDR_BLOCK1      = 8'h21;
  parameter ADDR_BLOCK2      = 8'h22;
  parameter ADDR_BLOCK3      = 8'h23;

  parameter ADDR_NONCE0      = 8'h30;
  parameter ADDR_NONCE1      = 8'h31;
  parameter ADDR_NONCE2      = 8'h32;
  parameter ADDR_NONCE3      = 8'h33;

  parameter ADDR_TAG0        = 8'h40;
  parameter ADDR_TAG1        = 8'h41;
  parameter ADDR_TAG2        = 8'h42;
  parameter ADDR_TAG3        = 8'h43;

  parameter ADDR_RESULT0     = 8'h50;
  parameter ADDR_RESULT1     = 8'h51;
  parameter ADDR_RESULT2     = 8'h52;
  parameter ADDR_RESULT3     = 8'h53;


  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0]  cycle_ctr;
  reg [31 : 0]  error_ctr;
  reg [31 : 0]  tc_ctr;

  reg           tb_clk;
  reg           tb_reset_n;
  reg           tb_cs;
  reg           tb_we;
  reg [7 : 0]   tb_address;
  reg [31 : 0]  tb_write_data;
  wire [31 : 0] tb_read_data;
  wire          tb_error;
  reg [31 : 0]  read_data;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  gcm dut(
          .clk(tb_clk),
          .reset_n(tb_reset_n),

          .cs(tb_cs),
          .we(tb_we),
          .address(tb_address),
          .write_data(tb_write_data),
          .read_data(tb_read_data)
         );


  //----------------------------------------------------------------
  // clk_gen
  //
  // Clock generator process.
  //----------------------------------------------------------------
  always
    begin : clk_gen
      #CLK_HALF_PERIOD tb_clk = !tb_clk;
    end // clk_gen


  //----------------------------------------------------------------
  // sys_monitor
  //
  // Generates a cycle counter and displays information about
  // the dut as needed.
  //----------------------------------------------------------------
  always
    begin : sys_monitor
      #(2 * CLK_HALF_PERIOD);
      cycle_ctr = cycle_ctr + 1;
    end


  //----------------------------------------------------------------
  // dump_dut_state()
  //
  // Dump the state of the dump when needed.
  //----------------------------------------------------------------
  task dump_dut_state;
    begin
      $display("State of DUT");
      $display("------------");
      $display("Inputs and outputs:");
      $display("cs = 0x%01x, we = 0x%01x",
               dut.cs, dut.we);
      $display("address = 0x%02x", dut.address);
      $display("write_data = 0x%08x, read_data = 0x%08x",
               dut.write_data, dut.read_data);
      $display("tmp_read_data = 0x%08x", dut.tmp_read_data);
      $display("");

      $display("Control and status:");
      $display("");
    end
  endtask // dump_dut_state


  //----------------------------------------------------------------
  // reset_dut()
  //
  // Toggles reset to force the DUT into a well defined state.
  //----------------------------------------------------------------
  task reset_dut;
    begin
      $display("*** Toggle reset.");
      tb_reset_n = 0;
      #(4 * CLK_HALF_PERIOD);
      tb_reset_n = 1;
    end
  endtask // reset_dut


  //----------------------------------------------------------------
  // init_sim()
  //
  // Initialize all counters and testbed functionality as well
  // as setting the DUT inputs to defined values.
  //----------------------------------------------------------------
  task init_sim;
    begin
      cycle_ctr = 32'h0;
      error_ctr = 32'h0;
      tc_ctr = 32'h0;

      tb_clk = 0;
      tb_reset_n = 0;
      tb_cs = 0;
      tb_we = 0;
      tb_address = 6'h0;
      tb_write_data = 32'h0;
    end
  endtask // init_dut


  //----------------------------------------------------------------
  // display_test_result()
  //
  // Display the accumulated test results.
  //----------------------------------------------------------------
  task display_test_result;
    begin
      if (error_ctr == 0)
        begin
          $display("*** All %02d test cases completed successfully.", tc_ctr);
        end
      else
        begin
          $display("*** %02d test cases completed.", tc_ctr);
          $display("*** %02d errors detected during testing.", error_ctr);
        end
    end
  endtask // display_test_result


  //----------------------------------------------------------------
  // wait_ready()
  //
  // Wait for the ready or valid flag in the dut to be set,
  // with a cycle timeout to prevent infinite loops when the
  // implementation is incomplete.
  //----------------------------------------------------------------
  task wait_ready;
    reg [31 : 0] wait_ctr;
    begin
      read_data = 0;
      wait_ctr  = 0;

      while (read_data == 0 && wait_ctr < TIMEOUT_CYCLES)
        begin
          read_word(ADDR_STATUS);
          wait_ctr = wait_ctr + 1;
        end

      if (wait_ctr == TIMEOUT_CYCLES)
        $display("TIMEOUT: DUT did not assert ready/valid within %0d cycles.", TIMEOUT_CYCLES);
    end
  endtask // wait_ready


  //----------------------------------------------------------------
  // write_key()
  //
  // Write a 256-bit key to the key registers.
  // For AES-128 only the upper 128 bits (key[255:128]) are used.
  //----------------------------------------------------------------
  task write_key(input [255 : 0] key);
    begin
      write_word(ADDR_KEY0, key[255 : 224]);
      write_word(ADDR_KEY1, key[223 : 192]);
      write_word(ADDR_KEY2, key[191 : 160]);
      write_word(ADDR_KEY3, key[159 : 128]);
      write_word(ADDR_KEY4, key[127 :  96]);
      write_word(ADDR_KEY5, key[ 95 :  64]);
      write_word(ADDR_KEY6, key[ 63 :  32]);
      write_word(ADDR_KEY7, key[ 31 :   0]);
    end
  endtask // write_key


  //----------------------------------------------------------------
  // write_nonce()
  //
  // Write a 128-bit nonce to the nonce registers.
  // NIST 96-bit IVs should be padded to 128-bit as: IV || 0x00000001
  //----------------------------------------------------------------
  task write_nonce(input [127 : 0] nonce);
    begin
      write_word(ADDR_NONCE0, nonce[127 : 96]);
      write_word(ADDR_NONCE1, nonce[ 95 : 64]);
      write_word(ADDR_NONCE2, nonce[ 63 : 32]);
      write_word(ADDR_NONCE3, nonce[ 31 :  0]);
    end
  endtask // write_nonce


  //----------------------------------------------------------------
  // write_block()
  //
  // Write a 128-bit plaintext block to the block registers.
  //----------------------------------------------------------------
  task write_block(input [127 : 0] block);
    begin
      write_word(ADDR_BLOCK0, block[127 : 96]);
      write_word(ADDR_BLOCK1, block[ 95 : 64]);
      write_word(ADDR_BLOCK2, block[ 63 : 32]);
      write_word(ADDR_BLOCK3, block[ 31 :  0]);
    end
  endtask // write_block


  //----------------------------------------------------------------
  // gcm_init()
  //
  // Load key and nonce, trigger key expansion, wait for ready.
  // Uses two-phase polling: wait for ready to deassert (init has
  // started) then reassert (init complete).  This avoids the
  // one-cycle propagation delay through gcm.v that causes a stale
  // ready=1 read when called immediately after a prior operation.
  //----------------------------------------------------------------
  task gcm_init(input [255 : 0] key, input keylen, input [127 : 0] nonce);
    reg [31 : 0] wait_ctr;
    begin
      write_key(key);
      write_nonce(nonce);
      write_word(ADDR_CONFIG, {6'h0, 2'h3, 5'h0, keylen, 1'b1}); // taglen=128, keylen, encdec=encrypt
      write_word(ADDR_CTRL, 32'h1);
      wait_ctr = 0;
      read_data = ~0;
      while (read_data[STATUS_READY_BIT] && wait_ctr < TIMEOUT_CYCLES)
        begin
          read_word(ADDR_STATUS);
          wait_ctr = wait_ctr + 1;
        end
      wait_ctr = 0;
      while (!read_data[STATUS_READY_BIT] && wait_ctr < TIMEOUT_CYCLES)
        begin
          read_word(ADDR_STATUS);
          wait_ctr = wait_ctr + 1;
        end
      if (wait_ctr == TIMEOUT_CYCLES)
        $display("TIMEOUT: gcm_init did not complete within %0d cycles.", TIMEOUT_CYCLES);
    end
  endtask // gcm_init


  //----------------------------------------------------------------
  // gcm_encrypt_block()
  //
  // Write a plaintext block, trigger encryption, wait for valid.
  //----------------------------------------------------------------
  task gcm_encrypt_block(input [127 : 0] plaintext);
    reg [31 : 0] wait_ctr;
    begin
      write_block(plaintext);
      write_word(ADDR_CTRL, 32'h2);
      wait_ctr = 0;
      read_data = 0;
      while (!read_data[STATUS_VALID_BIT] && wait_ctr < TIMEOUT_CYCLES)
        begin
          read_word(ADDR_STATUS);
          wait_ctr = wait_ctr + 1;
        end
      if (wait_ctr == TIMEOUT_CYCLES)
        $display("TIMEOUT: DUT did not assert valid within %0d cycles.", TIMEOUT_CYCLES);
    end
  endtask // gcm_encrypt_block


  //----------------------------------------------------------------
  // gcm_done()
  //
  // Assert the done command to finalise the authentication tag.
  // Waits for valid to first deassert (done started) then reassert
  // (tag computation complete).
  //----------------------------------------------------------------
  task gcm_done;
    reg [31 : 0] wait_ctr;
    begin
      write_word(ADDR_CTRL, CTRL_DONE_VALUE);
      wait_ctr = 0;
      read_data = ~0;
      while (read_data[STATUS_VALID_BIT] && wait_ctr < TIMEOUT_CYCLES)
        begin
          read_word(ADDR_STATUS);
          wait_ctr = wait_ctr + 1;
        end
      wait_ctr = 0;
      while (!read_data[STATUS_VALID_BIT] && wait_ctr < TIMEOUT_CYCLES)
        begin
          read_word(ADDR_STATUS);
          wait_ctr = wait_ctr + 1;
        end
      if (wait_ctr == TIMEOUT_CYCLES)
        $display("TIMEOUT: DUT did not complete tag generation within %0d cycles.", TIMEOUT_CYCLES);
    end
  endtask // gcm_done


  //----------------------------------------------------------------
  // write_word()
  //
  // Write the given word to the DUT using the DUT interface.
  //----------------------------------------------------------------
  task write_word(input [7 : 0]  address,
                  input [31 : 0] word);
    begin
      if (DEBUG)
        begin
          $display("*** Writing 0x%08x to 0x%02x.", word, address);
          $display("");
        end

      tb_address = address;
      tb_write_data = word;
      tb_cs = 1;
      tb_we = 1;
      #(CLK_PERIOD);
      tb_cs = 0;
      tb_we = 0;
    end
  endtask // write_word


  //----------------------------------------------------------------
  // read_word()
  //
  // Read a data word from the given address in the DUT.
  // the word read will be available in the global variable
  // read_data.
  //----------------------------------------------------------------
  task read_word(input [7 : 0]  address);
    begin
      tb_address = address;
      tb_cs = 1;
      tb_we = 0;
      #(CLK_PERIOD);
      read_data = tb_read_data;
      tb_cs = 0;

      if (DEBUG)
        begin
          $display("*** Reading 0x%08x from 0x%02x.", read_data, address);
          $display("");
        end
    end
  endtask // read_word


  //----------------------------------------------------------------
  // check_name_version()
  //
  // Read the name and version from the DUT.
  //----------------------------------------------------------------
  task check_name_version;
    reg [31 : 0] name0;
    reg [31 : 0] name1;
    reg [31 : 0] version;
    begin

      read_word(ADDR_NAME0);
      name0 = read_data;
      read_word(ADDR_NAME1);
      name1 = read_data;
      read_word(ADDR_VERSION);
      version = read_data;

      $display("DUT name: %c%c%c%c%c%c%c%c",
               name0[31 : 24], name0[23 : 16], name0[15 : 8], name0[7 : 0],
               name1[31 : 24], name1[23 : 16], name1[15 : 8], name1[7 : 0]);
      $display("DUT version: %c%c%c%c",
               version[31 : 24], version[23 : 16], version[15 : 8], version[7 : 0]);
    end
  endtask // check_name_version


  //----------------------------------------------------------------
  // reg_map_tests()
  //
  // Write known values to nonce and tag registers then read them
  // back.  Also verify that core_nonce and core_keylen are correctly
  // wired to the register file.  These tests exercise the three bugs
  // fixed in issue #9 and require no functional core logic.
  //----------------------------------------------------------------
  task reg_map_tests;
    reg [127 : 0] exp_nonce;
    reg [127 : 0] exp_tag;
    reg [127 : 0] got_nonce;
    reg [127 : 0] got_tag;
    begin
      $display("*** Register map tests started.");

      // TC_RM01: nonce write/readback
      // Write a distinct 32-bit word to each nonce register and read
      // each word back.  Before the fix these writes went to key_reg
      // and reads returned block_reg, so the values would not match.
      tc_ctr = tc_ctr + 1;
      $display("TC%02d: nonce register write/readback", tc_ctr);

      exp_nonce = 128'hdeadbeef_cafebabe_01234567_89abcdef;

      write_word(ADDR_NONCE0, exp_nonce[127 : 96]);
      write_word(ADDR_NONCE1, exp_nonce[ 95 : 64]);
      write_word(ADDR_NONCE2, exp_nonce[ 63 : 32]);
      write_word(ADDR_NONCE3, exp_nonce[ 31 :  0]);

      read_word(ADDR_NONCE0); got_nonce[127 : 96] = read_data;
      read_word(ADDR_NONCE1); got_nonce[ 95 : 64] = read_data;
      read_word(ADDR_NONCE2); got_nonce[ 63 : 32] = read_data;
      read_word(ADDR_NONCE3); got_nonce[ 31 :  0] = read_data;

      if (got_nonce !== exp_nonce) begin
        $display("TC%02d FAILED: nonce readback mismatch", tc_ctr);
        $display("  expected: %h", exp_nonce);
        $display("  got:      %h", got_nonce);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: nonce = %h", tc_ctr, got_nonce);

      // TC_RM02: tag input register write.
      // Bus reads at ADDR_TAG return tag_out_reg (computed output), so
      // verify the write landed in tag_reg via hierarchical reference.
      tc_ctr = tc_ctr + 1;
      $display("TC%02d: tag input register write (verified via dut.tag_reg)", tc_ctr);

      exp_tag = 128'h11223344_55667788_99aabbcc_ddeeff00;

      write_word(ADDR_TAG0, exp_tag[127 : 96]);
      write_word(ADDR_TAG1, exp_tag[ 95 : 64]);
      write_word(ADDR_TAG2, exp_tag[ 63 : 32]);
      write_word(ADDR_TAG3, exp_tag[ 31 :  0]);

      got_tag = {dut.tag_reg[0], dut.tag_reg[1],
                 dut.tag_reg[2], dut.tag_reg[3]};

      if (got_tag !== exp_tag) begin
        $display("TC%02d FAILED: tag_reg mismatch", tc_ctr);
        $display("  expected: %h", exp_tag);
        $display("  got:      %h", got_tag);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: tag_reg = %h", tc_ctr, got_tag);

      // TC_RM03: core_nonce wiring
      // After writing to the nonce registers, check that the wire
      // reaching gcm_core carries the same 128-bit value.
      tc_ctr = tc_ctr + 1;
      $display("TC%02d: core_nonce wiring", tc_ctr);

      if (dut.core_nonce !== exp_nonce) begin
        $display("TC%02d FAILED: core_nonce mismatch", tc_ctr);
        $display("  expected: %h", exp_nonce);
        $display("  got:      %h", dut.core_nonce);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: core_nonce = %h", tc_ctr, dut.core_nonce);

      // TC_RM04: core_keylen wiring
      // Write keylen=1 (AES-256) via CONFIG, then check the wire.
      tc_ctr = tc_ctr + 1;
      $display("TC%02d: core_keylen wiring", tc_ctr);

      write_word(ADDR_CONFIG, 32'h2); // bit1 = keylen = 1
      if (dut.core_keylen !== 1'b1) begin
        $display("TC%02d FAILED: core_keylen expected 1, got %b", tc_ctr, dut.core_keylen);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: core_keylen = %b", tc_ctr, dut.core_keylen);

      $display("*** Register map tests completed.");
    end
  endtask // reg_map_tests


  //----------------------------------------------------------------
  // result_readback_tests()
  //
  // Verify that ADDR_RESULT0-3 and ADDR_TAG0-3 exist in the register
  // map and return defined (non-X) values.  Ciphertext/tag correctness
  // cannot be checked until gcm_core is functional; those checks belong
  // in the NIST test cases once the core is complete (issue #14).
  //----------------------------------------------------------------
  task result_readback_tests;
    reg [127 : 0] result;
    reg [127 : 0] tag_out;
    begin
      $display("*** Result readback tests started.");

      // TC_RR01: result_reg exists and resets to zero.
      // Referencing dut.result_reg directly causes a compile error if the
      // register array has not been declared in gcm.v — this is the TDD
      // red step.  Bus readback at ADDR_RESULT0-3 must also return 0.
      tc_ctr = tc_ctr + 1;
      $display("TC%02d: result register reset value and bus readback", tc_ctr);

      result = {dut.result_reg[0], dut.result_reg[1],
                dut.result_reg[2], dut.result_reg[3]};

      read_word(ADDR_RESULT0); result[127 : 96] = read_data;
      read_word(ADDR_RESULT1); result[ 95 : 64] = read_data;
      read_word(ADDR_RESULT2); result[ 63 : 32] = read_data;
      read_word(ADDR_RESULT3); result[ 31 :  0] = read_data;

      if (result !== 128'h0) begin
        $display("TC%02d FAILED: expected 0 after reset, got %h", tc_ctr, result);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: result = %h (core stub, expect 0)", tc_ctr, result);

      // TC_RR02: tag_out_reg exists and resets to zero.
      // TAG reads must return the latched output register, not tag_reg.
      tc_ctr = tc_ctr + 1;
      $display("TC%02d: tag output register reset value and bus readback", tc_ctr);

      tag_out = {dut.tag_out_reg[0], dut.tag_out_reg[1],
                 dut.tag_out_reg[2], dut.tag_out_reg[3]};

      read_word(ADDR_TAG0); tag_out[127 : 96] = read_data;
      read_word(ADDR_TAG1); tag_out[ 95 : 64] = read_data;
      read_word(ADDR_TAG2); tag_out[ 63 : 32] = read_data;
      read_word(ADDR_TAG3); tag_out[ 31 :  0] = read_data;

      if (tag_out !== 128'h0) begin
        $display("TC%02d FAILED: expected 0 after reset, got %h", tc_ctr, tag_out);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: tag_out = %h (core stub, expect 0)", tc_ctr, tag_out);

      $display("*** Result readback tests completed.");
    end
  endtask // result_readback_tests


  //----------------------------------------------------------------
  // gcm_core_init_tests()
  //
  // Verify that CTRL_INIT in gcm_core properly runs AES key expansion
  // and computes H = AES(K, 0^128).
  //
  // TC_CI01: ready asserts after init (currently times out — red).
  // TC_CI02: h_reg holds the correct H value for K=0 (AES-128).
  //          Referencing dut.core.h_reg causes a compile error until
  //          the register is declared — this is the TDD red step.
  //----------------------------------------------------------------
  task gcm_core_init_tests;
    begin
      $display("*** GCM core init tests started.");

      reset_dut();

      // TC_CI01: AES-128 init completes — ready must assert without timeout
      tc_ctr = tc_ctr + 1;
      $display("TC%02d: AES-128 init completes (K=0, nonce=0)", tc_ctr);

      gcm_init(256'h0, 1'b0, 128'h0);

      read_word(ADDR_STATUS);
      if (!read_data[STATUS_READY_BIT]) begin
        $display("TC%02d FAILED: ready did not assert after init", tc_ctr);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: ready asserted after init", tc_ctr);

      // TC_CI02: H = AES_128(K=0, 0^128) = 66e94bd4ef8a2c3b884cfa59ca342b2e
      tc_ctr = tc_ctr + 1;
      $display("TC%02d: H = AES(K=0, 0^128) correct value", tc_ctr);

      if (dut.core.h_reg !== 128'h66e94bd4ef8a2c3b884cfa59ca342b2e) begin
        $display("TC%02d FAILED:", tc_ctr);
        $display("  expected: 66e94bd4ef8a2c3b884cfa59ca342b2e");
        $display("  got:      %h", dut.core.h_reg);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: h_reg = %h", tc_ctr, dut.core.h_reg);

      $display("*** GCM core init tests completed.");
    end
  endtask // gcm_core_init_tests


  //----------------------------------------------------------------
  // gcm_core_next_tests()
  //
  // Verify that CTRL_NEXT in gcm_core performs CTR encryption and
  // updates GHASH, then asserts valid.
  //
  // TC_CN01: valid bit in STATUS asserts after a next operation.
  //          Referencing dut.core.valid_reg causes a compile error
  //          until the register is declared — TDD red step.
  // TC_CN02: NIST SP 800-38D TC2 ciphertext is correct.
  //          K=0, IV=0 (J0=0x01), P=0 → C=0388dace60b6a392f328c2b971b2fe78
  //----------------------------------------------------------------
  task gcm_core_next_tests;
    reg [127 : 0] result;
    begin
      $display("*** GCM core CTRL_NEXT tests started.");

      reset_dut();

      // TC_CN01: valid asserts after AES-128 block encryption
      tc_ctr = tc_ctr + 1;
      $display("TC%02d: valid asserts after AES-128 encrypt (K=0, P=0)", tc_ctr);

      gcm_init(256'h0, 1'b0, 128'h00000000000000000000000000000001);
      gcm_encrypt_block(128'h0);

      read_word(ADDR_STATUS);
      if (!read_data[STATUS_VALID_BIT]) begin
        $display("TC%02d FAILED: valid did not assert (status=%08x, valid_reg=%b)",
                 tc_ctr, read_data, dut.core.valid_reg);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: valid asserted, status = %08x", tc_ctr, read_data);

      // TC_CN02: NIST TC2 ciphertext readable from ADDR_RESULT0-3
      tc_ctr = tc_ctr + 1;
      $display("TC%02d: NIST TC2 ciphertext = 0388dace60b6a392f328c2b971b2fe78", tc_ctr);

      read_word(ADDR_RESULT0); result[127 : 96] = read_data;
      read_word(ADDR_RESULT1); result[ 95 : 64] = read_data;
      read_word(ADDR_RESULT2); result[ 63 : 32] = read_data;
      read_word(ADDR_RESULT3); result[ 31 :  0] = read_data;

      if (result !== 128'h0388dace60b6a392f328c2b971b2fe78) begin
        $display("TC%02d FAILED:", tc_ctr);
        $display("  expected: 0388dace60b6a392f328c2b971b2fe78");
        $display("  got:      %h", result);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: ciphertext = %h", tc_ctr, result);

      $display("*** GCM core CTRL_NEXT tests completed.");
    end
  endtask // gcm_core_next_tests


  //----------------------------------------------------------------
  // gcm_tag_tests()
  //
  // Verify authentication tag generation via the done command.
  //
  // TC_TG01: NIST SP 800-38D TC2 tag correct after init+next+done.
  //          K=0, IV=0 (J0=0x01), P=0 → Tag=ab6e47d42cec13bdf53a67b21257bddf
  //          Referencing dut.core.tag_reg causes a compile error until
  //          the register is declared in gcm_core.v — TDD red step.
  //----------------------------------------------------------------
  task gcm_tag_tests;
    reg [127 : 0] tag;
    begin
      $display("*** GCM tag generation tests started.");

      reset_dut();

      tc_ctr = tc_ctr + 1;
      $display("TC%02d: NIST TC2 authentication tag (K=0, IV=0, P=0)", tc_ctr);

      gcm_init(256'h0, 1'b0, 128'h00000000000000000000000000000001);
      gcm_encrypt_block(128'h0);
      gcm_done();

      read_word(ADDR_TAG0); tag[127 : 96] = read_data;
      read_word(ADDR_TAG1); tag[ 95 : 64] = read_data;
      read_word(ADDR_TAG2); tag[ 63 : 32] = read_data;
      read_word(ADDR_TAG3); tag[ 31 :  0] = read_data;

      if (tag !== 128'hab6e47d42cec13bdf53a67b21257bddf) begin
        $display("TC%02d FAILED:", tc_ctr);
        $display("  expected: ab6e47d42cec13bdf53a67b21257bddf");
        $display("  got:      %h  (core tag_reg=%h)", tag, dut.core.tag_reg);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: tag = %h", tc_ctr, tag);

      $display("*** GCM tag generation tests completed.");
    end
  endtask // gcm_tag_tests


  //----------------------------------------------------------------
  // gcm_tests()
  //
  // End-to-end NIST SP 800-38D test vectors exercised through the
  // full register bus: init → next (encrypt) → done (tag).
  // https://csrc.nist.gov/publications/detail/sp/800-38d/final
  //----------------------------------------------------------------
  task gcm_tests;
    begin : gcm_tests
      // NIST SP 800-38D Test Case 2 — AES-128-GCM, single block
      // K   : 00000000000000000000000000000000
      // IV  : 000000000000000000000000 (96-bit, J0 = IV || 0x00000001)
      // P   : 00000000000000000000000000000000
      // A   : (empty)
      // C   : 0388dace60b6a392f328c2b971b2fe78
      // Tag : ab6e47d42cec13bdf53a67b21257bddf
      reg [255 : 0] tc2_key;
      reg [127 : 0] tc2_nonce;
      reg [127 : 0] tc2_plaintext;
      reg [127 : 0] tc2_result;
      reg [127 : 0] tc2_tag;

      // NIST SP 800-38D Test Case 14 — AES-256-GCM, single block
      // K   : 0000000000000000000000000000000000000000000000000000000000000000
      // IV  : 000000000000000000000000 (96-bit)
      // P   : 00000000000000000000000000000000
      // A   : (empty)
      // C   : cea7403d4d606b6e074ec5d3baf39d18
      // Tag : d0d1c8a799996bf0265b98b5d48ab919
      reg [255 : 0] tc14_key;
      reg [127 : 0] tc14_nonce;
      reg [127 : 0] tc14_plaintext;
      reg [127 : 0] tc14_result;
      reg [127 : 0] tc14_tag;

      $display("*** Testcases for gcm functionality started.");

      reset_dut();

      // -- TC2: AES-128-GCM — ciphertext --
      tc_ctr        = tc_ctr + 1;
      tc2_key       = 256'h0;
      tc2_nonce     = 128'h00000000000000000000000000000001;
      tc2_plaintext = 128'h0;

      $display("TC%02d: NIST TC2 AES-128-GCM ciphertext = 0388dace60b6a392f328c2b971b2fe78", tc_ctr);
      gcm_init(tc2_key, 1'b0, tc2_nonce);
      gcm_encrypt_block(tc2_plaintext);

      read_word(ADDR_RESULT0); tc2_result[127 : 96] = read_data;
      read_word(ADDR_RESULT1); tc2_result[ 95 : 64] = read_data;
      read_word(ADDR_RESULT2); tc2_result[ 63 : 32] = read_data;
      read_word(ADDR_RESULT3); tc2_result[ 31 :  0] = read_data;

      if (tc2_result !== 128'h0388dace60b6a392f328c2b971b2fe78) begin
        $display("TC%02d FAILED: expected 0388dace60b6a392f328c2b971b2fe78, got %h",
                 tc_ctr, tc2_result);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: ciphertext = %h", tc_ctr, tc2_result);

      // -- TC2: AES-128-GCM — tag --
      tc_ctr = tc_ctr + 1;
      $display("TC%02d: NIST TC2 AES-128-GCM tag = ab6e47d42cec13bdf53a67b21257bddf", tc_ctr);
      gcm_done();

      read_word(ADDR_TAG0); tc2_tag[127 : 96] = read_data;
      read_word(ADDR_TAG1); tc2_tag[ 95 : 64] = read_data;
      read_word(ADDR_TAG2); tc2_tag[ 63 : 32] = read_data;
      read_word(ADDR_TAG3); tc2_tag[ 31 :  0] = read_data;

      if (tc2_tag !== 128'hab6e47d42cec13bdf53a67b21257bddf) begin
        $display("TC%02d FAILED: expected ab6e47d42cec13bdf53a67b21257bddf, got %h",
                 tc_ctr, tc2_tag);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: tag = %h", tc_ctr, tc2_tag);

      // -- TC14: AES-256-GCM — ciphertext --
      tc_ctr         = tc_ctr + 1;
      tc14_key       = 256'h0;
      tc14_nonce     = 128'h00000000000000000000000000000001;
      tc14_plaintext = 128'h0;

      $display("TC%02d: NIST TC14 AES-256-GCM ciphertext = cea7403d4d606b6e074ec5d3baf39d18", tc_ctr);
      gcm_init(tc14_key, 1'b1, tc14_nonce);
      gcm_encrypt_block(tc14_plaintext);

      read_word(ADDR_RESULT0); tc14_result[127 : 96] = read_data;
      read_word(ADDR_RESULT1); tc14_result[ 95 : 64] = read_data;
      read_word(ADDR_RESULT2); tc14_result[ 63 : 32] = read_data;
      read_word(ADDR_RESULT3); tc14_result[ 31 :  0] = read_data;

      if (tc14_result !== 128'hcea7403d4d606b6e074ec5d3baf39d18) begin
        $display("TC%02d FAILED: expected cea7403d4d606b6e074ec5d3baf39d18, got %h",
                 tc_ctr, tc14_result);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: ciphertext = %h", tc_ctr, tc14_result);

      // -- TC14: AES-256-GCM — tag --
      tc_ctr = tc_ctr + 1;
      $display("TC%02d: NIST TC14 AES-256-GCM tag = d0d1c8a799996bf0265b98b5d48ab919", tc_ctr);
      gcm_done();

      read_word(ADDR_TAG0); tc14_tag[127 : 96] = read_data;
      read_word(ADDR_TAG1); tc14_tag[ 95 : 64] = read_data;
      read_word(ADDR_TAG2); tc14_tag[ 63 : 32] = read_data;
      read_word(ADDR_TAG3); tc14_tag[ 31 :  0] = read_data;

      if (tc14_tag !== 128'hd0d1c8a799996bf0265b98b5d48ab919) begin
        $display("TC%02d FAILED: expected d0d1c8a799996bf0265b98b5d48ab919, got %h",
                 tc_ctr, tc14_tag);
        error_ctr = error_ctr + 1;
      end else
        $display("TC%02d PASSED: tag = %h", tc_ctr, tc14_tag);

      $display("*** Testcases for gcm functionality completed.");
    end
  endtask // gcm_tests


  //----------------------------------------------------------------
  // gcm_test
  // The main test functionality.
  //----------------------------------------------------------------
  initial
    begin : gcm_test
      $display("   -- Testbench for gcm started --");

      init_sim();
      reset_dut();

      check_name_version();
      reg_map_tests();
      result_readback_tests();
      gcm_core_init_tests();
      gcm_core_next_tests();
      gcm_tag_tests();
      gcm_tests();

      display_test_result();

      $display("   -- Testbench for gcm done. --");
      $finish;
    end // gcm_test
endmodule // tb_gcm

//======================================================================
// EOF tb_gcm.v
//======================================================================
