`timescale 1ns / 1ps

module reference_setting (
    input clk,                  // 时钟信号
    input rst,                // 复位信号
    input reminder_enable,
    input gesture_enable,
    input power_status,
    input up_button,
    input bottom_button,
    output reg [31:0] reminder_time, // 设置触发智能提醒的使用时长
    output reg [29:0] gesture_time // 设置手势开关的有效时间
);

    parameter DEBOUNCE_TIME = 20_000_000;    // 去抖延时 200 ms

    // 存储触发智能提醒的使用时长上限20小时，下限0小时
    reg [42:0] max_reminder_time;
    
    // 存储手势开关有效时间上限10秒，下限5秒
    reg [29:0] max_gesture_time;
    
    reg power_status_prev;
    reg power_status_now;
    
    wire up_stable;
    wire bottom_stable;
    
    wire up_pulse;
    wire bottom_pulse;
    
    // 去抖模块
    debouncer_pulse #(.DEBOUNCE_TIME(DEBOUNCE_TIME)) dp_up_1 (
        .clk(clk),
        .rst(rst),
        .button_in(up_button),
        .button_out(up_stable),
        .button_pulse(up_pulse)
    );
    
    debouncer_pulse #(.DEBOUNCE_TIME(DEBOUNCE_TIME)) dp_bottom_1 (
        .clk(clk),
        .rst(rst),
        .button_in(bottom_button),
        .button_out(bottom_stable),
        .button_pulse(bottom_pulse)
    );
    
    // 开机初始化处理
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            power_status_prev <= 0;
            power_status_now <= 0;
        end else begin
            power_status_prev <= power_status;
            power_status_now <= power_status_prev;
        end
    end

    // 在复位时初始化寄存器
    always @(posedge clk or negedge rst) begin
        if (~rst || (~power_status_prev && power_status_now)) begin
            // 复位时恢复默认值
            max_reminder_time <= 32'd72000;  // 默认最大智能提醒触发时长为20小时
            max_gesture_time <= 30'd1000000000; // 默认最大手势有效时间为10秒
            reminder_time <= 32'd36000;
            gesture_time <= 30'd500000000;           
        end else if (power_status) begin
            if (reminder_enable) begin
               if (up_pulse) begin
                   if (reminder_time == max_reminder_time) reminder_time <= max_reminder_time;
                   else reminder_time <= reminder_time + 32'd3600; //每次加一小时                   
               end else if (bottom_pulse) begin
                   if (reminder_time == 32'd0) reminder_time <= 32'd0;
                   else reminder_time <= reminder_time - 32'd3600; //每次减一小时
               end
            end else if (gesture_enable) begin
                if (up_pulse) begin
                    if (gesture_time == max_gesture_time) gesture_time <= max_gesture_time;
                    else gesture_time <= gesture_time + 30'd100000000; //每次加一秒                   
                end else if (bottom_pulse) begin
                    if (gesture_time == 30'd100000000) reminder_time <= 43'd100000000;
                    else gesture_time <= gesture_time - 30'd100000000; //每次减一秒
                end
            end 
        end

    end

endmodule

