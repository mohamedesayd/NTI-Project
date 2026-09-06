// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Matthias Baer - baermatt@student.ethz.ch                   //
//                                                                            //
// Additional contributions by:                                               //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    Subword multiplier and MAC                                 //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Advanced MAC unit for PULP.                                //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_mult
  import cv32e40p_pkg::*;
(
    input logic clk,
    input logic rst_n,

    input logic        enable_i, // enable from id_stage
    input mul_opcode_e operator_i, /* MUL_MAC32 = 3'b000,
                                      MUL_MSU32 = 3'b001,
                                      MUL_I     = 3'b010,
                                      MUL_IR    = 3'b011,
                                      MUL_DOT8  = 3'b100,
                                      MUL_DOT16 = 3'b101,
                                      MUL_H     = 3'b110 */

    // integer and short multiplier
    input logic       short_subword_i, // Selects which 16-bit subword to use from the 32-bit input operands.
                                       //0: Use lower 16 bits of the operands (op_a_i[15:0], op_b_i[15:0]).
                                       //1: Use upper 16 bits of the operands (op_a_i[31:16], op_b_i[31:16]).

    input logic [1:0] short_signed_i, // Controls whether each operand is treated as signed or unsigned.
                                      // short_signed_i[0]: Controls operand A (0 -> unsigned , 1 -> signed).
                                      // short_signed_i[1]: Controls operand B (0 -> unsigned , 1 -> signed).
    
    // Main operands for multiplication and accumulation:
    input logic [31:0] op_a_i,
    input logic [31:0] op_b_i,
    input logic [31:0] op_c_i,

    input logic [4:0] imm_i, //  Immediate/shift value used for rounding and positioning.


    // dot multiplier
    input logic [ 1:0] dot_signed_i, // Controls signed/unsigned mode for dot product operations.[same as short_signed_i]
                                     // dot_signed_i[0]: Controls operand B (0 -> unsigned , 1 -> signed).
                                     // dot_signed_i[1]: Controls operand A (0 -> unsigned , 1 -> signed).

    // Dot product operands and accumulator.                                 
    input logic [31:0] dot_op_a_i,
    input logic [31:0] dot_op_b_i,
    input logic [31:0] dot_op_c_i,

    input logic        is_clpx_i, // Enables complex number multiplication mode.
                                  // 0: Normal dot product mode.
                                  // 1: Complex multiplication mode.

    input logic [ 1:0] clpx_shift_i, // Controls right shift amount for complex multiplication results.

    input logic        clpx_img_i, // Selects which part of complex result goes to output.
                                   // 0: Output real part of complex multiplication
                                   // 1: Output imaginary part of complex multiplication.

    output logic [31:0] result_o, // The primary output of the MAC unit containing the multiplication result.

    output logic multicycle_o, // Indicates that the current operation requires multiple cycles.

    output logic mulh_active_o, // Indicates that the MULH state machine is currently active.
                                // 0: Normal operation (not MUL_H, or MUL_H completed).
                                // 1: MUL_H operation in progress (any state except IDLE).

    output logic ready_o, // Indicates that the MAC unit has completed its operation and result_o is valid.

    input  logic ex_ready_i // Pipeline control signal indicating the execution stage is ready to accept new instructions.
                            //When ex_ready_i = 1: Execution stage can accept new operation.
                            //When ex_ready_i = 0: Execution stage is stalled, MAC should hold current state.
);

  ///////////////////////////////////////////////////////////////
  //  ___ _  _ _____ ___ ___ ___ ___   __  __ _   _ _  _____   //
  // |_ _| \| |_   _| __/ __| __| _ \ |  \/  | | | | ||_   _|  //
  //  | || .  | | | | _| (_ | _||   / | |\/| | |_| | |__| |    //
  // |___|_|\_| |_| |___\___|___|_|_\ |_|  |_|\___/|____|_|    //
  //                                                           //
  ///////////////////////////////////////////////////////////////

  logic [16:0] short_op_a; // Signed/unsigned version of operand A's selected 16-bit subword.
  logic [16:0] short_op_b; // Signed/unsigned version of operand B's selected 16-bit subword.

  logic [32:0] short_op_c; // Extended accumulator value for MAC operations. {carry/extra_bit, 32-bit_accumulator}

  logic [33:0] short_mul; // The raw 17×17 multiplication result.

  logic [33:0] short_mac; // Multiply-Accumulate result (C + A×B + rounding).

  logic [31:0] short_round, short_round_tmp;  // Rounding constant for MUL_IR (Integer multiplication with rounding).
  logic [33:0] short_result;   // Final result after shifting/positioning.

  logic        short_mac_msb1; // These signals control the sign extension bits 
  logic        short_mac_msb0; // for arithmetic right shifts in the short multiplier.

  logic [ 4:0] short_imm; // Shift amount for the final right shift operation. 
                          // Normal mode: Uses external imm_i (for rounding shifts).
                          // MULH mode: Uses internal mulh_imm from state machine.

  logic [ 1:0] short_subword; // Selects which 16-bit subwords to use from 32-bit operands.
                              // Normal mode: Replicates short_subword_i to both bits (same selection for A and B)
                              //MULH mode: Uses state-machine controlled mulh_subword

  logic [ 1:0] short_signed; // Controls signed/unsigned mode for each operand.
                            // Normal mode: Uses external short_signed_i.
                            // MULH mode: Uses state-machine controlled mulh_signed.

  logic  short_shift_arith; //  Controls arithmetic vs logical right shift.
                            // Normal mode: Use short_signed_i[0] (arithmetic if operand A is signed).
                            // MULH mode: Uses state-machine controlled mulh_shift_arith.

  logic [ 4:0] mulh_imm; // State-machine controlled shift amount for MULH partial products.

  logic [ 1:0] mulh_subword; // State-machine controlled subword selection for MULH.

  logic [ 1:0] mulh_signed; // State-machine controlled signed mode for MULH partial products.

  logic        mulh_shift_arith; // state-machine controlled shift type for MULH.

  logic        mulh_carry_q; // Saved carry bit between MULH steps.

  logic        mulh_save; //Signal to save the carry bit from current partial product.

  logic        mulh_clearcarry; // Clears the saved carry bit.

  logic        mulh_ready; // Indicates MULH state machine is ready (result valid).

  mult_state_e mulh_CS, mulh_NS; // MULH State Machine States: (IDLE_MULT → STEP0 → STEP1 → STEP2 → FINISH → IDLE_MULT).

  // prepare the rounding value
  assign short_round_tmp = (32'h00000001) << imm_i;
  assign short_round = (operator_i == MUL_IR) ? {1'b0, short_round_tmp[31:1]} : '0;
  // short_round = (operator_i == MUL_IR) ? 0.5 × 2^imm_i :'0;

  // perform subword selection and sign extensions
  assign short_op_a[15:0] = short_subword[0] ? op_a_i[31:16] : op_a_i[15:0];
  assign short_op_b[15:0] = short_subword[1] ? op_b_i[31:16] : op_b_i[15:0];

  assign short_op_a[16] = short_signed[0] & short_op_a[15];
  assign short_op_b[16] = short_signed[1] & short_op_b[15];

  assign short_op_c = mulh_active_o ? $signed({mulh_carry_q, op_c_i}) : $signed(op_c_i);

  assign short_mul = $signed(short_op_a) * $signed(short_op_b);
  assign short_mac = $signed(short_op_c) + $signed(short_mul) + $signed(short_round);

  //we use only short_signed_i[0] as it cannot be short_signed_i[1] 1 and short_signed_i[0] 0
  assign short_result = $signed(
      {short_shift_arith & short_mac_msb1, short_shift_arith & short_mac_msb0, short_mac[31:0]}
  ) >>> short_imm;

  // >>> is arithmetic right shift (sign-preserving).

  // choose between normal short multiplication operation and mulh operation
  assign short_imm = mulh_active_o ? mulh_imm : imm_i;
  assign short_subword = mulh_active_o ? mulh_subword : {2{short_subword_i}};
  assign short_signed = mulh_active_o ? mulh_signed : short_signed_i;
  assign short_shift_arith = mulh_active_o ? mulh_shift_arith : short_signed_i[0];

  assign short_mac_msb1 = mulh_active_o ? short_mac[33] : short_mac[31];
  assign short_mac_msb0 = mulh_active_o ? short_mac[32] : short_mac[31];

  /* Example : 
   op_a_i[15:0] = 0x0007 (7)
   op_b_i[15:0] = 0x0003 (3)  
   imm_i = 3
   operator_i = MUL_IR
   short_signed_i = 2'b00 (unsigned)

1. Rounding: short_round = 0x00000004 (0.5 × 8)

2. Operand prep:
   short_op_a = 17'h00007 (unsigned 7)
   short_op_b = 17'h00003 (unsigned 3)

3. Multiplication:
   short_mul = 7 × 3 = 21 = 34'h00000015

4. Accumulation:
   short_op_c = 0 (no accumulator)
   short_mac = 0 + 21 + 4 = 25 = 34'h00000019

5. Sign extension:
   short_shift_arith = 0 (unsigned → logical shift)
   Extension = {0, 0, 25} = 34'h00000019

6. Shift:
   25 >>> 3 = 3 = 34'h00000003

Result: 0x00000003 (7×3=21, round to nearest multiple of 8 gives 24, 24/8=3) */


// MULH state machine
 /*
  A × B = (AH×BH)<<32 + (AH×BL + AL×BH)<<16 + AL×BL
    Where:
    AH = A[31:16], AL = A[15:0]
    BH = B[31:16], BL = B[15:0]
  */

  /* A = 0xFFFF_FFFD (-3) = AH=0xFFFF (-1), AL=0xFFFD (-3)
     B = 0x0000_0004 (+4) = BH=0x0000 (0), BL=0x0004 (4)
     short_signed_i = 2'b11 (both signed)
  */
  
  always_comb begin
    mulh_NS          = mulh_CS;
    mulh_imm         = 5'd0;
    mulh_subword     = 2'b00;
    mulh_signed      = 2'b00;
    mulh_shift_arith = 1'b0;
    mulh_ready       = 1'b0;
    mulh_active_o    = 1'b1;
    mulh_save        = 1'b0;
    mulh_clearcarry  = 1'b0;
    multicycle_o     = 1'b0;

    case (mulh_CS)
        IDLE_MULT: begin
          mulh_active_o = 1'b0;      // Not in MULH mode
          mulh_ready    = 1'b1;      // Ready for new operation
          mulh_save     = 1'b0;      // Don't save carry
          if ((operator_i == MUL_H) && enable_i) begin
            mulh_ready = 1'b0;       // Now busy
            mulh_NS    = STEP0;      // Start MULH
          end
        end

      STEP0: begin // Operation: AL × BL (low×low)
        multicycle_o  = 1'b1;      // Signal multi-cycle operation
        mulh_imm      = 5'd16;     // Shift result by 16 bits  (result goes to bits 31:16) 
        mulh_active_o = 1'b1;      // In MULH mode
        //AL*BL never overflows
        mulh_save     = 1'b0;      // No carry to save
        mulh_NS       = STEP1;     // Next state
        //Here always a 32'b unsigned result (no carry)
      end
      /*
      mulh_signed = 2'b00 (unsigned)
        AL × BL = (-3) × 4 = -12
        Shift by 16: -12 << 16 = -786,432 = 0xFFF4_0000
        Stored in op_c_i[31:16]
      */

      STEP1: begin // AL × BH
        multicycle_o     = 1'b1;
        //AL*BH is signed iff B is signed
        mulh_signed      = {short_signed_i[1], 1'b0}; // B signed, A unsigned
        mulh_subword     = 2'b10; // A low, B high
        // No shift (adds to bits 31:16)
        mulh_save        = 1'b1;  // Save carry
        mulh_shift_arith = 1'b1;  // Arithmetic shift
        mulh_NS          = STEP2;
        //Here signed 32'b + unsigned 32'b result.
        //Result is a signed 33'b
        //Store the carry as it will be used as sign extension, we do
        //not shift
      end
      /*
      mulh_signed = {1, 0} (B signed, A unsigned)
        AL × BH = (-3) × 0 = 0
        No shift: adds 0 to op_c_i[31:16]
        Save carry: short_mac[32] = 0 → mulh_carry_q = 0
      */


      STEP2: begin //AH × BL
        multicycle_o     = 1'b1;
        //AH*BL is signed iff A is signed
        mulh_signed      = {1'b0, short_signed_i[0]}; // A signed, B unsigned
        mulh_subword     = 2'b01; // A high, B low
        mulh_imm         = 5'd16; // Shift by 16 (adds to bits 47:32)
        mulh_save        = 1'b1;  // Save carry
        mulh_clearcarry  = 1'b1;  // Clear the carry
        mulh_shift_arith = 1'b1; // Arithmetic shift
        mulh_NS          = FINISH;
        //Here signed 32'b + signed 33'b result.
        //Result is a signed 34'b
        //We do not store the carries as the bits 34:33 are shifted back, so we clear it
      end
      /*
      mulh_signed = {0, 1} (A signed, B unsigned)
        AH × BL = (-1) × 4 = -4
        Shift by 16: -4 << 16 = -262,144 = 0xFFFC_0000
        Adds to op_c_i (now affecting upper bits)
        Clear carry: mulh_clearcarry = 1 → don't save
      */

      FINISH: begin //AH × BH 
        mulh_signed  = short_signed_i; // Original signedness
        mulh_subword = 2'b11; // A high, B high
        mulh_ready   = 1'b1;  // Result ready
        // No shift (occupies bits 63:32)
        if (ex_ready_i) mulh_NS = IDLE_MULT;
      end
      /*
      mulh_signed = 2'b11 (both signed)
        AH × BH = (-1) × 0 = 0
        No shift: adds 0 to upper 32 bits
        Final upper 32 bits = 0xFFFF_FFFF (-1)
      */
    endcase
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      mulh_CS      <= IDLE_MULT;
      mulh_carry_q <= 1'b0;
    end else begin
      mulh_CS <= mulh_NS;

      if (mulh_save) mulh_carry_q <= ~mulh_clearcarry & short_mac[32];
      else if (ex_ready_i)  // clear carry when we are going to the next instruction
        mulh_carry_q <= 1'b0;
    end
  end

  // 32x32 = 32-bit multiplier
  logic [31:0] int_op_a_msu;
  logic [31:0] int_op_b_msu;
  logic [31:0] int_result;

  logic        int_is_msu;

  assign int_is_msu = (operator_i == MUL_MSU32);

  assign int_op_a_msu = op_a_i ^ {32{int_is_msu}};
  assign int_op_b_msu = op_b_i & {32{int_is_msu}};

  assign int_result = $signed(
      op_c_i
  ) + $signed(
      int_op_b_msu
  ) + $signed(
      int_op_a_msu
  ) * $signed(
      op_b_i
  );

  ///////////////////////////////////////////////
  //  ___   ___ _____   __  __ _   _ _  _____  //
  // |   \ / _ \_   _| |  \/  | | | | ||_   _| //
  // | |) | (_) || |   | |\/| | |_| | |__| |   //
  // |___/ \___/ |_|   |_|  |_|\___/|____|_|   //
  //                                           //
  ///////////////////////////////////////////////

  logic [31:0] dot_char_result;
  logic [32:0] dot_short_result;
  logic [31:0] accumulator;
  logic [15:0] clpx_shift_result;
  logic [3:0][8:0] dot_char_op_a;
  logic [3:0][8:0] dot_char_op_b;
  logic [3:0][17:0] dot_char_mul;

  logic [1:0][16:0] dot_short_op_a;
  logic [1:0][16:0] dot_short_op_b;
  logic [1:0][33:0] dot_short_mul;
  logic      [16:0] dot_short_op_a_1_neg; //to compute -rA[31:16]*rB[31:16] -> (!rA[31:16] + 1)*rB[31:16] = !rA[31:16]*rB[31:16] + rB[31:16]
  logic [31:0] dot_short_op_b_ext;

  assign dot_char_op_a[0] = {dot_signed_i[1] & dot_op_a_i[7], dot_op_a_i[7:0]};
  assign dot_char_op_a[1] = {dot_signed_i[1] & dot_op_a_i[15], dot_op_a_i[15:8]};
  assign dot_char_op_a[2] = {dot_signed_i[1] & dot_op_a_i[23], dot_op_a_i[23:16]};
  assign dot_char_op_a[3] = {dot_signed_i[1] & dot_op_a_i[31], dot_op_a_i[31:24]};

  assign dot_char_op_b[0] = {dot_signed_i[0] & dot_op_b_i[7], dot_op_b_i[7:0]};
  assign dot_char_op_b[1] = {dot_signed_i[0] & dot_op_b_i[15], dot_op_b_i[15:8]};
  assign dot_char_op_b[2] = {dot_signed_i[0] & dot_op_b_i[23], dot_op_b_i[23:16]};
  assign dot_char_op_b[3] = {dot_signed_i[0] & dot_op_b_i[31], dot_op_b_i[31:24]};

  assign dot_char_mul[0] = $signed(dot_char_op_a[0]) * $signed(dot_char_op_b[0]);
  assign dot_char_mul[1] = $signed(dot_char_op_a[1]) * $signed(dot_char_op_b[1]);
  assign dot_char_mul[2] = $signed(dot_char_op_a[2]) * $signed(dot_char_op_b[2]);
  assign dot_char_mul[3] = $signed(dot_char_op_a[3]) * $signed(dot_char_op_b[3]);

  assign dot_char_result = $signed(
      dot_char_mul[0]
  ) + $signed(
      dot_char_mul[1]
  ) + $signed(
      dot_char_mul[2]
  ) + $signed(
      dot_char_mul[3]
  ) + $signed(
      dot_op_c_i
  );


  assign dot_short_op_a[0] = {dot_signed_i[1] & dot_op_a_i[15], dot_op_a_i[15:0]};
  assign dot_short_op_a[1] = {dot_signed_i[1] & dot_op_a_i[31], dot_op_a_i[31:16]};
  assign dot_short_op_a_1_neg = dot_short_op_a[1] ^ {17{(is_clpx_i & ~clpx_img_i)}}; //negates whether clpx_img_i is 0 or 1, only REAL PART needs to be negated

  assign dot_short_op_b[0] = (is_clpx_i & clpx_img_i) ? {
    dot_signed_i[0] & dot_op_b_i[31], dot_op_b_i[31:16]
  } : {
    dot_signed_i[0] & dot_op_b_i[15], dot_op_b_i[15:0]
  };
  assign dot_short_op_b[1] = (is_clpx_i & clpx_img_i) ? {
    dot_signed_i[0] & dot_op_b_i[15], dot_op_b_i[15:0]
  } : {
    dot_signed_i[0] & dot_op_b_i[31], dot_op_b_i[31:16]
  };

  assign dot_short_mul[0] = $signed(dot_short_op_a[0]) * $signed(dot_short_op_b[0]);
  assign dot_short_mul[1] = $signed(dot_short_op_a_1_neg) * $signed(dot_short_op_b[1]);

  assign dot_short_op_b_ext = $signed(dot_short_op_b[1]);
  assign accumulator = is_clpx_i ? dot_short_op_b_ext & {32{~clpx_img_i}} : $signed(dot_op_c_i);

  assign dot_short_result = $signed(
      dot_short_mul[0][31:0]
  ) + $signed(
      dot_short_mul[1][31:0]
  ) + $signed(
      accumulator
  );
  assign clpx_shift_result = $signed(dot_short_result[31:15]) >>> clpx_shift_i;

  ////////////////////////////////////////////////////////
  //   ____                 _ _     __  __              //
  //  |  _ \ ___  ___ _   _| | |_  |  \/  |_   ___  __  //
  //  | |_) / _ \/ __| | | | | __| | |\/| | | | \ \/ /  //
  //  |  _ <  __/\__ \ |_| | | |_  | |  | | |_| |>  <   //
  //  |_| \_\___||___/\__,_|_|\__| |_|  |_|\__,_/_/\_\  //
  //                                                    //
  ////////////////////////////////////////////////////////

  always_comb begin
    result_o = '0;

    unique case (operator_i)
      MUL_MAC32, MUL_MSU32: result_o = int_result[31:0];

      MUL_I, MUL_IR, MUL_H: result_o = short_result[31:0];

      MUL_DOT8: result_o = dot_char_result[31:0];
      MUL_DOT16: begin
        if (is_clpx_i) begin
          if (clpx_img_i) begin
            result_o[31:16] = clpx_shift_result;
            result_o[15:0]  = dot_op_c_i[15:0];
          end else begin
            result_o[15:0]  = clpx_shift_result;
            result_o[31:16] = dot_op_c_i[31:16];
          end
        end else begin
          result_o = dot_short_result[31:0];
        end
      end

      default: ;  // default case to suppress unique warning
    endcase
  end

  assign ready_o = mulh_ready;

  //----------------------------------------------------------------------------
  // Assertions
  //----------------------------------------------------------------------------

  // check multiplication result for mulh
`ifdef CV32E40P_ASSERT_ON
  assert property (
    @(posedge clk) ((mulh_CS == FINISH) && (operator_i == MUL_H) && (short_signed_i == 2'b11))
    |->
    (result_o == (($signed(
      {{32{op_a_i[31]}}, op_a_i}
  ) * $signed(
      {{32{op_b_i[31]}}, op_b_i}
  )) >>> 32)));

  // check multiplication result for mulhsu
  assert property (
    @(posedge clk) ((mulh_CS == FINISH) && (operator_i == MUL_H) && (short_signed_i == 2'b01))
    |->
    (result_o == (($signed(
      {{32{op_a_i[31]}}, op_a_i}
  ) * {
    32'b0, op_b_i
  }) >> 32)));

  // check multiplication result for mulhu
  assert property (
    @(posedge clk) ((mulh_CS == FINISH) && (operator_i == MUL_H) && (short_signed_i == 2'b00))
    |->
    (result_o == (({
    32'b0, op_a_i
  } * {
    32'b0, op_b_i
  }) >> 32)));
`endif
endmodule
