`timescale 1ns / 1ps

// 调整刷新
module display(
    input clk,           // 系统时钟 (100 MHz)
    input rst,           // 复位信号
    input power_status,  // 电源状态
    input up_button,
    input bottom_button,
    input left_button,
    input right_button,
    input current_time_setting,      //当前时间设置模式
    input search_use,
    input search_on,
    input search_reminder,
    input [42:0] reminder_time,
    input [29:0] gesture_time,
    input [31:0] count,
    input start_count,
    input start_count_idle,
    input start_clean,
    output reg [7:0] seg_out_left,   // 左边数码管段选信号
    output reg [7:0] seg_out_right,  // 右边数码管段选信号
    output reg [3:0] seg_en_left,    // 左边数码管片选信号
    output reg [3:0] seg_en_right,    // 右边数码管片选信号
    output reg [5:0] led1
);
    
    //累计工作时间
    wire [4:0] work_hours;
    wire [5:0] work_minutes;
    wire [5:0] work_seconds;
    
    assign work_hours = count / 3600;
    assign work_minutes = (count % 3600) / 60;
    assign work_seconds = (count % 3600) % 60;

    // 消抖参数
    parameter DEBOUNCE_TIME = 20_000_000;    // 去抖延时 200 ms
    // 时钟分频参数
    parameter CLOCK_FREQ = 100_000_000; // 100 MHz
    parameter ONE_SECOND = CLOCK_FREQ;  // 1 秒对应的时钟周期数
    parameter REFRESH_FREQ = 500;     // 数码管刷新频率 500Hz
    parameter REFRESH_DIV = CLOCK_FREQ / REFRESH_FREQ;
    
    //智能提醒时间
    wire [4:0] qrt_hours;
    wire [5:0] qrt_minutes;
    wire [5:0] qrt_seconds;
    
    assign qrt_seconds = (reminder_time % 3600) % 60;
    assign qrt_minutes = (reminder_time % 3600) / 60;
    assign qrt_hours = reminder_time / 3600;
    
    //手势开关时间
    wire [4:0] qgt_hours;
    wire [5:0] qgt_minutes;    
    wire [5:0] qgt_seconds;
    
    assign qgt_seconds = gesture_time / 100000000;
    assign qgt_minutes = 0;
    assign qgt_hours = 0;
    
    //倒计时
    reg [4:0] cd_hours;
    reg [5:0] cd_minutes;
    reg [5:0] cd_seconds;
   
    //消抖后的按钮信号
    wire up_stable;
    wire bottom_stable;
    wire left_stable;
    wire right_stable;
    
    //脉冲按钮信号
    wire up_pulse;
    wire bottom_pulse;
    wire left_pulse;
    wire right_pulse;
    
    //状态定义
    reg [2:0] time_select;              //000：秒个位，001：秒十位，010：分个位，011：分十位，100：时个位，101：时十位

    // 分频信号
    reg [26:0] clk_counter = 0;         // 1Hz 分频计数器
    reg one_hz_enable = 0;              // 1Hz 使能信号
    reg [15:0] refresh_counter = 0;     // 数码管刷新分频计数器
    wire refresh_clk = refresh_counter[14]; // 500Hz 刷新时钟

    // 时间计数器
    reg [5:0] seconds = 0;
    reg [5:0] minutes = 0;
    reg [4:0] hours = 0;

    // 显示选择
    reg [2:0] digit_select = 0;         // 当前选择的数码管
    reg blink;                          // 冒号闪烁信号

    // 同步复位信号
    reg rst_sync;
    always @(posedge clk or negedge rst) begin
        if (~rst)
            rst_sync <= 0;
        else
            rst_sync <= 1;
    end
    
    reg start_count_prev;
    reg start_count_now;
    reg start_count_idle_prev;
    reg start_count_idle_now;
    reg start_clean_prev;
    reg start_clean_now;
    
    always @(posedge clk or negedge rst_sync) begin
        if (~rst_sync) begin
            start_count_prev <= 0;
            start_count_now <= 0;
        end else begin
            start_count_prev <= start_count;
            start_count_now <= start_count_prev;
        end
    end
    
    always @(posedge clk or negedge rst_sync) begin
        if (~rst_sync) begin
            start_count_idle_prev <= 0;
            start_count_idle_now <= 0;
        end else begin
            start_count_idle_prev <= start_count_idle;
            start_count_idle_now <= start_count_idle_prev;
        end
    end

    always @(posedge clk or negedge rst_sync) begin
        if (~rst_sync) begin
            start_clean_prev <= 0;
            start_clean_now <= 0;
        end else begin
            start_clean_prev <= start_clean;
            start_clean_now <= start_clean_prev;
        end
    end
    
    always @ (posedge clk or negedge rst_sync) begin
        if(~rst_sync) begin
            cd_hours <= 0;
            cd_minutes <= 0;
            cd_seconds <= 0;
        end else if (~power_status) begin
            cd_seconds <= 0;
            cd_minutes <= 0;
            cd_hours <= 0;
        end else begin
            if (start_count_prev && (~start_count_now)) begin
                cd_minutes <= 1;
                cd_seconds <= 0;
            end
            if (start_count_idle_prev && (~start_count_idle_now)) begin
                cd_minutes <= 1;
                cd_seconds <= 0;                
            end
            if (start_clean_prev && (~start_clean_now)) begin
                cd_minutes <= 3;
                cd_seconds <= 0;                
            end 
            
            if (one_hz_enable) begin // 电源开启时，非设置模式且触发1Hz时更新时间
                if (cd_seconds == 0) begin
                    // 秒数为 0 时，先检查分钟
                    if (cd_minutes > 0) begin
                        cd_seconds <= 59;  // 重置秒数为59
                        cd_minutes <= cd_minutes - 1;  // 分钟递减
                    end else begin
                        // 分钟为 0 时，检查小时
                        if (cd_hours > 0) begin
                            cd_seconds <= 59;  // 秒数重置为 59
                            cd_hours <= cd_hours - 1;  // 小时递减
                        end
                    end
                end else begin
                    // 秒数递减
                    cd_seconds <= cd_seconds - 1;
                end
            end

        end
    end

    
    always @(posedge clk or negedge rst_sync) begin
        if (~rst_sync) begin
            time_select <= 3'b000;
        end else if (~current_time_setting) begin
            time_select <= 3'b000;
            end else begin
            if (left_pulse) begin
                time_select <= (time_select == 3'b101) ? 3'b000 : time_select + 1'b1;
            end else if (right_pulse) begin
                time_select <= (time_select == 3'b000) ? 3'b101 : time_select - 1'b1;
            end
        end
    end


    // 1Hz 分频生成
    always @(posedge clk or negedge rst_sync) begin
        if (~rst_sync) begin
            clk_counter <= 0;
            one_hz_enable <= 0;
        end else begin
            if (clk_counter == ONE_SECOND - 1) begin
                clk_counter <= 0;
                one_hz_enable <= 1;
            end else begin
                clk_counter <= clk_counter + 1;
                one_hz_enable <= 0;
            end
        end
    end
    
    reg setting_prev;
    reg setting_now;
    
    always @ (posedge clk or negedge rst_sync) begin
        if (~rst_sync) begin
        setting_prev <= 0;
        setting_now <= 0;
        end else if (power_status) begin
            setting_prev <= current_time_setting;
            setting_now <= setting_prev;
        end
    end
    
    always @ (posedge clk or negedge rst_sync) begin
        if (~rst_sync) begin
            led1 <= 6'b000000;
        end else if (~power_status || ~current_time_setting) begin
            led1 <= 6'b000000;    
        end else begin
            if (setting_prev && (~setting_now)) led1 <= 6'b000001;        
            case (led1)
                6'b000001: begin
                    if (left_pulse) led1 <= 6'b000010;
                    else if (right_pulse) led1 <= 6'b100000;
                end
                6'b000010: begin
                    if (left_pulse) led1 <= 6'b000100;
                    else if (right_pulse) led1 <= 6'b000001;
                end
                6'b000100: begin
                    if (left_pulse) led1 <= 6'b001000;
                    else if (right_pulse) led1 <= 6'b000010;
                end
                6'b001000: begin
                    if (left_pulse) led1 <= 6'b010000;
                    else if (right_pulse) led1 <= 6'b000100;
                end
                6'b010000: begin
                    if (left_pulse) led1 <= 6'b100000;
                    else if (right_pulse) led1 <= 6'b001000;
                end
                6'b100000: begin
                    if (left_pulse) led1 <= 6'b000001;
                    else if (right_pulse) led1 <= 6'b010000;
                end
            endcase
        end
    end

    // 冒号闪烁信号
    always @(posedge clk or negedge rst_sync) begin
        if (~rst_sync)
            blink <= 0;
        else if (one_hz_enable)
            blink <= ~blink;
    end

    // 时间计数逻辑
    always @(posedge clk or negedge rst_sync) begin
        if (~rst_sync) begin
            seconds <= 0;
            minutes <= 0;
            hours <= 0;
        end else if (~power_status) begin
            seconds <= 0;
            minutes <= 0;
            hours <= 0;
        end else if (current_time_setting) begin
            case (time_select)
                3'b000: begin // 秒个位
                    if (up_pulse) seconds <= (seconds == 59) ? 0 : (seconds + 1);
                    else if (bottom_pulse) seconds <= (seconds == 0) ? 59 : (seconds - 1);
                end
                3'b001: begin // 秒十位
                    if (up_pulse) seconds <= (seconds / 10 == 5) ? (seconds - 50) : (seconds + 10);
                    else if (bottom_pulse) seconds <= (seconds / 10 == 0) ? (seconds + 50) : (seconds - 10);
                end
                3'b010: begin // 分个位
                    if (up_pulse) minutes <= (minutes == 59) ? 0 : (minutes + 1);
                    else if (bottom_pulse) minutes <= (minutes == 0) ? 59 : (minutes - 1);
                end
                3'b011: begin // 分十位
                    if (up_pulse) minutes <= (minutes / 10 == 5) ? (minutes - 50) : (minutes + 10);
                    else if (bottom_pulse) minutes <= (minutes / 10 == 0) ? (minutes + 50) : (minutes - 10);
                end
                3'b100: begin // 时个位
                    if (up_pulse) hours <= (hours == 23) ? 0 : (hours + 1);
                    else if (bottom_pulse) hours <= (hours == 0) ? 23 : (hours - 1);
                end
                3'b101: begin // 时十位
                    if (up_pulse) hours <= (hours / 10 == 2) ? (hours - 20) : (hours + 10);
                    else if (bottom_pulse) hours <= (hours / 10 == 0) ? (hours + 20) : (hours - 10);
                end
            endcase
        end else if (one_hz_enable) begin // 电源开启时，非设置模式且触发1Hz时更新时间
            if (seconds == 59) begin
                seconds <= 0;
                if (minutes == 59) begin
                    minutes <= 0;
                    if (hours == 23)
                        hours <= 0;
                    else
                        hours <= hours + 1;
                end else
                    minutes <= minutes + 1;
            end else
                seconds <= seconds + 1;
        end
    end

    // 数码管刷新分频器
    always @(posedge clk or negedge rst_sync) begin
        if (~rst_sync)
            refresh_counter <= 0;
        else
            refresh_counter <= refresh_counter + 1;
    end

    // 数码管显示逻辑
    always @(posedge refresh_clk or negedge rst_sync) begin
        if (~rst_sync) begin
            digit_select <= 0;
            seg_en_left <= 4'b0000;
            seg_en_right <= 4'b0000;
        end else begin
            digit_select <= digit_select + 1; // 循环选择数码管
            if (search_use) begin
                case (digit_select)            
                    3'b000: begin
                        seg_out_left <= 8'b0000_0000; // 秒个位
                        seg_en_left <= 4'b0000;
                        seg_out_right <= digit_to_seg(qgt_seconds % 10);
                        seg_en_right <= 4'b0001;
                    end
                    3'b001: begin
                        seg_out_left <= 8'b0000_0000; // 秒十位
                        seg_en_left <= 4'b0000;
                        seg_out_right <= digit_to_seg(qgt_seconds / 10);
                        seg_en_right <= 4'b0010;
                    end
                    3'b010: begin
                        seg_out_left <= 8'b0000_0000;
                        seg_en_left <= 4'b0000;
                        seg_out_right <= 8'b0000_0000;
                        seg_en_right <= 4'b0000;
                    end
                    3'b011: begin
                        seg_out_left <= 8'b0000_0000;  // 分个位
                        seg_en_left <= 4'b0000;
                        seg_out_right <= 8'b0000_0000;
                        seg_en_right <= 4'b0000;
                    end
                    3'b100: begin
                        seg_out_right <= 8'b0000_0000; //分十位
                        seg_en_right <= 4'b0000;
                        seg_out_left <= 8'b0000_0000;
                        seg_en_left <= 4'b0000;
                    end
                    3'b101: begin
                        seg_out_right <= 8'b0000_0000;
                        seg_en_right <= 4'b0000;
                        seg_out_left <= 8'b0000_0000;
                        seg_en_left <= 4'b0000;
                    end
                    3'b110: begin
                        seg_out_right <= 8'b0000_0000; // 时个位
                        seg_en_right <= 4'b0000;
                        seg_out_left <= 8'b0000_0000;
                        seg_en_left <= 4'b0000;
                    end
                   3'b111: begin
                        seg_out_right <= 8'b0000_0000; // 时十位
                        seg_en_right <= 4'b0000;
                        seg_out_left <= 8'b0000_0000;
                        seg_en_left <= 4'b0000;
                    end
                   default: begin
                        seg_out_left <= 8'b0000_0000;
                        seg_en_left <= 4'b0000;
                        seg_out_right <= 8'b0000_0000;
                        seg_en_right <= 4'b0000;
                    end
                endcase
                
            end else if (search_reminder) begin
                
            case (digit_select)
                3'b000: begin
                    seg_out_left <= 8'b0000_0000; // 秒个位
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(qrt_seconds % 10);
                    seg_en_right <= 4'b0001;
                end
                3'b001: begin
                    seg_out_left <= 8'b0000_0000; // 秒十位
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(qrt_seconds / 10);
                    seg_en_right <= 4'b0010;
                end
                3'b010: begin
                    seg_out_left <= 8'b0000_0000; // 左边无输出
                    seg_en_left <= 4'b0000;
                    seg_out_right <= (blink ? 8'b0000_1100 : 8'b0000_0000); // 冒号闪烁
                    seg_en_right <= 4'b0100;
                end
                3'b011: begin
                    seg_out_left <= 8'b0000_0000;  // 分个位
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(qrt_minutes % 10);
                    seg_en_right <= 4'b1000;
                end
                3'b100: begin
                    seg_out_right <= 8'b0000_0000; //分十位
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(qrt_minutes / 10);
                    seg_en_left <= 4'b0001;
                end
                3'b101: begin
                    seg_out_right <= 8'b0000_0000;
                    seg_en_right <= 4'b0000;
                    seg_out_left <= (blink ? 8'b0000_1100 : 8'b0000_0000); // 冒号闪烁
                    seg_en_left <= 4'b0010;
                end
                3'b110: begin
                    seg_out_right <= 8'b0000_0000; // 时个位
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(qrt_hours % 10);
                    seg_en_left <= 4'b0100;
                end
                3'b111: begin
                    seg_out_right <= 8'b0000_0000; // 时十位
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(qrt_hours / 10);
                    seg_en_left <= 4'b1000;
                end
                default: begin
                    seg_out_left <= 8'b0000_0000;
                    seg_en_left <= 4'b0000;
                    seg_out_right <= 8'b0000_0000;
                    seg_en_right <= 4'b0000;
                end
            endcase                            
            
            end else if (search_on) begin
            
            case (digit_select)
                3'b000: begin
                    seg_out_left <= 8'b0000_0000; // 秒个位
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(work_seconds % 10);
                    seg_en_right <= 4'b0001;
                end
                3'b001: begin
                    seg_out_left <= 8'b0000_0000; // 秒十位
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(work_seconds / 10);
                    seg_en_right <= 4'b0010;
                end
                3'b010: begin
                    seg_out_left <= 8'b0000_0000; // 左边无输出
                    seg_en_left <= 4'b0000;
                    seg_out_right <= (blink ? 8'b0000_1100 : 8'b0000_0000); // 冒号闪烁
                    seg_en_right <= 4'b0100;
                end
                3'b011: begin
                    seg_out_left <= 8'b0000_0000;  // 分个位
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(work_minutes % 10);
                    seg_en_right <= 4'b1000;
                end
                3'b100: begin
                    seg_out_right <= 8'b0000_0000; //分十位
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(work_minutes / 10);
                    seg_en_left <= 4'b0001;
                end
                3'b101: begin
                    seg_out_right <= 8'b0000_0000;
                    seg_en_right <= 4'b0000;
                    seg_out_left <= (blink ? 8'b0000_1100 : 8'b0000_0000); // 冒号闪烁
                    seg_en_left <= 4'b0010;
                end
                3'b110: begin
                    seg_out_right <= 8'b0000_0000; // 时个位
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(work_hours % 10);
                    seg_en_left <= 4'b0100;
                end
                3'b111: begin
                    seg_out_right <= 8'b0000_0000; // 时十位
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(work_hours / 10);
                    seg_en_left <= 4'b1000;
                end
                default: begin
                    seg_out_left <= 8'b0000_0000;
                    seg_en_left <= 4'b0000;
                    seg_out_right <= 8'b0000_0000;
                    seg_en_right <= 4'b0000;
                end
            endcase            

            end else if (start_count || start_count_idle || start_clean) begin
            case (digit_select)
                3'b000: begin
                    seg_out_left <= 8'b0000_0000; // 秒个位
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(cd_seconds % 10);
                    seg_en_right <= 4'b0001;
                end
                3'b001: begin
                    seg_out_left <= 8'b0000_0000; // 秒十位
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(cd_seconds / 10);
                    seg_en_right <= 4'b0010;
                end
                3'b010: begin
                    seg_out_left <= 8'b0000_0000; // 左边无输出
                    seg_en_left <= 4'b0000;
                    seg_out_right <= (blink ? 8'b0000_1100 : 8'b0000_0000); // 冒号闪烁
                    seg_en_right <= 4'b0100;
                end
                3'b011: begin
                    seg_out_left <= 8'b0000_0000;  // 分个位
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(cd_minutes % 10);
                    seg_en_right <= 4'b1000;
                end
                3'b100: begin
                    seg_out_right <= 8'b0000_0000; //分十位
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(cd_minutes / 10);
                    seg_en_left <= 4'b0001;
                end
                3'b101: begin
                    seg_out_right <= 8'b0000_0000;
                    seg_en_right <= 4'b0000;
                    seg_out_left <= (blink ? 8'b0000_1100 : 8'b0000_0000); // 冒号闪烁
                    seg_en_left <= 4'b0010;
                end
                3'b110: begin
                    seg_out_right <= 8'b0000_0000; // 时个位
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(cd_hours % 10);
                    seg_en_left <= 4'b0100;
                end
                3'b111: begin
                    seg_out_right <= 8'b0000_0000; // 时十位
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(cd_hours / 10);
                    seg_en_left <= 4'b1000;
                end
                default: begin
                    seg_out_left <= 8'b0000_0000;
                    seg_en_left <= 4'b0000;
                    seg_out_right <= 8'b0000_0000;
                    seg_en_right <= 4'b0000;
                end
            endcase
            
            end else begin
            case (digit_select)
                3'b000: begin
                    seg_out_left <= 8'b0000_0000; // 秒个位
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(seconds % 10);
                    seg_en_right <= 4'b0001;
                end
                3'b001: begin
                    seg_out_left <= 8'b0000_0000; // 秒十位
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(seconds / 10);
                    seg_en_right <= 4'b0010;
                end
                3'b010: begin
                    seg_out_left <= 8'b0000_0000; // 左边无输出
                    seg_en_left <= 4'b0000;
                    seg_out_right <= (blink ? 8'b0000_1100 : 8'b0000_0000); // 冒号闪烁
                    seg_en_right <= 4'b0100;
                end
                3'b011: begin
                    seg_out_left <= 8'b0000_0000;  // 分个位
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(minutes % 10);
                    seg_en_right <= 4'b1000;
                end
                3'b100: begin
                    seg_out_right <= 8'b0000_0000; //分十位
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(minutes / 10);
                    seg_en_left <= 4'b0001;
                end
                3'b101: begin
                    seg_out_right <= 8'b0000_0000;
                    seg_en_right <= 4'b0000;
                    seg_out_left <= (blink ? 8'b0000_1100 : 8'b0000_0000); // 冒号闪烁
                    seg_en_left <= 4'b0010;
                end
                3'b110: begin
                    seg_out_right <= 8'b0000_0000; // 时个位
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(hours % 10);
                    seg_en_left <= 4'b0100;
                end
                3'b111: begin
                    seg_out_right <= 8'b0000_0000; // 时十位
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(hours / 10);
                    seg_en_left <= 4'b1000;
                end
                default: begin
                    seg_out_left <= 8'b0000_0000;
                    seg_en_left <= 4'b0000;
                    seg_out_right <= 8'b0000_0000;
                    seg_en_right <= 4'b0000;
                end
            endcase
            end
        end
    end

    // 数字到段选信号的转换函数
    function [7:0] digit_to_seg;
        input [3:0] digit;
        case (digit)
            4'd0: digit_to_seg = 8'b1111_1100; // 显示 0
            4'd1: digit_to_seg = 8'b0110_0000; // 显示 1
            4'd2: digit_to_seg = 8'b1101_1010; // 显示 2
            4'd3: digit_to_seg = 8'b1111_0010; // 显示 3
            4'd4: digit_to_seg = 8'b0110_0110; // 显示 4
            4'd5: digit_to_seg = 8'b1011_0110; // 显示 5
            4'd6: digit_to_seg = 8'b1011_1110; // 显示 6
            4'd7: digit_to_seg = 8'b1110_0000; // 显示 7
            4'd8: digit_to_seg = 8'b1111_1110; // 显示 8
            4'd9: digit_to_seg = 8'b1111_0110; // 显示 9
            default: digit_to_seg = 8'b0000_0000; // 默认关闭
        endcase
    endfunction
    
    // 去抖模块 (使用 debouncer_pulse)
     debouncer_pulse #(.DEBOUNCE_TIME(DEBOUNCE_TIME)) dp_up (
         .clk(clk),
         .rst(rst_sync),
         .button_in(up_button),
         .button_out(up_stable),     // 稳定按键输出
         .button_pulse(up_pulse)    // 按键单周期脉冲
     );
     
     debouncer_pulse #(.DEBOUNCE_TIME(DEBOUNCE_TIME)) dp_bottom (
         .clk(clk),
         .rst(rst_sync),
         .button_in(bottom_button),
         .button_out(bottom_stable),  // 稳定按键输出
         .button_pulse(bottom_pulse)  // 按键单周期脉冲
     );
     
     debouncer_pulse #(.DEBOUNCE_TIME(DEBOUNCE_TIME)) dp_left (
         .clk(clk),
         .rst(rst_sync),
         .button_in(left_button),
         .button_out(left_stable),   // 稳定按键输出
         .button_pulse(left_pulse)   // 按键单周期脉冲
     );
     
     debouncer_pulse #(.DEBOUNCE_TIME(DEBOUNCE_TIME)) dp_right (
         .clk(clk),
         .rst(rst_sync),
         .button_in(right_button),
         .button_out(right_stable),  // 稳定按键输出
         .button_pulse(right_pulse)  // 按键单周期脉冲
     );

endmodule


