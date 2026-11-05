
// AHB to APG Bridge | Maven Silicon
//
//
//
// AHB Slave Interface
// Date:04-06-2022
//
//
// Modifications: The Combinational part sensitivity list did not inclued Hresetn and hence they gave x output on reset
//                Transfers outside the decoded window get the two-cycle AHB ERROR response; Hrdata only carries Prdata during the APB read access phase


module AHB_slave_interface(Hclk,Hresetn,Hwrite,Hreadyin,Htrans,Haddr,Hwdata,
			   Prdata,valid,Haddr1,Haddr2,Hwdata1,Hwdata2,Hrdata,Hwritereg,tempselx,Hresp,
			   Penable,Pwrite,Hreadyout_apb,Hreadyout);
input Hclk,Hresetn;
input Hwrite,Hreadyin;
input Penable,Pwrite,Hreadyout_apb;
input [1:0] Htrans;
input [31:0] Haddr,Hwdata,Prdata;
output reg valid;
output reg [31:0] Haddr1,Haddr2,Hwdata1,Hwdata2;
output [31:0] Hrdata; 
output reg Hwritereg;
output reg [2:0] tempselx;
output  [1:0] Hresp;
output Hreadyout;

parameter RESP_OKAY=2'b00;
parameter RESP_ERROR=2'b01;

parameter ERR_NONE=2'b00;
parameter ERR_WAIT=2'b01;
parameter ERR_LAST=2'b10;

reg [1:0] err_state;
reg unmapped;



/// Implementing Pipeline Logic for Address,Data and Control Signal

	always @(posedge Hclk)
		begin
		
			if (~Hresetn)
				begin
					Haddr1<=0;
					Haddr2<=0;
				end
			else
				begin
					Haddr1<=Haddr;
					Haddr2<=Haddr1;
				end
		
		end

	always @(posedge Hclk)
		begin
		
			if (~Hresetn)
				begin
					Hwdata1<=0;
					Hwdata2<=0;
				end
			else
				begin
					Hwdata1<=Hwdata;
					Hwdata2<=Hwdata1;
				end
		
		end
		
	always @(posedge Hclk)
		begin	
			if (~Hresetn)
				Hwritereg<=0;
			else
				Hwritereg<=Hwrite;
		end
		
		
/// Implementing Valid Logic Generation
/// No new transfer is accepted while the first ERROR cycle is pending.

	always @(Hreadyin,Haddr,Htrans,Hresetn,err_state)
		begin
			valid=0;
			unmapped=0;
			if (Hresetn && Hreadyin && err_state!=ERR_WAIT && (Htrans==2'b10 || Htrans==2'b11))
				begin
					if (Haddr>=32'h8000_0000 && Haddr<32'h8C00_0000)
						valid=1;
					else
						unmapped=1;
				end

		end

/// Implementing Error Response Logic
/// ERR_WAIT: OKAY wait states until the APB side is ready, then ERROR with Hreadyout LOW.
/// ERR_LAST: ERROR with Hreadyout HIGH.

	always @(posedge Hclk)
		begin
			if (~Hresetn)
				err_state<=ERR_NONE;
			else if (err_state==ERR_WAIT)
				begin
					if (Hreadyout_apb)
						err_state<=ERR_LAST;
				end
			else if (unmapped)
				err_state<=ERR_WAIT;
			else
				err_state<=ERR_NONE;
		end
		
/// Implementing Tempselx Logic

	always @(Haddr,Hresetn)
		begin
			tempselx=3'b000;
			if (Hresetn && Haddr>=32'h8000_0000 && Haddr<32'h8400_0000)
				tempselx=3'b001;
			else if (Hresetn && Haddr>=32'h8400_0000 && Haddr<32'h8800_0000)
				tempselx=3'b010;
			else if (Hresetn && Haddr>=32'h8800_0000 && Haddr<32'h8C00_0000)
				tempselx=3'b100;

		end
	

assign Hrdata = (err_state==ERR_NONE && Penable && ~Pwrite) ? Prdata : 32'h0;
assign Hresp = (err_state==ERR_LAST || (err_state==ERR_WAIT && Hreadyout_apb)) ? RESP_ERROR : RESP_OKAY;
assign Hreadyout = (err_state==ERR_WAIT) ? 1'b0 : (err_state==ERR_LAST) ? 1'b1 : Hreadyout_apb;

endmodule