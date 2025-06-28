`timescale 1ns / 1ps

module search(
input power_status,
input [2:0] state,
input search_in_1,search_in_2,search_in_3,clk,rst,exit_in,
output reg search_use,search_on,search_reminder
    );
    wire search_1,search_2,search_3,exit;
    debouncer in_1(
    .clk(clk),
    .rst(rst),
    .button_in(search_in_1),
    .button_out(search_1)
    );
    debouncer in_2(
        .clk(clk),
        .rst(rst),
        .button_in(search_in_2),
        .button_out(search_2)
    );
    debouncer in_3(
        .clk(clk),
        .rst(rst),
        .button_in(exit_in),
        .button_out(exit)
    );
    debouncer in_4(
    .clk(clk),
    .rst(rst),
    .button_in(search_in_3),
    .button_out(search_3)
    );    
        
 always @ (posedge clk or negedge rst) begin
      if(~rst)begin
         search_use<=1'b0;
         search_on<=1'b0;
         search_reminder<=1'b0;
     end else if (~power_status) begin
         search_use<=1'b0;
         search_on<=1'b0;
         search_reminder<=1'b0;
     end else begin
         if(search_1)begin
            search_use<=1'b1;
            search_on<=1'b0;
            search_reminder<=1'b0;         
         end else if(search_2) begin
            search_use<=1'b0;
            search_on<=1'b1;
            search_reminder<=1'b0;         
         end if (search_3) begin
            search_use<=1'b0;
            search_on<=1'b0;
            search_reminder<=1'b1;                 
         end else if (exit) begin
            search_use<=1'b0;
            search_on<=1'b0;    
            search_reminder<=1'b0;
         end 
     end
 end 
        
endmodule
