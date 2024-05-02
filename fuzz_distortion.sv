/*
	inputs:
	clk, reset, readdata_left and readdata_right.
	readdata_left and readdata_right are the left and right channels of the audio
	outputs:
	readdata_left_fuzz, readdata_right_fuzz which will be the right and left channel with the fuzz effect.
	
	This module takes audio samples and places a fuzz effect over them. A fuzz effect is a calculation which
	chops off samples above or below a certain threshold (600000). It also does something called envolope
	following to make the distortion sound more 'musical'. This basically means scaling how 'hard' the cut
	is based on how many cuts have been made in a row. See diagram in lab report for more information.
*/
module fuzz_distortion(clk, reset, readdata_left, readdata_right, readdata_left_fuzz, readdata_right_fuzz);
	input logic clk, reset;
	input logic signed [23:0] readdata_left, readdata_right;
	output logic signed [23:0] readdata_left_fuzz, readdata_right_fuzz;
	
	logic signed [23:0] readdata_left_abs, readdata_right_abs;
	assign readdata_left_abs = readdata_left[23] ? -readdata_left : readdata_left;
	assign readdata_right_abs = readdata_right[23] ? -readdata_right : readdata_right;
	
	logic signed [23:0] aud_data;
	logic [10:0] cut_count_right, cut_count_left;
	logic [23:0] max_right, max_left;
	
	always_comb begin
		if (readdata_left_abs > 24'd600000) begin
		    if (readdata_left > 0) begin
		        readdata_left_fuzz = 24'd600000 + (readdata_left - 24'd600000) / (2 * cut_count_left);
		    end else begin
		        readdata_left_fuzz = 0 - 24'd600000 - (readdata_left + 24'd600000) / (2 * cut_count_left);
		    end
		end else begin
			readdata_left_fuzz = readdata_left;
		end
		
		if (readdata_right_abs > 24'd600000) begin
		    if (readdata_right > 0) begin
		        readdata_right_fuzz = 24'd600000 + (readdata_right - 24'd600000) / (2 * cut_count_right);
		    end else begin
		        readdata_right_fuzz = 0 - 24'd600000 - (readdata_right + 24'd600000) / (2 * cut_count_right);
		    end
		end else begin
			readdata_right_fuzz = readdata_right;
		end 
	end // always_comb
	
	// Hardens cut as the count as samples rise then once they 
	// lower sofen the cut for the same number of cycles it was hardened for
	
	
	always_ff @(posedge clk) begin
		if (reset) begin
			cut_count_right <= 1;
			cut_count_left <= 1;
			aud_data <= 24'd0;
			max_right <= 0;
			max_left <= 0;
		end else if (aud_data != readdata_left) begin
			// left data filt
			if (readdata_left > 24'd600000) begin
				if (readdata_left_abs > max_left) begin
					max_left <= readdata_left_abs;
					cut_count_left <= cut_count_left + 1;
				end else begin
					if (cut_count_left > 0) begin
						cut_count_left <= cut_count_left - 1;
					end
				end
			end else begin
				cut_count_left <= 1;
			end
			// right data filt
			if (readdata_right > 24'd600000) begin
				if (readdata_right_abs > max_right) begin
					max_right <= readdata_right_abs;
					cut_count_right <= cut_count_right + 1;
				end else begin
					if (cut_count_right > 0) begin
						cut_count_right <= cut_count_right - 1;
					end
				end
			end else begin
				cut_count_right <= 1;
			end
			aud_data <= readdata_left;
		end else begin
		end
	end // always_ff
endmodule // fuzz_distortion

/*
	Fuzz distortion test bench used for testing and verifying proper functionality of the 
	fuzz distortion module.
*/
module fuzz_distortion_tb();
	logic clk, reset;
	logic signed [23:0] readdata_left, readdata_right;
	logic signed [23:0] readdata_left_fuzz, readdata_right_fuzz;
	
	fuzz_distortion dut (.*);
	
	parameter CLOCK_PERIOD=10;
	initial begin
		clk <= 0;
		forever #(CLOCK_PERIOD/2) clk <= ~clk; //toggle the clock indefinitely
	end 
	
	initial begin
		reset<=1; readdata_left<=24'd1000000; readdata_right<=24'd1000000; @(posedge clk); 
		reset<=0; readdata_left<=24'd1000010; readdata_right<=24'd1000010;@(posedge clk); // increasing cut count
		readdata_left<=24'd1000020; readdata_right<=24'd1000020;@(posedge clk);
		readdata_left<=24'd1000030; readdata_right<=24'd1000030;@(posedge clk);
		readdata_left<=24'd1000040; readdata_right<=24'd1000040;@(posedge clk);
		readdata_left<=24'd1000050; readdata_right<=24'd1000050;@(posedge clk);
		readdata_left<=24'd1000060; readdata_right<=24'd1000060;@(posedge clk);
		readdata_left<=24'd1000060; readdata_right<=24'd1000060;@(posedge clk); // decrease cut count
		readdata_left<=24'd1000050; readdata_right<=24'd1000050;@(posedge clk);
		readdata_left<=24'd1000040; readdata_right<=24'd1000040;@(posedge clk);
		readdata_left<=24'd1000030; readdata_right<=24'd1000030;@(posedge clk);
		readdata_left<=24'd1000020; readdata_right<=24'd1000020;@(posedge clk);
		readdata_left<=24'd1000010; readdata_right<=24'd1000010;@(posedge clk);
		$stop;
	end
endmodule // line_drawer_wave_tb
