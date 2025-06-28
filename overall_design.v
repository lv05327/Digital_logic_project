`timescale 1ns / 1ps

module overall_design(
    input clk, //ʱ���źţ�100MHz
    input rst, //reset�źţ��͵�ƽ��Ч
    input power_button, //���ػ�����,Ҳ�����м䰴��
    input left_button, //��߰���
    input right_button, //�ұ߰���
    input up_button, //���水��
    input bottom_button, //���水��
    input [4:0] switch, //�������󿪹أ����ƹ���ģʽ
    input reminder_enable, //�������󿪹أ��������Ѳ�������
    input gesture_enable, //���߸��󿪹أ����ƿ��ز�������
    input current_time_setting, //���ұߴ󿪹�
    input lighting_switch, //���ұ�С���أ�����ģʽ
    input hand_clean, //�����С����,�ֶ������
    input search_in_1, //���ĸ�С���أ���ѯ���ƿ���ʱ��
    input search_in_2, //�����С���أ���ѯ����ʱ��
    input search_in_3, //������С���أ���ѯ��������ʱ��
    input exit, //�˳���ѯ,������С����
    output reg power_status, // ���ػ�״̬ (1: ����, 0: �ػ�) �м�İ�������
    output [7:0] selection, //Ƭѡ�ź�
    output [7:0] left_time, //��߶�ѡ�ź�
    output [7:0] right_time, //�ұ߶�ѡ�ź�
    output [5:0] led1, //��ߴ��,����ʱ������
    output reg [2:0] led2, //�ұ�С�ƣ���������״̬���������״̬������
    output reg led3, //�Ƿ��������
    output reg time_out, //��Ҫ�����,L1
    output reg light, //����ģʽ
    output beep //������
);
    
    // ����������
    parameter CNT_MAX = 25'd24_999_999;
    parameter DO = 18'd190839;
    parameter RE = 18'd170067;
    parameter MI = 18'd151514;
    parameter FA = 18'd143265;
    parameter SO = 18'd127550;
    parameter LA = 18'd113635;
    parameter XI = 18'd101213;   
    
    // ʱ�ӷ�Ƶ����
    parameter CLOCK_FREQ = 100_000_000; // 100 MHz
    parameter ONE_SECOND = CLOCK_FREQ;  // 1 ���Ӧ��ʱ��������
    parameter REFRESH_FREQ = 1_000;     // �����ˢ��Ƶ�� 1 kHz
    parameter REFRESH_DIV = CLOCK_FREQ / REFRESH_FREQ;

    parameter LONG_PRESS_TIME = 300_000_000; // ���� 3 �� (���� 100 MHz ʱ��)
    parameter DEBOUNCE_TIME = 20_000_000;    // ȥ����ʱ 200 ms
    parameter COUNTDOWN_TIME = 500_000_000;  // 5 �뵹��ʱ
    
    //����״̬����
    parameter IDLE = 3'b000;
    parameter MENU = 3'b001;
    parameter CLEAN = 3'b011;
    parameter power_1=3'b100;
    parameter power_2=3'b101;
    parameter power_3=3'b110;
    
    //�������Ѳ���
    parameter MILLION = 100_000_000;
    
    // ʵʱ���ƵĲ���
    wire [42:0] reminder_time;
    wire [29:0] gesture_time;    
    
    //�м��ź�����
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
    
    //��ģ��ʵ��������
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


// �����ź�ȥ��ģ��
module debouncer #(
    parameter DEBOUNCE_TIME = 20_000_000 // ȥ����ʱ (Ĭ�� 200 ms)
)(
    input clk,
    input rst,
    input button_in,
    output reg button_out
);
    reg [24:0] counter;  // ȥ��������
    reg button_sync;     // ͬ����İ����ź�

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

// �����ź�ȥ��ģ��
module debouncer_pulse #(
    parameter DEBOUNCE_TIME = 20_000_000 // ȥ����ʱ (Ĭ�� 200 ms)
)(
    input clk,
    input rst,
    input button_in,
    output reg button_out,
    output wire button_pulse  // �����������
);
    // ʹ�þֲ��ź�ȷ����ͬʵ��֮�以������
    reg [24:0] counter = 0;     // ȥ��������
    reg button_sync = 0;        // ͬ����İ����ź�
    reg button_out_prev = 0;    // ��һ�����״̬

    // ��ȥ���߼�
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            counter <= 0;
            button_sync <= 0;
            button_out <= 0;
        end else begin
            button_sync <= button_in;
            if (button_sync == button_out) begin
                counter <= 0; // ����״̬�ȶ�������������
            end else begin
                counter <= counter + 1; // ����״̬�仯���������ۼ�
                if (counter >= DEBOUNCE_TIME) begin
                    button_out <= button_sync; // ����״̬�ȶ���������
                    counter <= 0;
                end
            end
        end
    end

    // ���������߼�
    always @(posedge clk or negedge rst) begin
        if (!rst)
            button_out_prev <= 0; // ��λʱ����
        else
            button_out_prev <= button_out; // ������һ��״̬
    end

    // ��������������ź�
    assign button_pulse = (button_out && !button_out_prev); // ���������ز�������

endmodule
