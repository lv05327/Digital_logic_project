`timescale 1ns / 1ps

module reference_setting (
    input clk,                  // ʱ���ź�
    input rst,                // ��λ�ź�
    input reminder_enable,
    input gesture_enable,
    input power_status,
    input up_button,
    input bottom_button,
    output reg [31:0] reminder_time, // ���ô����������ѵ�ʹ��ʱ��
    output reg [29:0] gesture_time // �������ƿ��ص���Чʱ��
);

    parameter DEBOUNCE_TIME = 20_000_000;    // ȥ����ʱ 200 ms

    // �洢�����������ѵ�ʹ��ʱ������20Сʱ������0Сʱ
    reg [42:0] max_reminder_time;
    
    // �洢���ƿ�����Чʱ������10�룬����5��
    reg [29:0] max_gesture_time;
    
    reg power_status_prev;
    reg power_status_now;
    
    wire up_stable;
    wire bottom_stable;
    
    wire up_pulse;
    wire bottom_pulse;
    
    // ȥ��ģ��
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
    
    // ������ʼ������
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            power_status_prev <= 0;
            power_status_now <= 0;
        end else begin
            power_status_prev <= power_status;
            power_status_now <= power_status_prev;
        end
    end

    // �ڸ�λʱ��ʼ���Ĵ���
    always @(posedge clk or negedge rst) begin
        if (~rst || (~power_status_prev && power_status_now)) begin
            // ��λʱ�ָ�Ĭ��ֵ
            max_reminder_time <= 32'd72000;  // Ĭ������������Ѵ���ʱ��Ϊ20Сʱ
            max_gesture_time <= 30'd1000000000; // Ĭ�����������Чʱ��Ϊ10��
            reminder_time <= 32'd36000;
            gesture_time <= 30'd500000000;           
        end else if (power_status) begin
            if (reminder_enable) begin
               if (up_pulse) begin
                   if (reminder_time == max_reminder_time) reminder_time <= max_reminder_time;
                   else reminder_time <= reminder_time + 32'd3600; //ÿ�μ�һСʱ                   
               end else if (bottom_pulse) begin
                   if (reminder_time == 32'd0) reminder_time <= 32'd0;
                   else reminder_time <= reminder_time - 32'd3600; //ÿ�μ�һСʱ
               end
            end else if (gesture_enable) begin
                if (up_pulse) begin
                    if (gesture_time == max_gesture_time) gesture_time <= max_gesture_time;
                    else gesture_time <= gesture_time + 30'd100000000; //ÿ�μ�һ��                   
                end else if (bottom_pulse) begin
                    if (gesture_time == 30'd100000000) reminder_time <= 43'd100000000;
                    else gesture_time <= gesture_time - 30'd100000000; //ÿ�μ�һ��
                end
            end 
        end

    end

endmodule

