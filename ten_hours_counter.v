`timescale 1ns / 1ps

module ten_hours_counter(
    input [31:0] reminder_time,
    input wire clk,            // 时钟信号
    input wire reset,          // 复位信号
    input wire if_count,       // 是否计数
    input wire if_clean,       // 自动清零
    input wire if_hand_clean,  // 手动清零
    output reg time_out,       // 计时完成信号
    output reg [31:0] count    // 秒计数
);
    
    // 参数定义
    parameter MILLION = 100_000_000;  // 1 秒对应的时钟周期数

    // 分频计数器
    reg [31:0] prescaler;

    // 主逻辑
    always @(posedge clk or negedge reset) begin
        if (~reset) begin
            time_out <= 0;
            count <= 0;
            prescaler <= 0;
        end else if (if_clean || if_hand_clean) begin
            time_out <= 0;
            count <= 0;
            prescaler <= 0;
        end else begin 
            if (if_count) begin
                if (prescaler < MILLION) begin
                    prescaler <= prescaler + 1;
                end else begin
                    prescaler <= 0;
                    count <= count + 1;
                end
            end
            if (count >= reminder_time) begin
                time_out <= 1;
            end
        end
    end

endmodule
