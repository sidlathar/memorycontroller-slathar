`default_nettype none
`include "mem_ctrlr.svh"

//////
////// Memory Controller 18-341
////// Chip Interface for Synthesis
//////
module ChipInterface (
  input logic CLOCK_50_2,
  input logic [0:0] BUTTON,
  input logic [9:0] SW,
  output logic [3:0] LEDG,
  output logic [11:0] DRAM_ADDR,
  inout wire [15:0] DRAM_DQ,
  output logic DRAM_BA_0, DRAM_BA_1,
  output logic DRAM_LDQM, DRAM_UDQM,
  output logic DRAM_WE_N, DRAM_CAS_N, DRAM_RAS_N,
  output logic DRAM_CS_N, DRAM_CLK, DRAM_CKE,
  output logic [6:0] HEX0_D, HEX1_D, HEX2_D, HEX3_D);

  logic clock, reset_n;
  logic pll_locked;

  logic ready;
  logic we, re;
  logic [21:0] addr;
  logic [15:0] data_to_ctrlr, data_to_hwtb;
  logic data_to_hwtb_valid;
  logic init_start, done;
  logic phase0_start, phase1_start, phase2_start, phase3_start;

  assign reset_n = BUTTON[0];
  assign DRAM_CKE = pll_locked;

  /*
   * This PLL is in zero-delay buffer mode, meaning inclock0 and c0 must be
   * directly connected to chip pads. The PLL that is connected to DRAM_CLK
   * happens to be connected to CLOCK_50_2 but not CLOCK_50.
   *
   * inclock0:  50 MHz
   * c0:        133 MHz, -3 ns phase (Think about why this is necessary :) )
   * c1:        133 MHz,  0 ns phase
   */
  clkgen
    pll_133 (.inclk0(CLOCK_50_2), .areset(~reset_n),
             .c0(DRAM_CLK), .c1(clock),
             .locked(pll_locked));

  MemCtrlr
    student_ctrlr (.clock, .reset_n,
                   .ready, .we, .re,
                   .addr, .data_in(data_to_ctrlr),
                   .data_out(data_to_hwtb), .data_out_valid(data_to_hwtb_valid),
                   .init_start(pll_locked), .done,
                   .phase0_start, .phase1_start, .phase2_start, .phase3_start,
                   .DRAM_DQ, .DRAM_ADDR(DRAM_ADDR[11:0]), .DRAM_BA_0,
                   .DRAM_BA_1, .DRAM_LDQM, .DRAM_UDQM, .DRAM_WE_N, .DRAM_CAS_N,
                   .DRAM_RAS_N, .DRAM_CS_N);

  HWTB
    hwtb_inst (.clock, .reset_n,
               .addr_out(addr), .data_out(data_to_ctrlr),
               .we_out(we), .re_out(re),
               .data_in(data_to_hwtb),
               .data_in_valid(data_to_hwtb_valid), .phase_ready(ready),
               .done,
               .phase0_start, .phase1_start, .phase2_start, .phase3_start,
               .SW, .LEDG, .HEX0_D, .HEX1_D, .HEX2_D, .HEX3_D);
endmodule : ChipInterface

extern module HWTB (
  input logic clock, reset_n,

  output logic [21:0] addr_out,
  output logic [15:0] data_out,
  output logic we_out, re_out,

  input logic [15:0] data_in,
  input logic data_in_valid,
  input logic phase_ready,

  output logic done,
  output logic phase0_start, phase1_start, phase2_start, phase3_start,

  input logic [9:0] SW,
  output logic [3:0] LEDG,
  output logic [6:0] HEX0_D, HEX1_D, HEX2_D, HEX3_D);

extern module MemCtrlr (
  input logic clock, reset_n,

  output logic ready,
  input logic we, re,
  input logic [21:0] addr,
  input logic [15:0] data_in,

  output logic [15:0] data_out,
  output logic data_out_valid,

  input logic init_start, done,
  input logic phase0_start, phase1_start, phase2_start, phase3_start,

  inout wire [15:0] DRAM_DQ,
  output logic [11:0] DRAM_ADDR,
  output logic DRAM_BA_0, DRAM_BA_1,
  output logic DRAM_LDQM, DRAM_UDQM,
  output logic DRAM_WE_N, DRAM_CAS_N, DRAM_RAS_N,
  output logic DRAM_CS_N);
