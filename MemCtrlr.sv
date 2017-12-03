`default_nettype none
`include "MemCtrlr.svh"

module MemCtrlr (
	input logic clock, reset_n,

	output logic ready,
	input logic we, re,
	input logic [21:0] addr,   //B1 B0...R11 R0...C8 C0
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

	//INITIALIZE START
	logic clk_cnt_inc, clk_cnt_clr;
	logic [31:0] clk_cnt;

	logic [2:0] CAS_LATENCY, BURST_LEN;
	logic [6:0] MRS_OPTIONS;

	logic DQM_H, PALL, REF, MRS, NOP_INIT;
	logic ready_init;

	/************************************ FSM ***********************************/

	enum logic [4:0] {INIT, POWERUP_WAIT, PRECHARGE,
	                TRP_WAIT, 
	                AUTO_REF_1, AUTO_REF_2, AUTO_REF_3, AUTO_REF_4,
	                AUTO_REF_5, AUTO_REF_6, AUTO_REF_7, AUTO_REF_8,
	                MODE_REG_SET, WAIT1, WAIT2} currState, nextState;

	//NS logic

	always_comb begin
		{DQM_H, PALL, REF, MRS, clk_cnt_inc, clk_cnt_clr, NOP_INIT} = 'b0000001;
		case (currState)
			INIT: begin
				if(init_start) begin
					DQM_H = 1;
					clk_cnt_clr = 1;

					nextState = POWERUP_WAIT;
				end
				else begin
					nextState = INIT;
				end
			end

			POWERUP_WAIT: begin
				if(clk_cnt != `T_POWERUP) begin
					clk_cnt_inc = 1;

					nextState = POWERUP_WAIT;
				end
				else begin
				 	PALL = 1;
					clk_cnt_clr = 1;

					nextState = PRECHARGE;
				end
			end

			PRECHARGE: begin
				clk_cnt_inc = 1;

				nextState = TRP_WAIT;
			end

			TRP_WAIT: begin
				if(clk_cnt != `T_RP) begin
					clk_cnt_inc = 1;

					nextState = TRP_WAIT;
				end
				else begin
					REF = 1;
					clk_cnt_clr = 1;

					nextState = AUTO_REF_1;
				end
			end

			AUTO_REF_1: begin
				if(clk_cnt != `T_RC) begin
					clk_cnt_inc = 1;

					nextState = AUTO_REF_1;
				end
				else begin
					REF = 1;
					clk_cnt_clr = 1;

					nextState = AUTO_REF_2;
				end
			end

			AUTO_REF_2: begin
				if(clk_cnt != `T_RC) begin
					clk_cnt_inc = 1;

					nextState = AUTO_REF_2;
				end
				else begin
					REF = 1;
					clk_cnt_clr = 1;

					nextState = AUTO_REF_3;
				end
			end

			AUTO_REF_3: begin
				if(clk_cnt != `T_RC) begin
					clk_cnt_inc = 1;

					nextState = AUTO_REF_3;
				end
				else begin
					REF = 1;
					clk_cnt_clr = 1;

					nextState = AUTO_REF_4;
				end
			end

			AUTO_REF_4: begin
				if(clk_cnt != `T_RC) begin
					clk_cnt_inc = 1;

					nextState = AUTO_REF_4;
				end
				else begin
					REF = 1;
					clk_cnt_clr = 1;

					nextState = AUTO_REF_5;
				end
			end

			AUTO_REF_5: begin
				if(clk_cnt != `T_RC) begin
					clk_cnt_inc = 1;

					nextState = AUTO_REF_5;
				end
				else begin
					REF = 1;
					clk_cnt_clr = 1;

					nextState = AUTO_REF_6;
				end
			end

			AUTO_REF_6: begin
				if(clk_cnt != `T_RC) begin
					clk_cnt_inc = 1;

					nextState = AUTO_REF_6;
				end
				else begin
					REF = 1;
					clk_cnt_clr = 1;

					nextState = AUTO_REF_7;
				end
			end

			AUTO_REF_7: begin
				if(clk_cnt != `T_RC) begin
					clk_cnt_inc = 1;

					nextState = AUTO_REF_7;
				end
				else begin
					REF = 1;
					clk_cnt_clr = 1;

					nextState = AUTO_REF_8;
				end
			end

			AUTO_REF_8: begin
				if(clk_cnt != `T_RC) begin
					clk_cnt_inc = 1;

					nextState = AUTO_REF_8;
				end
				else begin
					MRS = 1;
					clk_cnt_clr = 1;

					nextState = MODE_REG_SET;
				end
			end
			
			MODE_REG_SET: begin

				nextState = WAIT1;

			end

			WAIT1: begin
				
				nextState = WAIT2;
			end

			WAIT2: begin
				ready_init = 1;

				nextState = INIT;
			end
		endcase // currState
	end

	//END INITIALIZE


	//*******************PHASE TRACKING***********************//

	logic [31:0] phase_cnt;
	logic phase_cnt_inc_r, phase_cnt_inc_w;
	logic phase_cnt_clr, reading, writing;

	enum logic [3:0] {IDLE_P, PH0_W, PH0_R, PH1_W, PH1_R,
							PH2_W, PH2_R, PH3_W, PH3_R, STOP} currState_p, nextState_p;

	always_comb begin
		{phase_cnt_clr, writing, reading} = 3'b000;
		case (currState_p)
			IDLE_P: begin
				if(ready_init) begin
					phase_cnt_clr = 1;

					nextState_p = PH0_W;
				end
				else begin

					nextState_p = IDLE_P;
				end
			end

			PH0_W: begin
				if(phase_cnt == 32'b1) begin
					phase_cnt_clr = 1;

					nextState_p = PH0_R;
				end
				else begin
					writing = 1;

					nextState_p = PH0_W;
				end
			end

			PH0_R: begin
				if(phase_cnt == 32'b1) begin
					phase_cnt_clr = 1;
					
					nextState_p = PH1_W;
				end
				else begin
					reading = 1;

					nextState_p = PH0_R;
				end
			end

			//PHASE 0 DONE

			PH1_W: begin
				if(phase_cnt == 32'b10) begin
					phase_cnt_clr = 1;

					nextState_p = PH1_R;
				end
				else begin
					writing = 1;

					nextState_p = PH1_W;
				end
			end

			PH1_R: begin
				if(phase_cnt == 32'b10) begin
					phase_cnt_clr = 1;

					nextState_p = PH2_W;
				end
				else begin
					reading = 1;

					nextState_p = PH1_R;
				end
			end

			//PHASE 1 DONE

			PH2_W: begin
				if(phase_cnt == 32'b1000) begin
					phase_cnt_clr = 1;

					nextState_p = PH2_R;
				end
				else begin
					writing = 1;

					nextState_p = PH2_W;
				end
			end

			PH2_R: begin
				if(phase_cnt == 32'b1000) begin
					phase_cnt_clr = 1;

					nextState_p = PH3_W;
				end
				else begin
					reading = 1;

					nextState_p = PH2_R;
				end
			end

			//PHASE 2 DONE

			PH3_W: begin
				if(phase_cnt == 32'b1000) begin
					phase_cnt_clr = 1;

					nextState_p = PH3_R;
				end
				else begin
					writing = 1;

					nextState_p = PH3_W;
				end
			end

			PH3_R: begin
				if(phase_cnt == 32'b1000) begin
					phase_cnt_clr = 1;

					nextState_p = STOP;
				end
				else begin
					reading = 1;

					nextState_p = PH3_R;
				end
			end

			//PHASE 3 DONE

			STOP: begin
				if(~reset_n) begin
					nextState_p = IDLE_P;
				end
				else begin
					nextState_p = STOP;
				end
			end

		endcase // currState_p
	end


	//****************WRITE***********************//

	logic clk_cnt_inc_w, clk_cnt_clr_w;
	logic [31:0] clk_cnt_w;
	logic ACT_W, WRITEA, NOP_W;

	logic load_data; //load for data and address of write
	logic ready_w; //ready to write
	logic send_write_data;

	enum logic [2:0] {IDLE_W, LOAD_DATA_W, ACTIVATE_W, DO_WRITE} currState_w, nextState_w;

	//NS logic

	always_comb begin
		{load_data, ready_w, send_write_data, WRITEA, ACT_W, NOP_W} = 6'b00000_1;
		case (currState_w)
			IDLE_W: begin
				if(!we && writing) begin
					ready_w = 1;

					nextState_w = IDLE_W;
				end
				else begin
					phase_cnt_inc_w = 1;
					load_data = 1;

					nextState_w = LOAD_DATA_W;
				end
			end

			LOAD_DATA_W: begin
				ACT_W = 1;
				clk_cnt_clr_w = 1;

				nextState_w = ACTIVATE_W;
			end

			ACTIVATE_W: begin
				if(clk_cnt_w != `T_RCD) begin
					clk_cnt_inc_w = 1;

					nextState_w = ACTIVATE_W;
				end
				else begin
					WRITEA = 1;
					clk_cnt_clr_w = 1;
					send_write_data = 1;
					nextState_w = DO_WRITE;
				end
			end

			DO_WRITE: begin
				if(clk_cnt_w != `T_RC - `T_RCD) begin
					clk_cnt_inc_w = 1;

					nextState_w = DO_WRITE;
				end
				else begin
					ready_w = 1;

					nextState_w = IDLE_W;
				end
			end
		endcase // currState_w
	end


	//END WRITE


	//******************READ START******************//
	logic clk_cnt_inc_r, clk_cnt_clr_r;
	logic [31:0] clk_cnt_r;
	logic ACT_R, READA, NOP_R;

	logic load_data_addr; //load for address of read
	logic ready_r; //ready to read
	logic load_read_data;

	enum logic [2:0] {IDLE_R, LOAD_DATA_R, ACTIVATE_R, DO_READ} currState_r, nextState_r;

	//NS logic

	always_comb begin
		{load_data_addr, ready_r, load_read_data, ACT_R, READA, NOP_R} = 6'b00000_1;
		case (currState_r)
			IDLE_R: begin
				if(!re && reading) begin
					ready_r = 1;

					nextState_r = IDLE_R;
				end
				else begin
					load_data_addr = 1;
					phase_cnt_inc_r = 1;

					nextState_r = LOAD_DATA_R;
				end
			end

			LOAD_DATA_R: begin
				ACT_R = 1;
				clk_cnt_clr_r = 1;

				nextState_r = ACTIVATE_R;
			end

			ACTIVATE_R: begin
				if(clk_cnt_r != `T_RCD) begin
					clk_cnt_inc_r = 1;

					nextState_r = ACTIVATE_R;
				end
				else begin
					READA = 1;
					clk_cnt_clr_r = 1;

					nextState_r = DO_READ;
				end
			end
			
			DO_READ: begin
				if(clk_cnt_r != `T_RC - `T_RCD) begin
					if(clk_cnt_r == `CAS_LATENCY) begin
						load_read_data = 1; 
					end
					clk_cnt_inc_r = 1;

					nextState_r = DO_READ;
				end
				else begin
					ready_r = 1;

					nextState_r = IDLE_R;
				end
			end
		endcase // currState_r
	end

	//END READ

	assign ready = (ready_w || ready_r);

	//CLK CNT FOR INIT
	always_ff @(posedge clock, negedge reset_n) begin
		if(~reset_n) begin
			 clk_cnt <= 0;
		end else begin
			 if(clk_cnt_inc) begin
			 	clk_cnt <= clk_cnt + 1;
			 end
			 else if(clk_cnt_clr) begin
			 	clk_cnt <= 0;
			 end
		end
	end

	//CLK CNT FOR READ
	always_ff @(posedge clock, negedge reset_n) begin
		if(~reset_n) begin
			 clk_cnt_r <= 0;
		end else begin
			 if(clk_cnt_inc_r) begin
			 	clk_cnt_r <= clk_cnt_r + 1;
			 end
			 else if(clk_cnt_clr_r) begin
			 	clk_cnt_r <= 0;
			 end
		end
	end

	//CLK CNT FOR WRITE
	always_ff @(posedge clock, negedge reset_n) begin
		if(~reset_n) begin
			 clk_cnt_w <= 0;
		end else begin
			 if(clk_cnt_inc_w) begin
			 	clk_cnt_w <= clk_cnt_w + 1;
			 end
			 else if(clk_cnt_clr_w) begin
			 	clk_cnt_w <= 0;
			 end
		end
	end

	//PHASE COUNT
	always_ff @(posedge clock, negedge reset_n) begin
		if(~reset_n) begin
			 phase_cnt <= 0;
		end else begin
			 if(phase_cnt_inc_r || phase_cnt_inc_w) begin
			 	phase_cnt <= phase_cnt + 1;
			 end
			 else if(phase_cnt_clr) begin
			 	phase_cnt <= 0;
			 end
		end
	end


	//ADDRESS LOAD FOR READ AND WRITE
	logic [21:0] addr_reg;
	always_ff @(posedge clock, negedge reset_n) begin
		if(~reset_n) begin
			addr_reg <= 0;
		end else begin
			if(load_data_addr || load_data) begin
				addr_reg <= addr;
			end
		end
	end

	//DATA LOAD FOR WRITE
	logic [15:0] data_reg;
	always_ff @(posedge clock, negedge reset_n) begin
		if(~reset_n) begin
			data_reg <= 0;
		end else begin
			if(load_data) begin
				data_reg <= data_in;
			end
		end
	end

	//DATA INOUT
	always_ff @(posedge clock, negedge reset_n) begin
		if(~reset_n) begin
			DRAM_DQ <= 'Z;
		end else begin 
			if(load_read_data) begin
				data_out <= DRAM_DQ;
				data_out_valid <= 1;
			end
			else if(send_write_data) begin
				DRAM_DQ <= data_reg;
			end
		end
	end


	// inout wire [15:0] DRAM_DQ,
	// output logic [11:0] DRAM_ADDR,
	// output logic DRAM_BA_0, DRAM_BA_1,
	// output logic DRAM_LDQM, DRAM_UDQM,
	// output logic DRAM_WE_N, DRAM_CAS_N, DRAM_RAS_N,
	// output logic DRAM_CS_N

	//SYNCHRONOUS OUTPUTS
	always_ff @(posedge clock, negedge reset_n) begin
		if(~reset_n) begin  //RESET TO NOP
			DRAM_CS_N <= 'bx;
			DRAM_RAS_N <= 'bx;
			DRAM_CAS_N <= 'bx;
			DRAM_WE_N <= 'bx;
			DRAM_LDQM <= 'bx;
			DRAM_UDQM <= 'bx;
			DRAM_BA_0 <= 'bx;
			DRAM_BA_1 <= 'bx;
			DRAM_ADDR <= 'bx;
		end else begin

			if(DQM_H) begin
				DRAM_UDQM <= 1'b1;
				DRAM_LDQM <= 1'b1;
			end

			else if(PALL) begin
				DRAM_CS_N <= 1'b0;
				DRAM_RAS_N <= 1'b0;
				DRAM_CAS_N <= 1'b1;
				DRAM_WE_N <= 1'b0;
				DRAM_ADDR[10] <= 1'b1;
			end

			else if(REF) begin
				DRAM_CS_N <= 1'b0;
				DRAM_RAS_N <= 1'b0;
				DRAM_CAS_N <= 1'b0;
				DRAM_WE_N <= 1'b1;
			end

			else if(MRS) begin
				DRAM_CS_N <= 1'b0;
				DRAM_RAS_N <= 1'b0;
				DRAM_CAS_N <= 1'b0;
				DRAM_WE_N <= 1'b0;
				DRAM_ADDR[10] <= 1'b0;

				DRAM_ADDR[6:4] <= 3'b011; //CAS LATENCY
				DRAM_ADDR[2:0] <= 3'b000; //BURST OF ONE
				DRAM_ADDR[3]  <= 1'b0; //WRAP TYPE SEQ
				DRAM_ADDR[11:7] <= 5'b00000; //OPTIONS?
			end

			else if(ACT_W) begin
				DRAM_CS_N <= 1'b0;
				DRAM_RAS_N <= 1'b0;
				DRAM_CAS_N <= 1'b1;
				DRAM_WE_N <= 1'b1;

				//BANK ADDR
				DRAM_BA_1 <= addr_reg[21]; 
				DRAM_BA_0 <= addr_reg[20];
			
				//ROW ADDR
				DRAM_ADDR[11:0] <= addr_reg[19:8];
			end

			else if(WRITEA) begin
				DRAM_CS_N <= 1'b0;
				DRAM_RAS_N <= 1'b1;
				DRAM_CAS_N <= 1'b0;
				DRAM_WE_N <= 1'b0;
				DRAM_ADDR[10] <= 1'b1;

				//BANK ADDR
				DRAM_BA_1 <= addr_reg[21]; 
				DRAM_BA_0 <= addr_reg[20];

				//COLUMN ADDR
				DRAM_ADDR[11:0] <= addr_reg[7:0];
			end

			else if(ACT_R) begin
				DRAM_CS_N <= 1'b0;
				DRAM_RAS_N <= 1'b0;
				DRAM_CAS_N <= 1'b1;
				DRAM_WE_N <= 1'b1;

				//BANK ADDR
				DRAM_BA_1 <= addr_reg[21]; 
				DRAM_BA_0 <= addr_reg[20];
			
				//ROW ADDR
				DRAM_ADDR[11:0] <= addr_reg[19:8];
			end

			else if(READA) begin
				DRAM_CS_N <= 1'b0;
				DRAM_RAS_N <= 1'b1;
				DRAM_CAS_N <= 1'b0;
				DRAM_WE_N <= 1'b1;
				DRAM_ADDR[10] <= 1'b1;

				//COULMN ADDR
				DRAM_ADDR[7:0] <= addr_reg[7:0];
			end

			else if(NOP_INIT) begin
				DRAM_CS_N <= 1'b0;
				DRAM_RAS_N <= 1'b1;
				DRAM_CAS_N <= 1'b1;
				DRAM_WE_N <= 1'b1;
			end

			else if(NOP_W) begin
				DRAM_CS_N <= 1'b0;
				DRAM_RAS_N <= 1'b1;
				DRAM_CAS_N <= 1'b1;
				DRAM_WE_N <= 1'b1;
			end

			else if(NOP_R) begin
				DRAM_CS_N <= 1'b0;
				DRAM_RAS_N <= 1'b1;
				DRAM_CAS_N <= 1'b1;
				DRAM_WE_N <= 1'b1;
			end
		end
	end
endmodule: MemCtrlr // MemCtrlr