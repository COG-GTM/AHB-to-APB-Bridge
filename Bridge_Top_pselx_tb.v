// AHB to APB Bridge | Write-path Pselx regression testbench
//
// Self-checking: drives Bridge_Top with a pipelined AHB master (Hreadyin tied
// to Hreadyout) and checks that every APB transfer's Pselx matches the decode
// of its Paddr, and that each scenario's write lands on the right peripheral.
// Run: iverilog -o /tmp/all.out *.v && vvp /tmp/all.out

module Bridge_Top_pselx_tb;

reg Hclk, Hresetn;
reg Hwrite;
reg [1:0] Htrans;
reg [31:0] Haddr, Hwdata;
wire [31:0] Prdata = 32'h0000_0000;
wire Hreadyout, Penable, Pwrite;
wire [1:0] Hresp;
wire [2:0] Pselx;
wire [31:0] Paddr, Pwdata, Hrdata;

Bridge_Top DUT (.Hclk(Hclk), .Hresetn(Hresetn), .Hwrite(Hwrite), .Hreadyin(Hreadyout),
		.Hreadyout(Hreadyout), .Hwdata(Hwdata), .Haddr(Haddr), .Htrans(Htrans),
		.Prdata(Prdata), .Penable(Penable), .Pwrite(Pwrite), .Pselx(Pselx),
		.Paddr(Paddr), .Pwdata(Pwdata), .Hresp(Hresp), .Hrdata(Hrdata));

localparam IDLE   = 2'b00;
localparam NONSEQ = 2'b10;

initial Hclk = 0;
always #5 Hclk = ~Hclk;

function [2:0] decode(input [31:0] a);
	begin
		if (a >= 32'h8000_0000 && a < 32'h8400_0000)      decode = 3'b001;
		else if (a >= 32'h8400_0000 && a < 32'h8800_0000) decode = 3'b010;
		else if (a >= 32'h8800_0000 && a < 32'h8C00_0000) decode = 3'b100;
		else                                              decode = 3'b000;
	end
endfunction

integer errors = 0;

// APB monitor: sample mid-cycle so registered outputs are stable.
reg        seen_write;
reg [31:0] want_addr, want_data;
reg [2:0]  want_sel;

always @(negedge Hclk)
	if (Hresetn && Pselx != 3'b000)
		begin
			if (Pselx !== decode(Paddr))
				begin
					$display("FAIL t=%0t: Pselx=%b but Paddr=%h decodes to %b (Pwrite=%b)",
						 $time, Pselx, Paddr, decode(Paddr), Pwrite);
					errors = errors + 1;
				end
			if (!Penable && Pwrite && Paddr == want_addr && Pselx == want_sel && Pwdata == want_data)
				seen_write = 1;
		end

// Pipelined AHB master: an entry's address phase ends on the first rising
// edge with HREADY high; its write data is then driven in the data phase.
reg [1:0]  q_trans [0:7];
reg        q_write [0:7];
reg [31:0] q_addr  [0:7];
reg [31:0] q_data  [0:7];
integer    q_len, q_idx;
reg        rdy;

always @(negedge Hclk) rdy = Hreadyout;

task run_scenario(input [8*48-1:0] name, input [31:0] exp_addr, input [2:0] exp_sel, input [31:0] exp_data);
	integer cyc;
	begin
		Hresetn = 0; Hwrite = 0; Htrans = IDLE; Haddr = 0; Hwdata = 0;
		seen_write = 0; want_addr = exp_addr; want_sel = exp_sel; want_data = exp_data;
		repeat (2) @(posedge Hclk);
		#1 Hresetn = 1;
		@(negedge Hclk);
		q_idx = -1;
		for (cyc = 0; cyc < 20; cyc = cyc + 1)
			begin
				@(posedge Hclk);
				#1;
				if (rdy)
					begin
						if (q_idx >= 0 && q_idx < q_len && q_write[q_idx])
							Hwdata = q_data[q_idx];
						q_idx = q_idx + 1;
						if (q_idx < q_len)
							begin
								Htrans = q_trans[q_idx];
								Hwrite = q_write[q_idx];
								Haddr  = q_addr[q_idx];
							end
						else
							Htrans = IDLE;
					end
			end
		if (!seen_write)
			begin
				$display("FAIL %0s: no APB write with Paddr=%h Pselx=%b Pwdata=%h",
					 name, exp_addr, exp_sel, exp_data);
				errors = errors + 1;
			end
		else
			$display("PASS %0s", name);
	end
endtask

initial
	begin
		// Write to peripheral 0, then a read of peripheral 1 in the next cycle.
		q_len = 2;
		q_trans[0] = NONSEQ; q_write[0] = 1; q_addr[0] = 32'h8000_0010; q_data[0] = 32'hDEAD_BEEF;
		q_trans[1] = NONSEQ; q_write[1] = 0; q_addr[1] = 32'h8400_0000; q_data[1] = 0;
		run_scenario("write P0 then read P1", 32'h8000_0010, 3'b001, 32'hDEAD_BEEF);

		// Write to peripheral 0, then Haddr moves to peripheral 2 during an IDLE cycle.
		q_len = 2;
		q_trans[0] = NONSEQ; q_write[0] = 1; q_addr[0] = 32'h8000_0010; q_data[0] = 32'h1111_2222;
		q_trans[1] = IDLE;   q_write[1] = 0; q_addr[1] = 32'h8800_0000; q_data[1] = 0;
		run_scenario("write P0 then idle on P2 address", 32'h8000_0010, 3'b001, 32'h1111_2222);

		// Write to peripheral 0, then Haddr leaves the bridge window during IDLE.
		q_len = 2;
		q_trans[0] = NONSEQ; q_write[0] = 1; q_addr[0] = 32'h8000_0010; q_data[0] = 32'h3333_4444;
		q_trans[1] = IDLE;   q_write[1] = 0; q_addr[1] = 32'h0000_0000; q_data[1] = 0;
		run_scenario("write P0 then idle outside window", 32'h8000_0010, 3'b001, 32'h3333_4444);

		// Back-to-back writes to different peripherals (pipelined write path).
		q_len = 2;
		q_trans[0] = NONSEQ; q_write[0] = 1; q_addr[0] = 32'h8400_0020; q_data[0] = 32'h5555_6666;
		q_trans[1] = NONSEQ; q_write[1] = 1; q_addr[1] = 32'h8800_0030; q_data[1] = 32'h7777_8888;
		run_scenario("write P1 then write P2 (first write)", 32'h8400_0020, 3'b010, 32'h5555_6666);
		run_scenario("write P1 then write P2 (second write)", 32'h8800_0030, 3'b100, 32'h7777_8888);

		if (errors != 0)
			$fatal(1, "Bridge_Top_pselx_tb: %0d check(s) failed", errors);
		$display("Bridge_Top_pselx_tb: all checks passed");
		$finish;
	end

endmodule
