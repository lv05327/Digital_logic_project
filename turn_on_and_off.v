`timescale 1ns / 1ps

module turn_on_and_off(
    input clk,
    input rst,
    input power_button,  // ���ػ�����
    input left_button,
    input right_button,
    input [29:0] gesture_time,
    output reg power_status, // ���ػ�״̬ (1: ����, 0: �ػ�)
    output [7:0] selection
);
    parameter LONG_PRESS_TIME = 300_000_000; // ���� 3 ��
    parameter DEBOUNCE_TIME = 20_000_000;    // ȥ����ʱ 200 ms

    // �ڲ��ź�
    wire button_stable;     // ȥ����İ����ź�
    wire left_stable;       // ȥ���������ź�
    wire right_stable;      // ȥ������Ҽ��ź�
    reg [28:0] counter;     // ����������
    reg [28:0] countdown;   // ����ʱ������
    reg countdown_active;   // ����ʱ�����־
    reg is_long_press;      // ������־
    reg button_prev;        // ��һ�ΰ���״̬
    reg left_prev, right_prev;
    
    

    // ȥ��ģ��
    debouncer #(.DEBOUNCE_TIME(DEBOUNCE_TIME)) db_power (
        .clk(clk),
        .rst(rst),
        .button_in(power_button),
        .button_out(button_stable)
    );

    debouncer #(.DEBOUNCE_TIME(DEBOUNCE_TIME)) db_left (
        .clk(clk),
        .rst(rst),
        .button_in(left_button),
        .button_out(left_stable)
    );

    debouncer #(.DEBOUNCE_TIME(DEBOUNCE_TIME)) db_right (
        .clk(clk),
        .rst(rst),
        .button_in(right_button),
        .button_out(right_stable)
    );

    // ���߼�
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            power_status <= 0; // ��ʼ״̬Ϊ�ػ�
            counter <= 0;
            is_long_press <= 0;
            countdown <= 0;
            countdown_active <= 0;
            button_prev <= 0;
            left_prev <= 0;
            right_prev <= 0;
        end else begin
            // �̰�/�����߼�
            if (button_stable) begin
                if (counter < LONG_PRESS_TIME) begin
                    counter <= counter + 1; // ��������
                end else begin
                    is_long_press <= 1; // ���Ϊ����
                end
            end else begin
                if (button_prev && !is_long_press) begin
                    power_status <= 1'b1; // �̰�����
                end else if (is_long_press) begin
                    power_status <= 1'b0; // �����ػ�
                end
                counter <= 0;
                is_long_press <= 0;
            end

            // �����߼�
            if (!power_status) begin // �ػ�״̬
                if (left_stable && !left_prev) begin
                    countdown_active <= 1;
                    countdown <= 0;
                end
                if (countdown_active && right_stable && !right_prev) begin
                    power_status <= 1; // ��� + �Ҽ� ����
                    countdown_active <= 0;
                    countdown <= 0;
                end
            end else begin // ����״̬
                if (right_stable && !right_prev) begin
                    countdown_active <= 1;
                    countdown <= 0;
                end
                if (countdown_active && left_stable && !left_prev) begin
                    power_status <= 0; // �Ҽ� + ��� �ػ�
                    countdown_active <= 0;
                    countdown <= 0;
                end
            end

            // ����ʱ�߼�
            if (countdown_active) begin
                if (countdown < gesture_time) begin
                    countdown <= countdown + 1;
                end else begin
                    countdown_active <= 0; // ����ʱ����
                    countdown <= 0;
                end
            end

            // ���°���״̬
            button_prev <= button_stable;
            left_prev <= left_stable;
            right_prev <= right_stable;
        end
    end
    
endmodule



