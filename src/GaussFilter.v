module GaussFilter #(parameter rows = 4, cols = 4, ksize = 3, data_width = 8) (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [data_width*rows*cols-1:0] image_in,
    output reg [data_width*rows*cols-1:0] image_out,
    output reg image_out_valid,
    output reg done,
    input wire image_ready
);

    reg [data_width-1:0] memory [0:rows*cols-1]; // To store memory
    reg [7:0] SigmaMatrix [0:ksize*ksize-1];    // Kernel

    integer i, j, k, l, y, z, ii, n, nn;
    reg [15:0] sum_g;                            // Accumulator for convolution
    reg [7:0] result [0:rows*cols-1];           // Result of convolution

    reg [7:0] ColumnVector [0:ksize-1];         // Column vector for kernel calculation
    reg [7:0] RowVector [0:ksize-1];            // Row vector for kernel calculation

    reg [3:0] state;                            // state machine
    integer pixel_idx;                          // Pixel index

    // FSM States
    localparam IDLE = 0, CALC_KERNEL = 1, LOAD_IMAGE = 2, CONVOLVE = 3, OUTPUT_RESULT = 4, DONE = 5;

    function integer factorial;
        input integer num;
        integer fact, i;
        begin
            fact = 1;
            for (i = 1; i <= num; i = i + 1)
                fact = fact * i;
            factorial = fact;
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            image_out <= 0;
            done <= 0;
            pixel_idx <= 0;
            sum_g <= 0;
            k <= 0;
            l <= 0;
            image_out_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CALC_KERNEL;
                    end
                end

                // Compute Kernel
                CALC_KERNEL: begin
                    // Calculate the kernel values
                    for (i = 0; i < ksize; i = i + 1) begin
                        ColumnVector[i] = factorial(ksize-1) / (factorial(i) * factorial(ksize-1-i));
                        RowVector[i] = factorial(ksize-1) / (factorial(i) * factorial(ksize-1-i));
                    end

                    // Compute the 2D Gaussian kernel
                    for (ii = 0; ii < ksize; ii = ii + 1) begin
                        for (j = 0; j < ksize; j = j + 1) begin
                            SigmaMatrix[ii * ksize + j] = ColumnVector[ii] * RowVector[j];
                        end
                    end

                    // Normalize the kernel
                    sum_g = 0;
                    for (n = 0; n < ksize*ksize; n = n + 1) begin
                        sum_g = sum_g + SigmaMatrix[n];
                    end
                    for (nn = 0; nn < ksize*ksize; nn = nn + 1) begin
                        SigmaMatrix[nn] = (SigmaMatrix[nn]*256) / sum_g;
                    end

                    if (image_ready)
                        state <= LOAD_IMAGE;
                end

                // Load input image into memory
                LOAD_IMAGE: begin
                    memory[pixel_idx] <= image_in[pixel_idx*data_width +: data_width]; // size: data_width. starts from pixel_idx*data_width
                    pixel_idx <= pixel_idx + 1;
                    if (pixel_idx == rows * cols - 1) begin
                        pixel_idx <= 0;
                        state <= CONVOLVE;
                    end
                end

                // Convolution
                CONVOLVE: begin
                    i = pixel_idx / cols; // Current row
                    j = pixel_idx % cols; // Current column

                    if (k < ksize) begin  //row index inside the window in the image
                        if (l < ksize) begin //Column index inside the window in the image
                            y = i + k - ksize/2; // Row offset. [Row in image] + [Row in window]- ksize/2 (index in the middle is zero)
                            z = j + l - ksize/2; // Column offset. 
                            if (y >= 0 && y < rows && z >= 0 && z < cols) begin //condition for boundary check
                                sum_g <= sum_g + (memory[y * cols + z] * SigmaMatrix[k * ksize + l]);
                            end else begin
                                // Handle edge cases by mirroring
                                y = (y < 0) ? -y : (y >= rows) ? 2*rows - y - 1 : y;
                                z = (z < 0) ? -z : (z >= cols) ? 2*cols - z - 1 : z;
                                sum_g <= sum_g + (memory[y * cols + z] * SigmaMatrix[k * ksize + l]);
                            end
                            l <= l + 1;
                        end else begin
                            l <= 0;
                            k <= k + 1;
                        end
                    end else begin
                        result[pixel_idx] <= sum_g>>8; // Store result
                        pixel_idx <= pixel_idx + 1; // Move to next pixel
                        k <= 0;
                        l <= 0;
                        sum_g <= 0;

                        if (pixel_idx == rows * cols - 1) begin
                            state <= OUTPUT_RESULT;
                            pixel_idx <= 0;
                        end
                    end
                end

                // Store convolution results
                OUTPUT_RESULT: begin
                    image_out[pixel_idx*data_width +: data_width] <= result[pixel_idx];
                    pixel_idx <= pixel_idx + 1;
                    
						  
						//  image_out_valid <= 1'b1;
						  
                    if (pixel_idx == rows * cols - 1) begin
						      image_out_valid <= 1'b1;
                        state <= DONE;
                    end
                end

                // Indicate completion
                DONE: begin
                    done <= 1;
                    state <= IDLE;
                    image_out_valid <= 1'b0;
                end

                default: state <= IDLE;
            endcase
        end
    end
	endmodule