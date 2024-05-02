/*
	Module for creating simple distortion through a hard cut lower and upper threshold
	inputs: readdata_left, readdata_right - left and right audio channels
	outputs: readdata_left_simp, readdata_right_simp - new distorted audio channels
	
*/
module simple_distortion(readdata_left, readdata_right, readdata_left_simp, readdata_right_simp);

	input logic signed [23:0] readdata_left, readdata_right;
	output logic signed [23:0] readdata_left_simp, readdata_right_simp;
	
	logic signed [23:0] audio_left_abs, audio_right_abs;
	assign audio_left_abs = readdata_left[23] ? -readdata_left : readdata_left;
	assign audio_right_abs = readdata_right[23] ? -readdata_right : readdata_right;
	
	always_comb begin
		if (audio_left_abs > 24'd600000) begin
			readdata_left_simp = 24'd600000;
		end else begin
			readdata_left_simp = readdata_left;
		end
		
		if (audio_right_abs > 24'd600000) begin
			readdata_right_simp = 24'd600000;
		end else begin
			readdata_right_simp = readdata_right;
		end 
	end // always_comb
	
endmodule // fuzz_distortion

/*
	Simple distortion test bench used for simulation
*/
module simple_distortion_tb();
	logic signed [23:0] readdata_left, readdata_right;
	logic signed [23:0] readdata_left_simp, readdata_right_simp;
	simple_distortion dut (.*);
	
	initial begin
		readdata_left <= 24'd500000; readdata_right <= 24'd500000; #10; // both under cutoff
		readdata_left <= 24'd700000; readdata_right <= 24'd500000; #10; // left over right under cutoff
		readdata_left <= 24'd500000; readdata_right <= 24'd700000; #10; // right over left under cutoff
		readdata_left <= 24'd700000; readdata_right <= 24'd700000; #10; // both over cutoff
		$stop;
	end

endmodule // simple_distortion_tb