//-----------------------------------------------------
// TB
//-----------------------------------------------------


module GaussFilter_tb;
 
 
parameter rows = 4;
parameter cols = 4; 
parameter ksize = 3; 
parameter data_width = 8;

integer i,ii;

wire image_out_valid;
wire [data_width-1:0] req;
wire [data_width*rows*cols-1:0] image_out; 
wire done;

 
reg [7:0] address;
reg reset;
reg clk=0;
reg [data_width*rows*cols-1:0] image_in;
reg [data_width-1:0] mem [0:(rows * cols)-1] ; 
reg image_ready;
reg start;




assign req = mem[address];


initial begin
  $readmemb("C:/Users/USER/Desktop/Gaussian Blur/image_pixels_binary4.txt", mem); // memory_list is memory file
end



 always 
 #5 clk = ~clk;

GaussFilter 
#(

.rows(rows),
.cols(cols),
.ksize(ksize),
.data_width(data_width)


)
GaussFilter_inst
(
 .clk		   (clk), 
 .rst 	   (reset),
 .start     (start),
 .image_in  (image_in),
 .image_ready(image_ready),
 .image_out (image_out),
 .done		(done),
 .image_out_valid (image_out_valid)
 );
 
    
integer output_file;
initial begin
  output_file = $fopen("C:/Users/USER/Desktop/Gaussian Blur/output2.txt", "w");
end

	 
	 
	 
 
 initial begin
   address 		= 0;
   reset   		= 1;
	image_ready = 0;
	image_in 	= 0;
	#100
	reset		   = 0;
	#100
	@(posedge clk)
	for (i = 0; i < rows * cols  ; i = i +1 )begin
		@(posedge clk)
		address = address + 1;
		image_in[i*8 +: 8] = req;//(7:0),(15:8)
	end
	image_ready <= 1'b1;	
	start <= 1'b1;
	@(posedge clk)
	start <= 1'b0;
	@(posedge clk)
	@(posedge clk)
	wait(done == 1'b1)
	@(posedge clk)
	$fwrite(output_file, "%h\n", image_out);
   $fclose(output_file);
 end
 


endmodule