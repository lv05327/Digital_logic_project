`timescale 1ns / 1ps

module overall_design(
    input clk, //时钟信号，100MHz
    input rst, //reset信号，低电平有效
    input power_button, //开关机按键,也就是中间按键
    input left_button, //左边按键
    input right_button, //右边按键
    input up_button, //上面按键
    input bottom_button, //下面按键
    input [4:0] switch, //左边五个大开关，控制工作模式
    input reminder_enable, //第六个大开关，智能提醒参数设置
    input gesture_enable, //第七个大开关，手势开关参数设置
    input current_time_setting, //最右边大开关
    input lighting_switch, //最右边小开关，照明模式
    input hand_clean, //最左边小开关,手动自清洁
    input search_in_1, //第四个小开关，查询手势开关时间
    input search_in_2, //第五个小开关，查询工作时间
    input search_in_3, //第三个小开关，查询智能提醒时间
    input exit, //退出查询,第六个小开关
    output reg power_status, // 开关机状态 (1: 开机, 0: 关机) 中间的按键控制
    output [7:0] selection, //片选信号
    output [7:0] left_time, //左边段选信号
    output [7:0] right_time, //右边段选信号
    output [5:0] led1, //左边大灯,控制时间设置
    output reg [2:0] led2, //右边小灯，描述工作状态（详见下面状态参数）
    output reg led3, //是否在自清洁
    output reg time_out, //需要自清洁,L1
    output reg light, //照明模式
    output beep //蜂鸣器
);
    
    // 蜂鸣器参数
    parameter CNT_MAX = 25'd24_999_999;
    parameter DO = 18'd190839;
    parameter RE = 18'd170067;
    parameter MI = 18'd151514;
    parameter FA = 18'd143265;
    parameter SO = 18'd127550;
    parameter LA = 18'd113635;
    parameter XI = 18'd101213;   
    
    // 时钟分频参数
    parameter CLOCK_FREQ = 100_000_000; // 100 MHz
    parameter ONE_SECOND = CLOCK_FREQ;  // 1 秒对应的时钟周期数
    parameter REFRESH_FREQ = 1_000;     // 数码管刷新频率 1 kHz
    parameter REFRESH_DIV = CLOCK_FREQ / REFRESH_FREQ;

    parameter LONG_PRESS_TIME = 300_000_000; // 长按 3 秒 (假设 100 MHz 时钟)
    parameter DEBOUNCE_TIME = 20_000_000;    // 去抖延时 200 ms
    parameter COUNTDOWN_TIME = 500_000_000;  // 5 秒倒计时
    
    //工作状态参数
    parameter IDLE = 3'b000;
    parameter MENU = 3'b001;
    parameter CLEAN = 3'b011;
    parameter power_1=3'b100;
    parameter power_2=3'b101;
    parameter power_3=3'b110;
    
    //智能提醒参数
    parameter MILLION = 100_000_000;
    
    // 实时控制的参数
    wire [42:0] reminder_time;
    wire [29:0] gesture_time;    
    
    //中间信号如下
    wire used_power_3;
    wire power_status_wire;
    wire light_wire;
    wire time_out_wire;    
    wire start_count;
    wire start_count_idle;
    wire start_clean;
    wire if_count;
    wire [2:0] state;
    
    wire search_use;
    wire search_on;
    wire search_reminder;
    
    wire if_clean;
    wire [31:0] count;    
    
    //各模块实例化如下
    lighting_mode lm(
    .clk(clk),
    .rst(rst),
    .lighting_button(lighting_switch),
    .power_status(power_status_wire),
    .light(light_wire)
    );
    
    turn_on_and_off #(
    .LONG_PRESS_TIME(LONG_PRESS_TIME),
    .DEBOUNCE_TIME(DEBOUNCE_TIME)
    ) toaf (
    .clk(clk),
    .rst(rst),
    .power_button(power_button),
    .left_button(left_button),
    .right_button(right_button),
    .gesture_time(gesture_time),
    .power_status(power_status_wire),
    .selection(selection)
    );
    
    display #(
    .DEBOUNCE_TIME(DEBOUNCE_TIME),
    .CLOCK_FREQ(CLOCK_FREQ),
    .ONE_SECOND(ONE_SECOND),
    .REFRESH_FREQ(REFRESH_FREQ),
    .REFRESH_DIV(REFRESH_DIV)
    ) ctd (
    .clk(clk),
    .rst(rst),
    .power_status(power_status_wire),
    .up_button(up_button),
    .bottom_button(bottom_button),
    .left_button(left_button),
    .right_button(right_button),
    .current_time_setting(current_time_setting),
    .search_use(search_use),
    .search_on(search_on),
    .search_reminder(search_reminder),
    .reminder_time(reminder_time),
    .gesture_time(gesture_time),
    .count(count),
    .start_count(start_count),
    .start_count_idle(start_count_idle),
    .start_clean(start_clean),
    .seg_out_left(left_time),
    .seg_out_right(right_time),
    .seg_en_left(selection[7:4]),
    .seg_en_right(selection[3:0]),
    .led1(led1)
    );
    
    search sch (
    .power_status(power_status_wire),
    .state(state),
    .search_in_1(search_in_1),
    .search_in_2(search_in_2),
    .search_in_3(search_in_3),
    .clk(clk),
    .rst(rst),
    .exit_in(exit),
    .search_use(search_use),
    .search_on(search_on),
    .search_reminder(search_reminder)
    );
    
    switch #(
    .IDLE(IDLE),
    .MENU(MENU),
    .CLEAN(CLEAN),
    .power_1(power_1),
    .power_2(power_2),
    .power_3(power_3),
    .COUNTDOWN_TIME(COUNTDOWN_TIME)
    ) s (
    .clk(clk),
    .rst(rst),
    .menu(switch[0]),
    .speed1(switch[1]),
    .speed2(switch[2]),
    .speed3(switch[3]),
    .clean(switch[4]),
    .power_status(power_status_wire),
    .used_power_3(used_power_3),
    .if_clean(if_clean),
    .current_state(state),
    .start_count(start_count),
    .start_count_idle(start_count_idle),
    .start_clean(start_clean),
    .if_count(if_count)
    );
    
    ten_hours_counter #(
    .MILLION(MILLION)
    ) thc (
    .reminder_time(reminder_time),
    .clk(clk),
    .reset(rst),
    .if_count(if_count),
    .if_clean(if_clean),
    .if_hand_clean(hand_clean),
    .time_out(time_out_wire),
    .count(count)
    );
    
    reference_setting #(
    .DEBOUNCE_TIME(DEBOUNCE_TIME)
    ) rs (
    .clk(clk),
    .rst(rst),
    .reminder_enable(reminder_enable),
    .gesture_enable(gesture_enable),
    .power_status(power_status_wire),
    .up_button(up_button),
    .bottom_button(bottom_button),
    .reminder_time(reminder_time),
    .gesture_time(gesture_time)
    );
    
    beep #(
    .CNT_MAX(CNT_MAX),
    .DO(DO),
    .RE(RE),
    .MI(MI),
    .FA(FA),
    .SO(SO),
    .LA(LA),
    .XI(XI)
    ) b (
    .clk(clk),
    .rst(rst),
    .enable(time_out),
    .beep(beep)
    );
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            power_status <= 0;
        end else begin
            power_status <= power_status_wire;
        end
    end
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            time_out <= 0;
        end else begin
            time_out <= time_out_wire;
        end
    end    
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            led3 <= 0;
        end else begin
            led3 <= if_clean;
        end
    end
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            led2 <= 0;
        end else begin
            led2 <= state;
        end
    end    
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            light <= 0;
        end else begin
            light <= light_wire;
        end
    end
     
endmodule


// 连续信号去抖模块
module debouncer #(
    parameter DEBOUNCE_TIME = 20_000_000 // 去抖延时 (默认 200 ms)
)(
    input clk,
    input rst,
    input button_in,
    output reg button_out
);
    reg [24:0] counter;  // 去抖计数器
    reg button_sync;     // 同步后的按键信号

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            counter <= 0;
            button_sync <= 0;
            button_out <= 0;
        end else begin
            button_sync <= button_in;
            if (button_sync == button_out) begin
                counter <= 0;
            end else begin
                counter <= counter + 1;
                if (counter >= DEBOUNCE_TIME) begin
                    button_out <= button_sync;
                    counter <= 0;
                end
            end
        end
    end
endmodule

// 脉冲信号去抖模块
module debouncer_pulse #(
    parameter DEBOUNCE_TIME = 20_000_000 // 去抖延时 (默认 200 ms)
)(
    input clk,
    input rst,
    input button_in,
    output reg button_out,
    output wire button_pulse  // 按键脉冲输出
);
    // 使用局部信号确保不同实例之间互不干扰
    reg [24:0] counter = 0;     // 去抖计数器
    reg button_sync = 0;        // 同步后的按键信号
    reg button_out_prev = 0;    // 上一个输出状态

    // 主去抖逻辑
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            counter <= 0;
            button_sync <= 0;
            button_out <= 0;
        end else begin
            button_sync <= button_in;
            if (button_sync == button_out) begin
                counter <= 0; // 按键状态稳定，计数器清零
            end else begin
                counter <= counter + 1; // 按键状态变化，计数器累加
                if (counter >= DEBOUNCE_TIME) begin
                    button_out <= button_sync; // 按键状态稳定后更新输出
                    counter <= 0;
                end
            end
        end
    end

    // 脉冲生成逻辑
    always @(posedge clk or negedge rst) begin
        if (!rst)
            button_out_prev <= 0; // 复位时清零
        else
            button_out_prev <= button_out; // 保存上一个状态
    end

    // 输出单周期脉冲信号
    assign button_pulse = (button_out && !button_out_prev); // 仅在上升沿产生脉冲

endmodule
