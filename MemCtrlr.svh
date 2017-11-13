`ifndef MEM_CTRLR_H
  `define MEM_CTRLR_H

  `define CAS_LATENCY 3

  `define T_DPL     2     // Write to precharge time
  `define T_POWERUP 26600 // Powerup time
  `define T_RAS     6     // Row active time
  `define T_RC      9     // Activate to activate time (same bank)
  `define T_RCD     3     // Activate to read/write time
  `define T_RP      3     // Precharge to activate time
  `define T_RRD     2     // Activate to activate time (different banks)
  `define T_RSC     2     // MRS time
`endif
