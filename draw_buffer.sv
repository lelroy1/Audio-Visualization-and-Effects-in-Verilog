module draw_buffer #(parameter WAVE_SAMPLES_PER_SEC = 10)
						  (clk, reset, start, pixel_color, running_average, x, y, done);
	input logic clk, reset, start;
	input logic [30:0] running_average;
	output logic [10:0] x, y;
	output logic pixel_color;
	output logic done;
	
	logic [25:0] animate_count_full, animate_count;
	assign animate_count_full = 26'd50000000 / WAVE_SAMPLES_PER_SEC; // 50,000,000 is number of clock cycles in one second for the 50 MHz clock
	
	
	// This structure will store the state of the screen at each frame. A 1 represents a pixel with a white value and
	// 0 represents black.
	logic [639:0] written_pixels [0:479];
	
	// variables for frame advancement
	logic [8:0] mem_count;
	logic shift_screen; // signals to move every pixel over to the right 1
	logic write_pixels; // signals that a new line of pixels needs to be written to the written_pixels array
	logic screen_scan; // signals that new screen state is ready to be written
	logic [8:0] shift_count;
	logic [479:0] next_frame_buffer;
	
	// variables for writing to the VGA
	logic erasing, screen_buffering;
	
	// This ff handles erasing screen completely on reset and handles writing the pixels from
	// written_pixels to the VGA
	always_ff @(posedge clk) begin
		if (reset) begin
			x <= 0;
			y <= 0;
			erasing <= 1;
			screen_buffering <= 0;
		end else if (erasing == 1) begin
			pixel_color <= 1'b0;
			if (x < 11'd639) begin
				x <= x + 1;
			end else if (x == 11'd639 & y < 11'd479) begin
				x <= 0;
				y <= y + 1;
			end else if (x == 11'd639 & y == 11'd479) begin
				erasing <= 0;
			end
		end else if (screen_buffering) begin
			pixel_color <= written_pixels[y][x];
			if (x < 11'd639) begin
				x <= x + 1;
			end else if (x == 11'd639 & y < 11'd479) begin
				x <= 0;
				y <= y + 1;
			end else if (x == 11'd639 & y == 11'd479) begin
				screen_buffering <= 0;
			end
		end else if (screen_scan) begin
			screen_buffering <= 1;
			x <= 0;
			y <= 0;
		end
	end // always_ff
	
	// initializes memory to all 0s. This is done to show that all pixels are initally off.	
	// manages when to advance to the next frame. (screen scan basically says advance the frame)
	// When advancing to the next frame every pixel needs to be moved over to the right by 1.
	/*
		Standard Process
		-reset
		-when start is high it stages the next left most column of the VGA (next_frame_buffer)
		-written_pixels is written to every 50,000,000/WAVE_SAMPLES_PER_SEC clock cycles (animate state)
		-Once this starts the screen is shifted right and either all 0s are fed into the leftmost bits or next_frame_buffer is.
	*/

	always_ff @(posedge clk) begin
		if (reset) begin
			animate_count <= 0;
			screen_scan <= 0;
			shift_screen <= 0;
			shift_count <= 0;
			write_pixels <= 0;
			done <= 0;
			mem_count <= 0;
		end else if (mem_count < 9'b111101010) begin
			written_pixels[mem_count] <= {640{1'b0}};
			mem_count <= mem_count + 1;
		end else if (start & ~write_pixels) begin
			write_pixels <= 1;
			next_frame_buffer <= {{40{1'b0}}, {400{1'b1}}, {40{1'b0}}}; // this is where I should scale based on the running average
			done <= 0;
		end else if (animate_count < animate_count_full) begin
			animate_count <= animate_count + 1'b1;
			screen_scan <= 0;
		end else if (shift_count == 9'b111101010) begin
			shift_screen <= 0;
			screen_scan <= 1; // signals animation ff to start 
			shift_count <= 0;
			animate_count <= 0;
			write_pixels <= 0;
			done <= 1;
		end else if (shift_screen) begin
			written_pixels[shift_count] <= written_pixels[shift_count] >>> 1;
			if (write_pixels) begin
				written_pixels[shift_count][0] <= next_frame_buffer[shift_count];  // {{next_frame_buffer[shift_count]}, {written_pixels[shift_count][1:639]}};
			end
			shift_count <= shift_count + 1'b1;
		end else if (animate_count == animate_count_full) begin
			shift_screen <= 1;
		end
	end // always_ff
	
endmodule // draw_buffer

module draw_buffer_tb();
	logic clk, reset, start;
	logic [30:0] running_average;
	logic [10:0] x, y;
	logic pixel_color;
	logic done;
	
	draw_buffer #(10) dut (.*);
	
	parameter CLOCK_PERIOD=10;
	initial begin
		clk <= 0;
		forever #(CLOCK_PERIOD/2) clk <= ~clk; //toggle the clock indefinitely
	end 
	
	initial begin
	reset<=1; start<=0; running_average<=0; @(posedge clk);
	reset<=0; @(posedge clk);
	repeat(400000) @(posedge clk); // make sure inital erase is done
	start<=1; @(posedge clk);
	start<=0; @(posedge clk);
	repeat(10000000) @(posedge clk); // do inital writing of first line
	$stop;
	end
endmodule 