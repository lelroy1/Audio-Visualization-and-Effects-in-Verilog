/*
	Does all the calculations for the next column of the waveform for the top level.
	inputs: clk, reset, read, seen, audio_left, audio_right
		read - signals to this module that the next sample is ready to be read
		seen - signals that the frame that is sent out has been registered
		audio_left and audio_right - CODEC audio samples
	outputs: next_frame, LEDR
		next_frame - 100 bit signal that signals the next far left column in the VGA
		LEDR - outputs to show communication between VGA and DE1 are synced.
*/

module sample_buffer(clk, reset, audio_left, audio_right, read, seen, next_frame, LEDR);
	input logic clk, reset, read, seen;
	input logic signed [23:0] audio_left, audio_right;
	output logic [9:0] LEDR;
	output logic [99:0] next_frame;
		
	logic signed [30:0] running_average;
	logic [12:0] sample_count;
	logic divide_avg;
	logic signed [23:0] audio_left_abs, audio_right_abs;
	assign audio_left_abs = audio_left[23] ? -audio_left : audio_left;
	assign audio_right_abs = audio_right[23] ? -audio_right : audio_right;
	
	// this chooses the next frame based on how loud the average of the last 2200 samples are
	// note: There is a 20 clock cycle slack on the calculation
	always_ff @(posedge clk) begin
		if (reset) begin
			running_average <= 0;
			sample_count <= 0;
			divide_avg <= 1;
		end else if (sample_count == 13'd2180) begin
			if (divide_avg) begin
				divide_avg <= 0;
			end else begin
				if (running_average > 30'd1000000) begin
					next_frame <= {{20{1'b0}},{60{1'b1}}, {20{1'b0}}};
					LEDR[9] <= 1;
					LEDR[8:0] <= 0;
				end else if (running_average > 30'd950000) begin
					next_frame <= {{22{1'b0}},{56{1'b1}}, {22{1'b0}}};
					LEDR[9] <= 0;
					LEDR[8] <= 1;
					LEDR[7:0] <= 0;
				end else if (running_average > 30'd900000) begin
					next_frame <= {{24{1'b0}},{52{1'b1}}, {24{1'b0}}};
					LEDR[9:8] <= 0;
					LEDR[7] <= 1;
					LEDR[6:0] <= 0;
				end else if (running_average > 30'd850000) begin
					next_frame <= {{26{1'b0}},{48{1'b1}}, {26{1'b0}}};
					LEDR[9:7] <= 0;
					LEDR[6] <= 1;
					LEDR[5:0] <= 0;
				end else if (running_average > 30'd800000) begin
					next_frame <= {{28{1'b0}},{44{1'b1}}, {28{1'b0}}};
					LEDR[9:6] <= 0;
					LEDR[5] <= 1;
					LEDR[4:0] <= 0;
				end else if (running_average > 30'd750000) begin
					next_frame <= {{48{1'b0}},{4{1'b1}}, {48{1'b0}}};
					LEDR[9:5] <= 0;
					LEDR[4] <= 1;
					LEDR[3:0] <= 0;
				end else if (running_average > 30'd700000) begin
					next_frame <= {{32{1'b0}},{36{1'b1}}, {32{1'b0}}};
					LEDR[9:4] <= 0;
					LEDR[3] <= 1;
					LEDR[2:0] <= 0;
				end else if (running_average > 30'd650000) begin
					next_frame <= {{34{1'b0}},{32{1'b1}}, {34{1'b0}}};
					LEDR[9:3] <= 0;
					LEDR[2] <= 1;
					LEDR[1:0] <= 0;
				end else if (running_average > 30'd600000) begin
					next_frame <= {{36{1'b0}},{28{1'b1}}, {36{1'b0}}};
					LEDR[9:2] <= 0;
					LEDR[1] <= 1;
					LEDR[0] <= 0;
				end else if (running_average > 30'd550000) begin
					next_frame <= {{38{1'b0}},{24{1'b1}}, {38{1'b0}}};
					LEDR[9:1] <= 0;
					LEDR[0] <= 1;
				end else if (running_average > 30'd500000) begin
					next_frame <= {{40{1'b0}},{20{1'b1}}, {40{1'b0}}};
				end else if (running_average > 30'd450000) begin
					next_frame <= {{42{1'b0}},{16{1'b1}}, {42{1'b0}}};
				end else if (running_average > 30'd400000) begin
					next_frame <= {{44{1'b0}},{12{1'b1}}, {44{1'b0}}};
				end else if (running_average > 30'd350000) begin
					next_frame <= {{46{1'b0}},{8{1'b1}}, {46{1'b0}}};
				end else if (running_average > 30'd300000) begin
					next_frame <= {{48{1'b0}},{4{1'b1}}, {48{1'b0}}};
				end else begin
					next_frame <= {100{1'b0}};
				end
			end
			if (seen) begin
			   running_average <= 0;
				sample_count <= 0;
				divide_avg <= 1;
			end
		end else if (read) begin
			sample_count <= sample_count + 1;
			running_average <= running_average + (audio_left_abs + audio_right_abs) / 30'd4260;;
		end
	end // always_ff

endmodule  // sample_buffer

/*
	Sample buffer testbench used for simulation.
*/
module sample_buffer_wave_tb();
	logic clk, reset, read, seen;
	logic signed [23:0] audio_left, audio_right;
	logic [99:0] next_frame;
	logic [9:0] LEDR;
	
	sample_buffer dut (.*);
	
	parameter CLOCK_PERIOD=10;
	initial begin
		clk <= 0;
		forever #(CLOCK_PERIOD/2) clk <= ~clk; //toggle the clock indefinitely
	end 
	
	initial begin
		reset<=1; audio_left<=24'd1000000; audio_right<=24'd1200000; read<=0; seen<=0; @(posedge clk); // high test
		reset<=0; @(posedge clk);
		repeat(5000) begin
			read<=1; @(posedge clk);
			read<=0; @(posedge clk);
		end
		seen<=1; @(posedge clk);
		seen<=0; @(posedge clk);
		audio_left<=24'd724000; audio_right<=24'd724000; @(posedge clk); // middle test LEDR3
		repeat(5000) begin
			read<=1; @(posedge clk);
			read<=0; @(posedge clk);
		end
		seen<=1; @(posedge clk);
		seen<=0; @(posedge clk);
		audio_left<=24'd575000; audio_right<=24'd575000; @(posedge clk); // low test LEDR0
		repeat(5000) begin
			read<=1; @(posedge clk);
			read<=0; @(posedge clk);
		end
		$stop;
	end
endmodule // line_drawer_wave_tb
