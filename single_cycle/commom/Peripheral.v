`timescale 1ns/1ps
//2013011076 Wang Han
//Provide connection to Memory, timer, LEDs, switches and UART.
//UART is temporarily missing...

module Peripheral (reset,clk,rd,wr,addr,wdata,rdata,led,switch,digi,irqout);
	//===== I/O =====
	input reset,clk;
	input rd,wr;
	input [31:0] addr;
	input [31:0] wdata;
	output [31:0] rdata;
	reg [31:0] rdata;
	//===== LED =====
	output [7:0] led;
	reg [7:0] led;
	input [7:0] switch;
	output [11:0] digi;
	reg [11:0] digi;
	output irqout;
	//===== Timer =====
	reg [31:0] TH,TL;
	reg [2:0] TCON;
	assign irqout = TCON[2];
	//===== Memory =====
	wire [31:0] MemReadData;
	DataMem datamem0(.reset(reset),.clk(clk),.rd(rd),.wr(wr),.addr(addr),.wdata(wdata),.rdata(MemReadData));

	always@(*) begin
		if(rd) begin
			case(addr)
				32'h40000000: rdata <= TH;			
				32'h40000004: rdata <= TL;			
				32'h40000008: rdata <= {29'b0,TCON};				
				32'h4000000C: rdata <= {24'b0,led};			
				32'h40000010: rdata <= {24'b0,switch};
				32'h40000014: rdata <= {20'b0,digi};
				default: rdata <= MemReadData;
			endcase
		end
		else
			rdata <= 32'b0;
	end

	always@(negedge reset or posedge clk) begin
		if(~reset) begin
			TH <= 32'b0;
			TL <= 32'b0;
			TCON <= 3'b0;
			led <= 8'b0;
			digi <= 12'b0;
		end
		else begin
			if(TCON[0]) begin	//timer is enabled
				if(TL==32'hffffffff) begin
					TL <= TH;
					if(TCON[1]) TCON[2] <= 1'b1;		//irq is enabled
				end
				else TL <= TL + 1;
			end
			
			if(wr) begin
				case(addr)
					32'h40000000: TH <= wdata;
					32'h40000004: TL <= wdata;
					32'h40000008: TCON <= wdata[2:0];		
					32'h4000000C: led <= wdata[7:0];			
					32'h40000014: digi <= wdata[11:0];
					default: ;
				endcase
			end
		end
	end
endmodule

