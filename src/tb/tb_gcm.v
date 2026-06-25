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
  //----------------------------------------------------------------
  task gcm_init(input [255 : 0] key, input keylen, input [127 : 0] nonce);
    begin
      write_key(key);
      write_nonce(nonce);
      write_word(ADDR_CONFIG, {6'h0, 2'h3, 5'h0, keylen, 1'b1}); // taglen=128, keylen, encdec=encrypt
      write_word(ADDR_CTRL, 32'h1);
      wait_ready();
    end
  endtask // gcm_init


  //----------------------------------------------------------------
  // gcm_encrypt_block()
  //
  // Write a plaintext block, trigger encryption, wait for valid.
  //----------------------------------------------------------------
  task gcm_encrypt_block(input [127 : 0] plaintext);
    begin
      write_block(plaintext);
      write_word(ADDR_CTRL, 32'h2);
      wait_ready();
    end
  endtask // gcm_encrypt_block


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
  // gcm_tests()
  //
  // Test vectors from NIST SP 800-38D, Appendix B.
  // https://csrc.nist.gov/publications/detail/sp/800-38d/final
  //
  // Note: ciphertext readback is not yet implemented in the register
  // interface (gcm.v has no result registers). Tests currently verify
  // that init and encrypt sequences complete without timeout. Output
  // correctness checks should be added once result registers exist.
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

      $display("*** Testcases for gcm functionality started.");

      // -- TC2: AES-128-GCM --
      tc_ctr = tc_ctr + 1;
      $display("TC%02d: NIST SP 800-38D Test Case 2 (AES-128-GCM, single block)", tc_ctr);

      tc2_key       = 256'h0;
      tc2_nonce     = 128'h00000000000000000000000000000001; // IV=0 padded with counter=1
      tc2_plaintext = 128'h0;

      gcm_init(tc2_key, 1'b0, tc2_nonce);
      gcm_encrypt_block(tc2_plaintext);

      read_word(ADDR_STATUS);
      if (read_data[STATUS_VALID_BIT] || read_data[STATUS_READY_BIT])
        $display("TC%02d PASSED: init and encrypt completed.", tc_ctr);
      else
        begin
          $display("TC%02d FAILED: DUT not ready/valid after encrypt.", tc_ctr);
          error_ctr = error_ctr + 1;
        end

      // Expected ciphertext (not yet verifiable via register interface):
      // C   = 0388dace60b6a392f328c2b971b2fe78
      // Tag = ab6e47d42cec13bdf53a67b21257bddf

      // -- TC14: AES-256-GCM --
      tc_ctr = tc_ctr + 1;
      $display("TC%02d: NIST SP 800-38D Test Case 14 (AES-256-GCM, single block)", tc_ctr);

      tc14_key       = 256'h0;
      tc14_nonce     = 128'h00000000000000000000000000000001; // IV=0 padded with counter=1
      tc14_plaintext = 128'h0;

      gcm_init(tc14_key, 1'b1, tc14_nonce);
      gcm_encrypt_block(tc14_plaintext);

      read_word(ADDR_STATUS);
      if (read_data[STATUS_VALID_BIT] || read_data[STATUS_READY_BIT])
        $display("TC%02d PASSED: init and encrypt completed.", tc_ctr);
      else
        begin
          $display("TC%02d FAILED: DUT not ready/valid after encrypt.", tc_ctr);
          error_ctr = error_ctr + 1;
        end

      // Expected ciphertext (not yet verifiable via register interface):
      // C   = cea7403d4d606b6e074ec5d3baf39d18
      // Tag = d0d1c8a799996bf0265b98b5d48ab919

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
      gcm_tests();

      display_test_result();

      $display("   -- Testbench for gcm done. --");
      $finish;
    end // gcm_test
endmodule // tb_gcm

//======================================================================
// EOF tb_gcm.v
//======================================================================
