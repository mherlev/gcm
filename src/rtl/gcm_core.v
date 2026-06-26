//======================================================================
//
// gcm_core.v
// ----------
// Galois Counter Mode core for AES.
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

module gcm_core(
                input wire            clk,
                input wire            reset_n,

                input wire            init,
                input wire            next,
                input wire            done,

                input wire            enc_dec,
                input wire            keylen,
                input wire [1 : 0]    taglen,

                output wire           ready,
                output wire           valid,
                output wire           tag_correct,

                input wire [255 : 0]  key,
                input wire [127 : 0]  nonce,
                input wire [127 : 0]  block_in,
                output wire [127 : 0] block_out,
                input wire [127 : 0]  tag_in,
                output wire [127 : 0] tag_out
               );

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam CTRL_IDLE        = 4'h0;
  localparam CTRL_INIT_AES    = 4'h1; // assert aes_init for one cycle
  localparam CTRL_WAIT_KEY    = 4'h2; // wait for AES key expansion
  localparam CTRL_INIT_H      = 4'h3; // assert aes_next with zero block
  localparam CTRL_WAIT_H      = 4'h4; // wait for AES to produce H
  localparam CTRL_INIT_GHASH  = 4'h5; // load H into GHASH, load nonce, assert ready
  localparam CTRL_NEXT_AES    = 4'h6; // assert aes_next with counter block
  localparam CTRL_WAIT_AES    = 4'h7; // wait for AES result, start GHASH
  localparam CTRL_WAIT_GHASH  = 4'h8; // wait for GHASH, assert valid


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [127 : 0] ctr_reg;
  reg [127 : 0] ctr_new;
  reg           ctr_we;

  reg [127 : 0] h_reg;
  reg [127 : 0] h_new;
  reg           h_we;

  reg [127 : 0] block_out_reg;
  reg [127 : 0] block_out_new;
  reg           block_out_we;

  reg           ready_reg;
  reg           ready_new;
  reg           ready_we;

  reg           valid_reg;
  reg           valid_new;
  reg           valid_we;

  reg [3 : 0]   gcm_ctrl_reg;
  reg [3 : 0]   gcm_ctrl_new;
  reg           gcm_ctrl_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg            aes_init;
  reg            aes_next;
  reg  [127 : 0] aes_block;
  wire           aes_encdec;
  wire           aes_ready;
  wire [127 : 0] aes_result;
  wire           aes_valid;

  reg            ctr_init;
  reg            ctr_next;

  reg            ghash_init;
  reg            ghash_next;
  wire           ghash_ready;
  reg [127 : 0]  ghash_h0;
  reg [127 : 0]  ghash_x;
  wire [127 : 0] ghash_y;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign aes_encdec  = 1'b1; // GCM only needs AES encryption
  assign ready       = ready_reg;
  assign valid       = valid_reg;
  assign tag_correct = 1'b0;
  assign block_out   = block_out_reg;
  assign tag_out     = 128'h0;


  //----------------------------------------------------------------
  // Core instantiations.
  //----------------------------------------------------------------
  aes_core aes(
               .clk(clk),
               .reset_n(reset_n),

               .encdec(aes_encdec),
               .init(aes_init),
               .next(aes_next),
               .ready(aes_ready),

               .key(key),
               .keylen(keylen),

               .block(aes_block),
               .result(aes_result),
               .result_valid(aes_valid)
              );


  gcm_ghash ghash(
                  .clk(clk),
                  .reset_n(reset_n),

                  .init(ghash_init),
                  .next(ghash_next),
                  .ready(ghash_ready),

                  .h(ghash_h0),
                  .block(ghash_x),
                  .y(ghash_y)
                 );


  //----------------------------------------------------------------
  // reg_update
  //----------------------------------------------------------------
  always @ (posedge clk)
    begin : reg_update
      if (!reset_n)
        begin
          ctr_reg      <= 128'h0;
          h_reg        <= 128'h0;
          block_out_reg <= 128'h0;
          ready_reg    <= 1'h0;
          valid_reg    <= 1'h0;
          gcm_ctrl_reg <= CTRL_IDLE;
        end
      else
        begin
          if (ctr_we)
            ctr_reg <= ctr_new;

          if (h_we)
            h_reg <= h_new;

          if (block_out_we)
            block_out_reg <= block_out_new;

          if (ready_we)
            ready_reg <= ready_new;

          if (valid_we)
            valid_reg <= valid_new;

          if (gcm_ctrl_we)
            gcm_ctrl_reg <= gcm_ctrl_new;
        end
    end // reg_update


  //----------------------------------------------------------------
  // ctr_logic
  //----------------------------------------------------------------
  always @*
    begin : ctr_logic
      ctr_new = 128'h0;
      ctr_we  = 1'h0;

      if (ctr_init)
        begin
          ctr_new = nonce;
          ctr_we  = 1'h1;
        end

      if (ctr_next)
        begin
          ctr_new = {ctr_reg[127 : 64], ctr_reg[63 : 0] + 1'b1};
          ctr_we  = 1'h1;
        end
    end // ctr_logic


  //----------------------------------------------------------------
  // gcm_core_ctrl_fsm
  //
  // CTRL_IDLE        — wait for init or next
  // CTRL_INIT_AES    — pulse aes_init to start key expansion
  // CTRL_WAIT_KEY    — wait for aes_ready (key expansion complete)
  // CTRL_INIT_H      — pulse aes_next with zero block to compute H
  // CTRL_WAIT_H      — wait for aes_ready, latch result as h_reg
  // CTRL_INIT_GHASH  — load H into gcm_ghash, load nonce, assert ready
  // CTRL_NEXT_AES    — pulse aes_next with ctr_reg to encrypt counter
  // CTRL_WAIT_AES    — wait for aes_ready, XOR with block_in, start GHASH
  // CTRL_WAIT_GHASH  — wait for ghash_ready, assert valid and ready
  //----------------------------------------------------------------
  always @*
    begin : gcm_core_ctrl_fsm
      aes_init      = 1'h0;
      aes_next      = 1'h0;
      aes_block     = block_in;
      ctr_init      = 1'h0;
      ctr_next      = 1'h0;
      ghash_init    = 1'h0;
      ghash_next    = 1'h0;
      ghash_h0      = h_reg;
      ghash_x       = 128'h0;
      h_new         = 128'h0;
      h_we          = 1'h0;
      block_out_new = 128'h0;
      block_out_we  = 1'h0;
      ready_new     = 1'h0;
      ready_we      = 1'h0;
      valid_new     = 1'h0;
      valid_we      = 1'h0;
      gcm_ctrl_new  = CTRL_IDLE;
      gcm_ctrl_we   = 1'h0;

      case (gcm_ctrl_reg)
        CTRL_IDLE:
          begin
            if (init)
              begin
                valid_new    = 1'h0;
                valid_we     = 1'h1;
                ready_new    = 1'h0;
                ready_we     = 1'h1;
                gcm_ctrl_new = CTRL_INIT_AES;
                gcm_ctrl_we  = 1'h1;
              end
            if (next)
              begin
                ctr_next     = 1'h1; // increment J0 → J1 before encrypting
                valid_new    = 1'h0;
                valid_we     = 1'h1;
                ready_new    = 1'h0;
                ready_we     = 1'h1;
                gcm_ctrl_new = CTRL_NEXT_AES;
                gcm_ctrl_we  = 1'h1;
              end
          end

        CTRL_INIT_AES:
          begin
            aes_init     = 1'h1;
            gcm_ctrl_new = CTRL_WAIT_KEY;
            gcm_ctrl_we  = 1'h1;
          end

        CTRL_WAIT_KEY:
          begin
            if (aes_ready)
              begin
                gcm_ctrl_new = CTRL_INIT_H;
                gcm_ctrl_we  = 1'h1;
              end
            else
              begin
                gcm_ctrl_new = CTRL_WAIT_KEY;
                gcm_ctrl_we  = 1'h1;
              end
          end

        CTRL_INIT_H:
          begin
            aes_next     = 1'h1;
            aes_block    = 128'h0; // encrypt zero block to get H = AES(K, 0)
            gcm_ctrl_new = CTRL_WAIT_H;
            gcm_ctrl_we  = 1'h1;
          end

        CTRL_WAIT_H:
          begin
            aes_block = 128'h0;
            if (aes_ready)
              begin
                h_new        = aes_result;
                h_we         = 1'h1;
                gcm_ctrl_new = CTRL_INIT_GHASH;
                gcm_ctrl_we  = 1'h1;
              end
            else
              begin
                gcm_ctrl_new = CTRL_WAIT_H;
                gcm_ctrl_we  = 1'h1;
              end
          end

        CTRL_INIT_GHASH:
          begin
            ghash_init   = 1'h1;
            ghash_h0     = h_reg;
            ctr_init     = 1'h1; // load nonce into ctr_reg so first next increments to J0+1
            ready_new    = 1'h1;
            ready_we     = 1'h1;
            gcm_ctrl_new = CTRL_IDLE;
            gcm_ctrl_we  = 1'h1;
          end

        CTRL_NEXT_AES:
          begin
            aes_next     = 1'h1;
            aes_block    = ctr_reg; // ctr_reg was already incremented in CTRL_IDLE
            gcm_ctrl_new = CTRL_WAIT_AES;
            gcm_ctrl_we  = 1'h1;
          end

        CTRL_WAIT_AES:
          begin
            aes_block = ctr_reg; // hold counter block for encipher (reads block combinatorially in CTRL_INIT)
            if (aes_ready)
              begin
                block_out_new = block_in ^ aes_result; // ciphertext = plaintext XOR keystream
                block_out_we  = 1'h1;
                ghash_next    = 1'h1;
                ghash_x       = block_in ^ aes_result; // GHASH authenticates ciphertext
                gcm_ctrl_new  = CTRL_WAIT_GHASH;
                gcm_ctrl_we   = 1'h1;
              end
            else
              begin
                gcm_ctrl_new = CTRL_WAIT_AES;
                gcm_ctrl_we  = 1'h1;
              end
          end

        CTRL_WAIT_GHASH:
          begin
            if (ghash_ready)
              begin
                valid_new    = 1'h1;
                valid_we     = 1'h1;
                ready_new    = 1'h1;
                ready_we     = 1'h1;
                gcm_ctrl_new = CTRL_IDLE;
                gcm_ctrl_we  = 1'h1;
              end
            else
              begin
                gcm_ctrl_new = CTRL_WAIT_GHASH;
                gcm_ctrl_we  = 1'h1;
              end
          end

        default:
          begin
          end
      endcase
    end // gcm_core_ctrl_fsm

endmodule // gcm_core

//======================================================================
// EOF gcm_core.v
//======================================================================
