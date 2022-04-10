`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2021 02:44:56 PM
// Design Name: 
// Module Name: processorTomasulo_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module processorTomasulo_tb(

    );
    reg clk,rst;
    wire test;
    
    tomasulo uut (  .clk(clk), .rst(rst), .done(test)   );
    
    initial
    begin
    rst<=0;
    clk<=0;
    
    #1 rst<=1;
    #4 rst<=0;
    end
    
    always
    #1 clk = ~clk;
    
endmodule
