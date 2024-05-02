module line_drawer_wave #(parameter WAVE_SAMPLES_PER_SEC = 10)
								 (clk, reset, audio_left, audio_right, read, pixel_color, x, y);
		
	input logic clk, reset, read;
	input logic [23:0] audio_left, audio_right;
	output logic pixel_color;
	output logic [10:0] x, y;
		
	logic [12:0] sample_count_curr, sample_count_full;
	logic [30:0] running_average;
	// logic add_avg;
	logic start; // start drawing line
	logic done; // line drawing is done
	assign sample_count_full = 13'd48000 / WAVE_SAMPLES_PER_SEC;
	
	// drives the running average and start for line drawing algorithm
	always_ff @(posedge clk) begin
		if (reset) begin
			running_average <= 0;
			sample_count_curr <= 0;
			start <= 0;
		end else if (sample_count_curr == sample_count_full & done) begin
			sample_count_curr <= 0;
			running_average <= 0;
			start <= 0;	
		end else if (sample_count_curr == sample_count_full) begin
			start <= 1;
		end else if (read) begin
			sample_count_curr <= sample_count_curr + 1'b1;
			running_average <= running_average + (audio_left + audio_right) / sample_count_full;
		end
	end // always_ff
	/*
	// drives the logic for when to add to the running average in the above ff
	logic [23:0] data_change;
	always_ff @(posedge clk) begin
		if (reset) begin
			add_avg <= 0;
		end else if (data_change != audio_left) begin
			data_change <= audio_left;
			add_avg <= 1;
		end
	end // always_ff
	*/
	draw_buffer #(WAVE_SAMPLES_PER_SEC) drawcurr_buff (.clk, .reset, .start, .pixel_color, .running_average, .x, .y, .done);

endmodule // line_drawer_wave

module line_drawer_wave_tb();
	logic clk, reset, read;
	logic [23:0] audio_left, audio_right;
	logic pixel_color;
	logic [10:0] x, y;
	
	line_drawer_wave #(10) dut (.*);
	
	parameter CLOCK_PERIOD=10;
	initial begin
		clk <= 0;
		forever #(CLOCK_PERIOD/2) clk <= ~clk; //toggle the clock indefinitely
	end 
	
	initial begin
		reset<=1; audio_left<=24'd200000; audio_right<=24'd31000; read<=0; @(posedge clk);
		reset<=0; @(posedge clk);
		repeat(400000) @(posedge clk); // make sure inital erase is done begin
		repeat(10000000) begin
			read<=1; @(posedge clk);
		end	// do inital writing of first line
		$stop;
	end
endmodule // line_drawer_wave_tb
		