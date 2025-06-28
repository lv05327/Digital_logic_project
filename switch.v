`timescale 1ns / 1ps

module switch(
  input clk, rst, menu, speed1, speed2, speed3, clean, power_status, used_power_3,
  output reg if_clean, 
  output reg [2:0] current_state,
  output reg start_count, //power3开始
  output reg start_count_idle, //3档返回待机倒计时
  output reg start_clean, //自清洁开始
  output reg if_count 
    );
    parameter IDLE = 3'b000;
    parameter MENU = 3'b001;
    parameter CLEAN = 3'b011;
    parameter power_1=3'b100;
    parameter power_2=3'b101;
    parameter power_3=3'b110;
    parameter COUNTDOWN_TIME =500_000_000;
    parameter DEBOUNCE_TIME =100_000_000;
    reg  [2:0] next_state;
    reg finish_count_idle;
    reg finish_count;
    reg finish_count_clean;
    reg [31:0] counter_1;
    reg [31:0]countdown_power3_power2;
    reg [31:0] counter_2;
    reg [31:0] countdown_power3_idle;
    reg [31:0] countdown_clean;
    reg [31:0] counter_3; 
    reg [31:0] counter_4;
    reg [31:0] counter_5;
    reg go_menu;
    reg power_3_time;

    
    always @(posedge clk or negedge rst) begin
      if (~rst || ~power_status) begin
        current_state <= IDLE;
        next_state <= IDLE;
         finish_count_idle<=0;
         finish_count<=0;
         start_count<=0;
         start_count_idle<=0;
         start_clean<=0;
         counter_1<=0;
         counter_2<=0;
         counter_3<=0;
         countdown_power3_power2<=0;
         countdown_power3_idle<=0;
         countdown_clean<=0;
         if_clean<=0;
         if_count<=0;
         power_3_time<=0;
         counter_4<=0;
         counter_5<=0;
         go_menu<=1;
      end else begin
       case (current_state)
           
             IDLE:
               if (menu&&go_menu) begin
                 next_state <= MENU;
               end else begin
                 next_state <= IDLE;
               end
             MENU:
               if (speed1) begin
                 next_state<=power_1;
                 if_count<=1;
               end else if (speed2) begin
                 next_state<=power_2;
                  if_count<=1;
               end else if (speed3&&~power_3_time) begin
                 next_state<=power_3;
                 start_count<=1;
                 if_count<=1;
                 power_3_time<=1;
               end  else if (clean) begin
                 next_state<=CLEAN;
                 start_clean<=1;
              
               end else if (menu) begin
                 next_state <= MENU;
               end
         
             CLEAN:begin
             
             if(clean) begin
             next_state<=CLEAN;
             end
             if(finish_count_clean)begin
                          next_state<=IDLE;
                          start_clean<=0;
                          finish_count_clean<=0;
                          counter_3<=0;
                          if_clean<=1;
                          end
             end
             
             power_1:begin
                     if(menu)begin
                     next_state<=IDLE;
                     if_count<=0;
                     go_menu<=0;
                     end
                     else if(speed2) begin
                     next_state<=power_2;
                     end else begin
                     next_state<=power_1;
                     end
                     end
             power_2:begin
                         if(menu)begin
                         next_state<=IDLE;
                         if_count<=0;
                         go_menu<=0;
                         end
                          else if(speed1) begin
                          next_state<=power_1;
                           end else begin
                        next_state<=power_2;
                   end
                     end
             power_3:begin
             if(menu)begin
             start_count_idle<=1;
             start_count<=0;
             end
             if(finish_count_idle)begin
             next_state<=IDLE;
             start_count_idle<=0;
             finish_count_idle<=0;
             counter_2<=0;
             if_count<=0;
             end
             if(finish_count)begin
             next_state<=power_2;
             start_count<=0;
             finish_count<=0;
             counter_1<=0;
             end
         end
           endcase
            if (start_count) begin   
                                   if (countdown_power3_power2 < COUNTDOWN_TIME) begin
                                       countdown_power3_power2 <= countdown_power3_power2 + 1;
                                   end else begin
                                       counter_1 <= counter_1+1;
                                       countdown_power3_power2<=0;
                                   end
                               end
                               if(counter_1==12)begin
                               finish_count<=1;
                               end
                       if (start_count_idle) begin
                          if (countdown_power3_idle < COUNTDOWN_TIME) begin
                              countdown_power3_idle <= countdown_power3_idle + 1;
                              end else begin
                              counter_2 <= counter_2+1;
                              countdown_power3_idle<=0;
                                 end
                              end
                              if(counter_2==12)begin
                              finish_count_idle<=1;
   end
   if (start_clean) begin   
                                      if (countdown_clean < COUNTDOWN_TIME) begin
                                          countdown_clean <= countdown_clean + 1;
                                      end else begin
                                          counter_3 <= counter_3+1;
                                          countdown_clean<=0;
                                      end
                                  end
                                  if(counter_3==36)begin
                                  finish_count_clean<=1;
                                  end
   if(if_clean)begin
        if (counter_4 < COUNTDOWN_TIME) begin
                                             counter_4 <= counter_4 + 1;
                                         end
                                         else begin
                                         if_clean<=0;
                                         counter_4<=0;
                                         end
   end     
      if(~go_menu)begin
        if (counter_5 < COUNTDOWN_TIME) begin
                                             counter_5 <= counter_5 + 1;
                                         end
                                         else begin
                                         go_menu<=1;
                                         counter_5<=0;
                                         end
   end     
        current_state <= next_state;
      end
    end
endmodule