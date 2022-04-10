`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/09/2021 07:53:59 AM
// Design Name: 
// Module Name: tomasulo
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

 `define no_ARF 10  // number of ARF(architectural registers)
 `define no_RAT 10 // number of RAT slots
 `define no_instr  7 // number of instructions in instruction memory
 `define no_RS_addsub  3 // number of addition-subtraction reservation stations 
 `define no_RS_muldiv  2 // number of multiplication-division reservation stations
 `define no_LoadStoreBuffer  3 // number of load-store buffer
 `define no_ROB 8 // number of ROB entries
 `define main_memory_length 100 //main memory length in double word (no of 32bit words)
 
 // Implememnted opcodes concatenated func7,func3,opcode
 `define lw  10'b010_0000011 // load
 `define add 17'b0000000_000_0110011 // addition
 `define sub 17'b0100000_000_0110011 // subtraction
 `define mul 17'b0000001_000_0110011 // multiplication
 `define div 17'b0000001_100_0110011 // division

module tomasulo(
    input clk,
    input rst,
    output reg done
    );
    
    reg stall; // reg for stalling 
    reg [31:0] pc; //program counter
    reg [31:0] instruction_memory [`no_instr-1:0]; // instruction memory
    reg [$clog2(`no_instr)-1:0] instr_ID;  // instruction ID acting as the name for each instruction
    reg RS_AddSub_busy;
    reg RS_MulDiv_busy;
    reg LS_busy;
    reg [$clog2(`no_ROB)-1:0]ROB_head; // registers to point to ROB head and tail
    reg [$clog2(`no_ROB)-1:0]ROB_tail; // new ROB entries at head, commit from tail
    
    reg [31:0] ARF[1:`no_ARF]; /////////////////////////////////////////////////////////ARF registers
    reg [$clog2(`no_ROB)-1:0] RAT[1:`no_RAT]; //////////////////////////////////////////RAT registers
    reg [7:0]MAIN_MEMORY[`main_memory_length*4 :0]; ////////////////////////////////////Main memory
    
    //////////////////////////////////////////////////////////////////////////////////////ROB table
    reg [$clog2(`no_instr)-1:0] ROB_instr_ID [`no_ROB:1]; 
    reg [$clog2(`no_ARF)-1:0] ROB_dest [`no_ROB:1];
    reg [31:0] ROB_value [`no_ROB:1];
    reg ROB_valid[`no_ROB:1];
    
    /////////////////////////////////////////////////////////////////////////////////////ADD SUB Reservation table 
    reg [$clog2(`no_instr)-1:0] AS_RS_instr_ID [`no_RS_addsub-1:0];
    reg [16:0] AS_RS_instr [`no_RS_addsub-1:0];
    reg AS_RS_busy [`no_RS_addsub-1:0];
    reg [$clog2(`no_ARF)-1:0] AS_RS_dest [`no_RS_addsub-1:0];
    reg [$clog2(`no_ARF)-1:0] AS_RS_src1 [`no_RS_addsub-1:0];
    reg [$clog2(`no_ARF)-1:0] AS_RS_src2 [`no_RS_addsub-1:0];
    reg [31:0] AS_RS_value1 [`no_RS_addsub-1:0];
    reg [31:0] AS_RS_value2 [`no_RS_addsub-1:0];
    
    /////////////////////////////////////////////////////////////////////////////////////MUL DIV Reservation table 
    reg [$clog2(`no_instr)-1:0] MD_RS_instr_ID [`no_RS_muldiv-1:0];
    reg [16:0] MD_RS_instr [`no_RS_muldiv-1:0];
    reg MD_RS_busy [`no_RS_muldiv-1:0];
    reg [$clog2(`no_ROB)-1:0] MD_RS_dest [`no_RS_muldiv-1:0];
    reg [$clog2(`no_ROB)-1:0] MD_RS_src1 [`no_RS_muldiv-1:0];
    reg [$clog2(`no_ROB)-1:0] MD_RS_src2 [`no_RS_muldiv-1:0];
    reg [31:0] MD_RS_value1 [`no_RS_muldiv-1:0];
    reg [31:0] MD_RS_value2 [`no_RS_muldiv-1:0];
    
    //////////////////////////////////////////////////////////////////////////////////////Load Store buffer
    reg [$clog2(`no_instr)-1:0] LS_buffer_instr_ID [`no_LoadStoreBuffer-1:0];
    reg LS_buffer_busy [`no_LoadStoreBuffer-1:0];
    reg [$clog2(`no_ARF)-1:0] LS_buffer_dest_tag [`no_LoadStoreBuffer-1:0];
    reg [11:0] LS_buffer_offset [`no_LoadStoreBuffer-1:0];  
    reg [$clog2(`no_ARF)-1:0] LS_buffer_SRCreg [`no_LoadStoreBuffer-1:0];
    
    
    reg [31:0] instr_IQ; // instruction coming from instruction queue
    always@(posedge clk) ////////////////////////////////////////////////////////////////Instruction queue block
    begin
    if(rst == 1)
        begin 
            pc <= 0;
            instr_IQ <= 0;
            done <=0 ;
            stall <=0;
            ARF[1] <= 12;  ARF[2] <= 16; ARF[3] <= 45; ARF[4] <= 5; ARF[5] <= 3;
            ARF[6] <= 4;   ARF[7] <= 1;  ARF[8] <= 2;  ARF[9] <= 2; ARF[10] <= 3;
            
            RAT[1] <= 0;   RAT[2] <= 0;  RAT[3] <= 0;  RAT[4] <= 0;  RAT[5] <= 0;
            RAT[6] <= 0;   RAT[7] <= 0;  RAT[8] <= 0;  RAT[9] <= 0;  RAT[10] <= 0;
            
            MAIN_MEMORY[16] <= 16;
            
            instruction_memory[0] <= 32'b0000_0000_0000_0001_0010_0001_1000_0011;
            instruction_memory[1] <= 32'b0000_0010_0100_0001_1100_0001_0011_0011;
            instruction_memory[2] <= 32'b0000_0010_0110_0010_1000_0000_1011_0011;
            instruction_memory[3] <= 32'b0000_0000_1000_0011_1000_0001_1011_0011;
            instruction_memory[4] <= 32'b0000_0010_0011_0000_1000_0000_1011_0011;
            instruction_memory[5] <= 32'b0100_0000_0101_0000_1000_0010_0011_0011;
            instruction_memory[6] <= 32'b0000_0000_0010_0010_0000_0000_1011_0011;
        end
    else if(stall == 1)        begin   pc <= pc;  instr_IQ <= instr_IQ;        end
    else if(pc > `no_instr)    begin   pc <= pc;  instr_IQ <= instr_IQ;        end
    else
        begin
            instr_IQ <= instruction_memory[pc];
            pc <= pc + 1;
        end
        
    end
    
    wire [6:0]func7;
    wire [2:0]func3;
    wire [6:0]opcode;
    wire [4:0]src1;
    wire [4:0]src2;
    wire [4:0]dst;
    wire [11:0]offset;
    
    assign func7 = instr_IQ[31:25];
    assign offset = instr_IQ[31:20];
    assign src2 = instr_IQ[24:20];
    assign src1 = instr_IQ[19:15];
    assign func3 = instr_IQ[14:12];
    assign dst = instr_IQ[11:7];
    assign opcode = instr_IQ[6:0];
    
    
    reg [4:0]dest;
    integer r,updated;
    always@(posedge clk) // /////////////////////////////////////////////////////////////Dispatch block
    begin  
    if (rst == 1)
        begin
        instr_ID <=0;
        dest <= 0;
//        op <= 0; 
//        src1_tag <=0; 
//        src2_tag <=0; 
//        dest_tag <=0;
        end
    else if (stall == 1) begin
        instr_ID <= instr_ID;
        ROB_head <= ROB_head;
        end
    else
        begin
        
        case({func7,func3,opcode})
        {offset[11:5],`lw} : begin
                if(LS_busy == 1'b1) stall <=1;
                else begin
               
                    updated = 0;
                    for(r=0 ; r < `no_LoadStoreBuffer; r=r+1) begin : loop_ls // entry into Load store buffer
                         if(updated==0 && LS_buffer_busy[r] == 0) begin
                                LS_buffer_SRCreg[r] <= src1;
                                LS_buffer_instr_ID[r] <= instr_ID;
                                LS_buffer_busy[r] <= 1'b1;
                                LS_buffer_dest_tag[r] <= ROB_head;
                                LS_buffer_offset[r] <= offset;                                
                                updated = 1;
                         end  
                    end
                    
                    ROB_instr_ID [ROB_head] <= instr_ID; /// entry into ROB
                    ROB_dest [ROB_head] <= dst;
                    ROB_value [ROB_head] <= 32'hxxxxxxxx;
                    
                    RAT[dst] <= ROB_head;                                     /// entry into RAT
                    
                    ROB_head <= ROB_head + 1;
                    instr_ID <= instr_ID + 1;
                end
              end
              
        `add : begin
                if (RS_AddSub_busy == 1'b1) stall <= 1;

                else
                begin
                                      
                    updated = 0;
                    for(r = 0; r < `no_RS_addsub; r = r + 1) /// entry into the Add Sub RS
                    begin : loop_add
                        if(updated == 0 && AS_RS_busy[r] == 0)
                            begin
                             AS_RS_busy[r] <= 1'b1;
                             AS_RS_instr[r] <= `add;
                             AS_RS_instr_ID[r] <= instr_ID;  
                             AS_RS_dest[r] <= ROB_head;
                             if(RAT[src1]!=0) AS_RS_src1[r] = RAT[src1]; else AS_RS_value1[r] = ARF[src1];
                             if(RAT[src2]!=0) AS_RS_src2[r] = RAT[src2]; else AS_RS_value2[r] = ARF[src2];
                             updated = 1;                   
                             end
                    end
                    
                    ROB_instr_ID [ROB_head] <= instr_ID; /// entry into ROB
                    ROB_dest [ROB_head] <= dst;
                    ROB_value [ROB_head] <= 32'hxxxxxxxx;
                    
                    RAT[dst] <= ROB_head;                  /// entry into RAT
                    
                    ROB_head <= ROB_head + 1;
                    instr_ID <= instr_ID + 1;     
                end                    
               end
               
        `sub : begin
                if (RS_AddSub_busy == 1'b1) stall <= 1;

                else
                begin
                                       
                    updated = 0;
                    for(r = 0; r < `no_RS_addsub; r = r + 1) /// entry into the Add Sub RS
                    begin : loop_sub
                        if(updated == 0 && AS_RS_busy[r] == 0)
                            begin
                             AS_RS_busy[r] <= 1'b1;
                             AS_RS_instr[r] <= `sub;
                             AS_RS_instr_ID[r] <= instr_ID;  
                             AS_RS_dest[r] <= ROB_head;
                             if(RAT[src1]!=0) AS_RS_src1[r] = RAT[src1]; else AS_RS_value1[r] = ARF[src1];
                             if(RAT[src2]!=0) AS_RS_src2[r] = RAT[src2]; else AS_RS_value2[r] = ARF[src2];
                             updated = 1;                   
                             end
                    end
                    
                    ROB_instr_ID [ROB_head] <= instr_ID; /// entry into ROB
                    ROB_dest [ROB_head] <= dst;
                    ROB_value [ROB_head] <= 32'hxxxxxxxx;
                    
                    RAT[dst] <= ROB_head;                  /// entry into RAT
                    
                    ROB_head <= ROB_head + 1;
                    instr_ID <= instr_ID + 1;     
                end                    
               end
               
        `mul : begin
                if (RS_MulDiv_busy == 1'b1)  stall <= 1;

                else
                begin
                                     
                    updated = 0;
                    for(r = 0; r < `no_RS_muldiv; r = r + 1) /// entry into the Add Sub RS
                    begin :loop_mul
                        if(updated == 0 && MD_RS_busy[r] == 0)
                            begin
                             MD_RS_busy[r] <= 1'b1;
                             MD_RS_instr[r] <= `mul;
                             MD_RS_instr_ID[r] <= instr_ID;  
                             MD_RS_dest[r] <= ROB_head;
                             if(RAT[src1]!=0) MD_RS_src1[r] <= RAT[src1]; else MD_RS_value1[r] <= ARF[src1];
                             if(RAT[src2]!=0) MD_RS_src2[r] <= RAT[src2]; else MD_RS_value2[r] <= ARF[src2]; 
                             updated = 1;                     
                             end
                    end
                    
                    ROB_instr_ID [ROB_head] <= instr_ID; /// entry into ROB
                    ROB_dest [ROB_head] <= dst;
                    ROB_value [ROB_head] <= 32'hxxxxxxxx;
                    
                    RAT[dst] <= ROB_head;                  /// entry into RAT
                    
                    ROB_head <= ROB_head + 1;
                    instr_ID <= instr_ID + 1;     
                end                    
               end
               
        `div : begin
                if (RS_MulDiv_busy == 1'b1)  stall <= 1;

                else
                begin
                                     
                    updated = 0;
                    for(r = 0; r < `no_RS_muldiv; r = r + 1) begin :loop_div /// entry into the Add Sub RS    
                        if(updated == 0 && MD_RS_busy[r] == 0)
                            begin
                             MD_RS_busy[r] <= 1'b1;
                             MD_RS_instr[r] <= `div;
                             MD_RS_instr_ID[r] <= instr_ID;  
                             MD_RS_dest[r] <= ROB_head;
                             if(RAT[src1]!=0) MD_RS_src1[r] = RAT[src1]; 
                             if(RAT[src1]==0) MD_RS_value1[r] = ARF[src1];
                             if(RAT[src2]!=0) MD_RS_src2[r] = RAT[src2]; 
                             if(RAT[src2]==0) MD_RS_value2[r] = ARF[src2]; 
                             updated = 1;                     
                             end
                    end
                    
                    ROB_instr_ID [ROB_head] <= instr_ID; /// entry into ROB
                    ROB_dest [ROB_head] <= dst;
                    ROB_value [ROB_head] <= 32'hxxxxxxxx;
                    
                    RAT[dst] <= ROB_head;                  /// entry into RAT
                    
                    ROB_head <= ROB_head + 1;
                    instr_ID <= instr_ID + 1;     
                end                    
               end
               
         endcase
        end
 
    end 
    
    integer k,l;
    reg [$clog2(`no_ARF)-1:0]LS_src;
    reg [$clog2(`no_ROB)-1:0]LS_dest;
    reg [$clog2(`no_instr)-1:0]LS_instr_ID;
    reg [11:0]LS_offset;
    reg LS_start;
    reg LS_counter_run;
    reg LS_updated;
    reg LS_valid;
    always@(posedge clk)//////////////////////////////////////////////////////////////////LS buffer block 
    begin
       if(LS_start == 1) LS_start <=0;
       if((LS_buffer_busy[0]+LS_buffer_busy[1]+LS_buffer_busy[2]) > 3)     LS_busy<=1;  
       else LS_busy <= 0;
       
       if(rst==1) begin // update LS buffer values on reset
         for(k = 0; k < `no_RS_addsub; k = k + 1) begin                           
            LS_buffer_instr_ID[k] <= 0; 
            LS_buffer_busy[k] <= 0;  
            LS_buffer_dest_tag[k] <= 0;   
            LS_buffer_offset[k] <= 0;   
            LS_buffer_SRCreg[k] <= 0;   
            LS_updated <= 0;
            end 
         end
         
       else begin
            LS_updated <= 0;
            for(l = 0; l < `no_LoadStoreBuffer; l = l + 1) begin : loop_ls_buffer
             if(LS_counter_run == 0 && LS_updated == 0 && LS_buffer_busy[l]!=0 ) // send to Load store opeartion block
                 begin
                 LS_src <= LS_buffer_SRCreg[l];
                 LS_dest <= LS_buffer_dest_tag[l];
                 LS_instr_ID <= LS_buffer_instr_ID[l];
                 LS_offset <= LS_buffer_offset[l];
                 LS_buffer_busy[l]<=0;
                 LS_start <= 1;
                 LS_updated <= 1;
                 end
           end
       end
    end
    
    reg [$clog2(`no_ARF)-1:0]CDB_dest;
    reg [31:0]CDB_value;
    
    reg [31:0]LS_result;
    reg [2:0]LS_counter;
    always@(posedge clk)/////////////////////////////////////////////////////////////////////Load store execution block
    begin       
        if(rst==1) begin LS_counter <=0; LS_result <= 0; LS_valid<=0; LS_counter_run <=0;end
        else if(LS_start == 1) begin
            LS_counter <= 0;
            LS_result <= MAIN_MEMORY[LS_offset + ARF[LS_src]]; 
            LS_valid <= 0;   
            LS_counter_run <= 1;          
            end
        else if(LS_counter > 3) begin
            LS_valid <= 1; 
            LS_counter <= 0;
            LS_counter_run <= 0;
            end
        else if(LS_counter_run == 1)  LS_counter <= LS_counter +1;
    end
          
    integer j,t,y;    
    reg [31:0]AS_src1,AS_src2;
    reg [$clog2(`no_ROB)-1:0]AS_dest;
    reg [16:0]AS_instr;
    reg [$clog2(`no_instr)-1:0]AS_instr_ID;
    reg AS_start;
    reg AS_counter_run;
    reg AS_updated;
    reg AS_valid;
    always@(posedge clk)////////////////////////////////////////////////////////////////////ADD SUB RS block
    begin
     if(AS_start == 1) AS_start <= 0;
     if((AS_RS_busy[0]+AS_RS_busy[1]+AS_RS_busy[2]) > 3)     RS_AddSub_busy <= 1;
     else RS_AddSub_busy <= 0;
     
     if(rst==1) begin
     for(j = 0; j < `no_RS_addsub; j = j + 1) begin
        AS_RS_instr_ID[j] <= 0; 
        AS_RS_instr[j] <= 0;  
        AS_RS_busy[j] <= 0;   
        AS_RS_dest[j] <= 0;   
        AS_RS_src1[j] <= 0;   
        AS_RS_src2[j] <= 0;   
        AS_RS_value1[j] <= 0;   
        AS_RS_value2[j] <= 0; 
        end 
     end
     
     else begin
         AS_updated <= 0;
         for(t = 0 ; t < `no_RS_addsub; t = t +1 ) begin
            if(AS_RS_src1[t] == CDB_dest && CDB_dest != 0) begin AS_RS_value1[t] <= CDB_value; AS_RS_src1[t] <= 0; end
            if(AS_RS_src2[t] == CDB_dest && CDB_dest != 0) begin AS_RS_value2[t] <= CDB_value; AS_RS_src2[t] <= 0; end
            end
         for(j = 0; j < `no_RS_addsub; j = j + 1) begin : loop_as_rs
//              for(t = 1; t <= `no_ROB; t = t + 1) begin  // update the values in RS
//                if(ROB_value[AS_RS_src1[j]] != 32'hxxxxxxxx)  AS_RS_value1[j]<=ROB_value[AS_RS_src1[j]];
//                if(ROB_value[AS_RS_src2[j]] != 32'hxxxxxxxx)  AS_RS_value2[j]<=ROB_value[AS_RS_src2[j]];
//              end 
        
             if(AS_counter_run == 0 && AS_updated == 0 && AS_RS_busy[j]==1 && AS_RS_src1[j]==0 && AS_RS_src2[j]==0 ) // send to execution if values available
                 begin
                 AS_src1 <= AS_RS_value1[j];
                 AS_src2 <= AS_RS_value2[j];
                 AS_dest <= AS_RS_dest[j];
                 AS_instr <= AS_RS_instr[j];
                 AS_instr_ID <= AS_RS_instr_ID[j];
                 AS_RS_busy[j] <= 0;
                 AS_start <= 1;
                 AS_updated <= 1; //break for loop
                 end
          end
     end
    end
    
    reg [2:0]AS_counter;
    reg [31:0]AS_result;
    always@(posedge clk)////////////////////////////////////////////////////////////////////Add sub execution block
    begin
        if(rst == 1) begin AS_counter <=0; AS_result <= 0; AS_valid<=0; AS_counter_run <=0; end
        else if(AS_start == 1) begin
            if(AS_instr == `add)     AS_result <= AS_src1 + AS_src2;
            else if(AS_instr ==`sub) AS_result <= AS_src1 - AS_src2;
            AS_counter <= 0;  
            AS_valid <= 0;
            AS_counter_run <= 1;
            end
//        else if(AS_counter > 0) begin
////            if(AS_instr[j] == `add) AS_result <= AS_src1 + AS_src2;
////            else if(AS_instr[j] ==`sub) AS_result <= AS_src1 - AS_src2;
//            AS_valid <=1;
//            AS_counter <= 0;
//            AS_counter_run <= 0;
//            end
        else if(AS_counter_run == 1) begin  
            AS_valid <=1; 
            AS_counter <= 0;
            AS_counter_run <= 0; //AS_counter <= AS_counter + 1; 
            end
    end
    
    reg [31:0]MD_src1,MD_src2;
    reg [$clog2(`no_ROB)-1:0]MD_dest;
    reg [16:0]MD_instr;
    reg [$clog2(`no_instr)-1:0]MD_instr_ID;
    reg MD_start;
    reg MD_counter_run;
    reg MD_updated;
    reg MD_valid;
    always@(posedge clk)////////////////////////////////////////////////////////////////////MUL DIV RS block
    begin
     if(MD_start == 1) MD_start <= 0;
     if((MD_RS_busy[0]+MD_RS_busy[1]) > 2)     RS_MulDiv_busy <= 1;
     else RS_MulDiv_busy <= 0;
     
     if(rst==1) begin
         MD_start <= 0; //MD_src1 <= 0; MD_src2 <= 0;
         for(j = 0; j < `no_RS_muldiv; j = j + 1) begin 
            MD_RS_instr_ID[j] <= 0; 
            MD_RS_instr[j] <= 0;  
            MD_RS_busy[j] <= 0;   
            MD_RS_dest[j] <= 0;   
            MD_RS_src1[j] <= 0;   
            MD_RS_src2[j] <= 0;   
            MD_RS_value1[j] <= 0;   
            MD_RS_value2[j] <= 0; 
            end 
     end
     
     else begin
         MD_updated <= 0;
         for(t = 0 ; t < `no_RS_muldiv; t = t +1 ) begin
            if(MD_RS_src1[t] == CDB_dest && CDB_dest != 0) begin MD_RS_value1[t] <= CDB_value; MD_RS_src1[t] <= 0; end
            if(MD_RS_src2[t] == CDB_dest && CDB_dest != 0) begin MD_RS_value2[t] <= CDB_value; MD_RS_src2[t] <= 0; end
            end
         for(j = 0; j < `no_RS_muldiv; j = j + 1) begin : loop_md_rs
//              for(t = 1; t <= `no_ROB; t = t + 1) begin  // update the values in RS
//                if(ROB_value[MD_RS_src1[j]] != 32'hxxxxxxxx) begin MD_RS_value1[j]<=ROB_value[MD_RS_src1[j]]; MD_RS_src1[j]<=0; end
//                if(ROB_value[MD_RS_src2[j]] != 32'hxxxxxxxx) begin MD_RS_value2[j]<=ROB_value[MD_RS_src2[j]]; MD_RS_src2[j]<=0; end
//              end 
        
             if(MD_counter_run == 0 && MD_updated == 0 && MD_RS_busy[j]==1 && MD_RS_src1[j]==0 && MD_RS_src2[j]==0 ) // send to execution if values available
                 begin
                 MD_src1 <= MD_RS_value1[j];
                 MD_src2 <= MD_RS_value2[j];
                 MD_dest <= MD_RS_dest[j];
                 MD_instr <= MD_RS_instr[j];
                 MD_instr_ID <= MD_RS_instr_ID[j];
                 MD_RS_busy[j] <= 0;
                 MD_start <= 1;
                 MD_updated <= 1;  // break for loop
                 end

          end
     end
    end

    reg [6:0]MD_counter;
    reg [31:0]MD_result;
    reg MD_type;//0=mul 1=div
    always@(posedge clk)////////////////////////////////////////////////////////////////////Mul div execution block
    begin
        if(rst == 1) begin MD_counter <= 0; MD_result <= 0; MD_valid<=0; MD_counter_run <=0; end
        else if(MD_start == 1) begin 
            if(MD_instr == `mul)      begin  MD_result <= MD_src1 * MD_src2; MD_type <= 0; end
            else if(MD_instr == `div) begin  MD_result <= MD_src1 / MD_src2; MD_type <= 1; end 
            MD_counter <= 0;  
            MD_valid <= 0;
            MD_counter_run <= 1;  
            end
        else if(MD_counter > 8 && MD_type==0)  begin  MD_valid <=1; MD_counter <= 0; MD_counter_run <= 0; end     
        else if(MD_counter > 38 && MD_type==1) begin  MD_valid <=1; MD_counter <= 0; MD_counter_run <= 0; end
        else if(MD_counter_run == 1)  MD_counter <= MD_counter + 1; 
    end
    

    reg [$clog2(`no_instr)-1:0]CDB_instr_ID;
    reg CDB_valid;
    reg CDB_updated;
    integer u;
    always@(posedge clk)///////////////////////////////////////////////////////////////////CDB block
    begin
        if(rst == 1)begin
            CDB_dest <= 0;
            CDB_value <= 0;
            CDB_instr_ID <=0;
            CDB_valid <= 0;
            end
//        else begin
//            CDB_updated <= 0;
//            for(u=1 ;u <= `no_ROB; u=u+1) begin : loop_cdb
//                if(CDB_updated == 0 && ROB_instr_ID[u] == LS_instr_ID && LS_valid == 1) begin
//                    CDB_dest <= LS_dest;
//                    CDB_value <= LS_result;
//                    CDB_instr_ID <= LS_instr_ID;
//                    CDB_valid <= 1;
//                    CDB_updated <= 1;
//                    LS_valid = 0;
//                end                    
//                if(CDB_updated == 0 && ROB_instr_ID[u] == AS_instr_ID && AS_valid == 1) begin
//                    CDB_dest <= AS_dest;
//                    CDB_value <= AS_result;
//                    CDB_instr_ID <= AS_instr_ID;
//                    CDB_valid <= 1;
//                    CDB_updated <= 1;
//                    AS_valid = 0;
//                end
//                else if(CDB_updated == 0 && ROB_instr_ID[u] == MD_instr_ID && MD_valid == 1) begin
//                    CDB_dest <= MD_dest;
//                    CDB_value <= MD_result;
//                    CDB_instr_ID <= MD_instr_ID;
//                    CDB_valid <= 1;
//                    CDB_updated <= 1;
//                    MD_valid = 0;
//                end

//            end
//        end
          else begin
            if(LS_valid == 1) begin
                CDB_dest <= LS_dest;
                CDB_value <= LS_result;
                CDB_instr_ID <= LS_instr_ID;
                CDB_valid <= 1;
                LS_valid = 0;
                end
            else if(AS_valid == 1) begin
                CDB_dest <= AS_dest;
                CDB_value <= AS_result;
                CDB_instr_ID <= AS_instr_ID;
                CDB_valid <= 1;
                AS_valid = 0;
                end
            else if(MD_valid == 1) begin
                CDB_dest <= MD_dest;
                CDB_value <= MD_result;
                CDB_instr_ID <= MD_instr_ID;
                CDB_valid <= 1;
                MD_valid = 0;
                end
//            else begin
//                CDB_valid <= 0;
//                end
         end
    end
    
    integer i;
    always@(posedge clk)///////////////////////////////////////////////////////////////////ROB block
    begin
        
        if(rst==1)
            begin
            ROB_head <= 1;
            ROB_tail <= 1;
                for(i = 1; i <= `no_ROB; i = i + 1) begin
                 ROB_instr_ID [i] <= 0; 
                 ROB_dest [i] <= 0;
                 ROB_value [i] <= 32'hxxxxxxxx;
                 ROB_valid[i] <= 0;
                end
            end
         else begin
            for(i = 1; i <= `no_ROB; i = i + 1) begin
                if(ROB_instr_ID[i] == `no_instr-1) done<=1;
                if(CDB_valid == 1 && CDB_instr_ID==ROB_instr_ID[i]) begin
//                   ROB_instr_ID [ROB_head] <= CDB_instr_ID; 
//                   ROB_dest [ROB_head] <= CDB_dest;
                    ROB_value [i] <= CDB_value;
                    ROB_valid[i] <= 1;
                    CDB_valid=0;
//                    if(ROB_head>`no_ROB) ROB_head <= 1;
//                    else ROB_head = ROB_head +1;
                end
            end
//            for(i = 1; i <= `no_ROB; i = i+1) begin
//                if(ROB_value[i] != 32'hxxxxxxxx) begin
//                    ARF[ROB_dest[i]] = ROB_value[i];
//                    if (ROB_tail==ROB_head)   ROB_tail <= ROB_tail;
//                    else ROB_tail <= ROB_tail + 1 ;
//                    end
//            end
            if(ROB_valid[ROB_tail] == 1 ) begin
                ARF[ROB_dest[ROB_tail]] = ROB_value[ROB_tail];
                ROB_valid[ROB_tail] = 0;
                ROB_tail = ROB_tail +1;
                end
         end
            
     end
    
endmodule
