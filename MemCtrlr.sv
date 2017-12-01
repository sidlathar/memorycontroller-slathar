`default_nettype none

module MemCtrlr (
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


	//INITIALIZE START
	logic clk_cnt_inc, clk_cnt_clr;
	logic [31:0] clk_cnt;

	logic [2:0] CAS_LATENCY, BURST_LEN;
	logic [6:0] MRS_OPTIONS;

	logic DQM_H, PALL, REF, MRS;

	/************************************ FSM ***********************************/

	enum logic [3:0] {INIT, POWERUP_WAIT, PRECHARGE,
	                TRP_WAIT, 
	                AUTO_REF_1, AUTO_REF_2, AUTO_REF_3, AUTO_REF_4,
	                AUTO_REF_5, AUTO_REF_6, AUTO_REF_7, AUTO_REF_8,
	                MODE_REG_SET} currState, nextState;

	//NS logic

	always_comb begin
		{DQM_H, PALL, REF, MRS, clk_cnt_inc, clk_cnt_clr} = 'b000000
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
				if(clk_cnt != T_POWERUP) begin
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
				if(clk_cnt != T_RP) begin
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
				if(clk_cnt != T_RC) begin
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
				if(clk_cnt != T_RC) begin
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
				if(clk_cnt != T_RC) begin
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
				if(clk_cnt != T_RC) begin
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
				if(clk_cnt != T_RC) begin
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
				if(clk_cnt != T_RC) begin
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
				if(clk_cnt != T_RC) begin
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
				if(clk_cnt != T_RC) begin
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
				CAS_LATENCY = 3'b010;
				BURST_LEN = 3'b0;
				WT = 1'b0;
				MRS_OPTIONS = 6'b0;   //$$$$$$$$$$$$$$$-CHANGE-$$$$$$$$$$$$$//

				nextState = INIT; 
			end
		endcase // currState
	end

	//END INITIALIZE

	//WRITE START
	logic clk_cnt_inc_w, clk_cnt_clr_w;
	logic [31:0] clk_cnt_w;
	logic ACT_W, WRITEA;

	logic load_data; //load for data and address of write
	logic ready_w; //ready to write

	/************************************ FSM ***********************************/

	enum logic [2:0] {IDLE_W, LOAD_DATA_W, ACTIVATE_W, DO_WRITE} currState_w, nextState_w;

	//NS logic

	always_comb begin
		{load_data, ready_w, WRITEA, ACT_W} = 4'b0000;
		case (currState_w)
			IDLE_W: begin
				if(!we) begin
					ready_w = 1;

					nextState_w = IDLE_W;
				end
				else begin
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
				if(clk_cnt != T_RCD) begin
					clk_cnt_inc_w = 1;

					nextState_w = ACTIVATE_W;
				end
				else begin
					WRITEA = 1;
					clk_cnt_clr_w = 1;

					nextState_w = DO_WRITE;
				end
			end

			DO_WRITE: begin
				if(clk_cnt != T_RC - T_RCD) begin
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


	//READ START
	logic clk_cnt_inc_r, clk_cnt_clr_r;
	logic [31:0] clk_cnt_r;
	logic ACT_R, READA;

	logic load_data_addr; //load for address of read
	logic ready_r; //ready to read

	/************************************ FSM ***********************************/

	enum logic [2:0] {IDLE_R, LOAD_DATA_R, ACTIVATE_R, DO_READ} currState_r, nextState_r;

	//NS logic

	always_comb begin
		{load_data_addr, ready_r, ACT_R, READA} = 4'b0000;
		case (currState_r)
			IDLE_R: begin
				if(!re) begin
					ready_r = 1;

					nextState_r = IDLE_R;
				end
				else begin
					load_data_addr = 1;

					nextState_r = LOAD_DATA_R;
				end
			end

			LOAD_DATA_R: begin
				ACT_R = 1;
				clk_cnt_clr_r = 1;

				nextState_r = ACTIVATE_R;
			end

			ACTIVATE_R: begin
				if(clk_cnt != T_RCD) begin
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
				if(clk_cnt != T_RC - T_RCD) begin
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
			 	clk_cnt_W <= 0;
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

	//SYNCHRONOUS OUTPUTS
	always_ff @(posedge clock, negedge reset_n) begin
		if(~reset_n) begin
			//OUTPUTS HERE
		end else begin
			if(DQM_H) begin
				//OUTPUTS HERE
			end
			else if(PALL) begin
				//OUTPUTS HERE
			end
			else if(REF) begin
				//OUTPUTS HERE
			end
			else if(MRS) begin
				//OUTPUTS HERE
			end
			else if(ACT_W) begin
				//OUTPUTS HERE
			end
			else if(WRITEA) begin
				//OUTPUTS HERE
			end
			else if(ACT_R) begin
				//OUTPUTS HERE
			end
			else if(READA) begin
				//OUTPUTS HERE
			end
		end
	end


endmodule: MemCtrlr // MemCtrlr