/*
	Drives all the top level systems for the audio -> VGA interface
 *
 * Inputs:
 *   KEY 			- On board keys of the FPGA
 *   SW 				- On board switches of the FPGA
 *   CLOCK_50 		- On board 50 MHz clock of the FPGA
 *   CLOCK2_50 	- On board 50 MHz clock of the FPGA

 *
 * Outputs:
 *   HEX 			- On board 7 segment displays of the FPGA
 *   LEDR 			- On board LEDs of the FPGA
 *	VGA:
 *   VGA_R 			- Red data of the VGA connection
 *   VGA_G 			- Green data of the VGA connection
 *   VGA_B 			- Blue data of the VGA connection
 *   VGA_BLANK_N 	- Blanking interval of the VGA connection
 *   VGA_CLK 		- VGA's clock signal
 *   VGA_HS 		- Horizontal Sync of the VGA connection
 *   VGA_SYNC_N 	- Enable signal for the sync of the VGA connection
 *   VGA_VS 		- Vertical Sync of the VGA connection
   Audio:
     FPGA_I2C_SCLK
	  FPGA_I2C_SDAT
	  AUD_XCK
	  AUD_DACLRCK
	  AUD_ADCLRCK
	  AUD_BCLK
	  AUD_ADCDAT
	  AUD_DACDAT
 */
module DE1_SoC (HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, KEY, LEDR, SW, CLOCK_50, CLOCK2_50,
					 VGA_R, VGA_G, VGA_B, VGA_BLANK_N, VGA_CLK, VGA_HS, VGA_SYNC_N, VGA_VS,
					 FPGA_I2C_SCLK, FPGA_I2C_SDAT, AUD_XCK, AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK, AUD_ADCDAT, AUD_DACDAT);
	output logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
	output logic [9:0] LEDR;
	input logic [3:0] KEY;
	input logic [9:0] SW;

	input CLOCK_50, CLOCK2_50;
	output [7:0] VGA_R;
	output [7:0] VGA_G;
	output [7:0] VGA_B;
	output VGA_BLANK_N;
	output VGA_CLK;
	output VGA_HS;
	output VGA_SYNC_N;
	output VGA_VS;
	
	// I2C Audio/Video config interface
	output FPGA_I2C_SCLK;
	inout FPGA_I2C_SDAT;
	// Audio CODEC
	output AUD_XCK;
	input AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK;
	input AUD_ADCDAT;
	output AUD_DACDAT;
	
	// Local wires
	logic read_ready, write_ready, read, write;
	logic signed [23:0] readdata_left, readdata_right, readdata_left_simp, readdata_right_simp, readdata_left_fuzz, readdata_right_fuzz;
	logic signed [23:0] writedata_left, writedata_right;
	
	assign read = write_ready & read_ready;
	assign write = write_ready & read_ready;
	
	// drives fuzz left and right channels
	fuzz_distortion fuzz (.clk(CLOCK_50), .reset, .readdata_left, .readdata_right, .readdata_left_fuzz, .readdata_right_fuzz);
	
	// drives simple left and right channels
	simple_distortion simp (.readdata_left, .readdata_right, .readdata_left_simp, .readdata_right_simp);
	
	// decides the effects placed over the incoming audio.
	always_comb begin
		if (~SW[0]) begin
			writedata_left = readdata_left;
			writedata_right = readdata_right;
		end else if (~SW[1]) begin
			writedata_left = readdata_left_simp;
			writedata_right = readdata_right_simp;
		end else begin
			writedata_left = readdata_left_fuzz;
			writedata_right = readdata_right_fuzz;
		end
	end // always_comb

	/////////////////////////////////////////////////////////////////////////////////
