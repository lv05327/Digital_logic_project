`timescale 1ns / 1ps

module ten_hours_counter(
    input [31:0] reminder_time,
    input wire clk,            // ʱ���ź�
    input wire reset,          // ��λ�ź�
    input wire if_count,       // �Ƿ����
    input wire if_clean,       // �Զ�����
    input wire if_hand_clean,  // �ֶ�����
    output reg time_out,       // ��ʱ����ź�
    output reg [31:0] count    // �����
);
    
    // ��������
    parameter MILLION = 100_000_000;  // 1 ���Ӧ��ʱ��������

    // ��Ƶ������
    reg [31:0] prescaler;

    // ���߼�
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