// Audio CODEC interface. 
//
// The interface consists of the following wires:
// read_ready, write_ready - CODEC ready for read/write operation 
// readdata_left, readdata_right - left and right channel data from the CODEC
// read - send data from the CODEC (both channels)
// writedata_left, writedata_right - left and right channel data to the CODEC
// write - send data to the CODEC (both channels)
// AUD_* - should connect to top-level entity I/O of the same name.
//         These signals go directly to the Audio CODEC
// I2C_* - should connect to top-level entity I/O of the same name.
//         These signals go directly to the Audio/Video Config module
/////////////////////////////////////////////////////////////////////////////////
	clock_generator my_clock_gen(
		// inputs
		CLOCK2_50,
		1'b0,

		// outputs
		AUD_XCK
	);

	audio_and_video_config cfg(
		// Inputs
		CLOCK_50,
		1'b0,

		// Bidirectionals
		FPGA_I2C_SDAT,
		FPGA_I2C_SCLK
	);

	audio_codec codec(
		// Inputs
		CLOCK_50,
		1'b0,

		read,	write,
		writedata_left, writedata_right,

		AUD_ADCDAT,

		// Bidirectionals
		AUD_BCLK,
		AUD_ADCLRCK,
		AUD_DACLRCK,

		// Outputs
		read_ready, write_ready,
		readdata_left, readdata_right,
		AUD_DACDAT
	);
	
	
	//
	//	End Audio Interface
	//
	
	logic reset;
	logic [7:0] x;
	logic [7:0] y;
	logic [7:0] r, g, b;
	
	video_driver #(.WIDTH(100), .HEIGHT(100))
		v1 (.CLOCK_50, .reset(1'b0), .x, .y, .r, .g, .b,
			 .VGA_R, .VGA_G, .VGA_B, .VGA_BLANK_N,
			 .VGA_CLK, .VGA_HS, .VGA_SYNC_N, .VGA_VS);
	
	logic [99:0] written_pixels [99:0]; // array represents each pixel on the VGA
	logic erasing;
	logic [15:0] erase_count;
	logic [7:0] clr_written_pixels_count;
	logic [22:0] sample_count_curr, sample_count_full; // count of frames before add
	logic [7:0] shift_count; // iterate over every value and shift over by 1 to make room for the next frame
	assign sample_count_full = 23'd500000; // shifts screen once the sample_count_curr reaches this value
	
	always_ff @(posedge CLOCK_50) begin
		if (reset) begin
			erasing <= 1;
			erase_count <= 0;
			clr_written_pixels_count <= 0;
			sample_count_curr <= 0;
			shift_count <= 0;
		end else if (erasing) begin
			if (clr_written_pixels_count < 100) begin
				written_pixels[clr_written_pixels_count] <= {{100{1'b0}}};
			end
			pixel_curr <= 0;
			erase_count <= erase_count + 1;
			clr_written_pixels_count <= clr_written_pixels_count + 1;
			if (erase_count == 16'd40000) begin
				erasing <= 0;
			end
		end else begin
			if (sample_count_curr == sample_count_full) begin
				written_pixels[shift_count] <= written_pixels[shift_count] <<< 1;
				written_pixels[shift_count][0] <= next_frame_buffer[shift_count];
				shift_count <= shift_count + 1;
				if (shift_count == 8'd100) begin
					shift_count <= 0;
					sample_count_curr <= 0;
				end
			end else begin
				sample_count_curr <= sample_count_curr + 1;
			end
		end
		pixel_curr <= written_pixels[y][x];
	end // always_ff
	
	logic [99:0] next_frame_buffer; // stores left most column of pixels on the screen
	logic [25:0] animate_count_full, animate_count;
	assign animate_count_full = 26'd500000;
	// drives the next frame logic.
	always_ff @(posedge CLOCK_50) begin
		if (reset) begin
			animate_count <= 0;
			seen <= 0;
		end else if (animate_count < animate_count_full) begin
			animate_count <= animate_count + 1;
			seen <= 0;
		end else if (animate_count == animate_count_full) begin
			next_frame_buffer <= next_frame;
			seen <= 1;
			if (sample_count_curr == 0) begin
				animate_count <= 0;
				next_frame_buffer <= {100{1'b0}};
			end
		end
	end // always_ff
	
	logic seen;
	logic [99:0] next_frame;
	logic signed [23:0] aud_data;
	logic read_sample;
	always_ff @(posedge CLOCK_50) begin
	    if (reset) begin
	        read_sample <=0;
	        aud_data <= 24'd0;
	    end else if (aud_data != readdata_left) begin
	        aud_data <= readdata_left;
	        read_sample <= 1;
	    end else begin
	        read_sample <= 0;
	    end 
	end // always_ff
	
	// drives the scaling of next frame buffer depending on sample
	sample_buffer frame_drive (.clk(CLOCK_50), .reset, .audio_left(readdata_left), .audio_right(readdata_right), .read(read_sample), .seen, .next_frame, .LEDR);
	
	logic pixel_curr;
	
	// drives the pixel color
	always_ff @(posedge CLOCK_50) begin
		if (pixel_curr == 1'b0) begin
			r <= 0;
			g <= 0;
			b <= 0;
		end else if (pixel_curr == 1'b1) begin
			r <= {{8{1'b1}}};
			g <= {{8{1'b1}}};
			b <= {{8{1'b1}}};
		end
	end // always_ff
	
	assign HEX0 = '1;
	assign HEX1 = '1;
	assign HEX2 = '1;
	assign HEX3 = '1;
	assign HEX4 = '1;
	assign HEX5 = '1;
	assign reset = ~KEY[0];
	
endmodule // DE1_SoC