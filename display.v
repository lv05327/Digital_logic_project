`timescale 1ns / 1ps

// ����ˢ��
module display(
    input clk,           // ϵͳʱ�� (100 MHz)
    input rst,           // ��λ�ź�
    input power_status,  // ��Դ״̬
    input up_button,
    input bottom_button,
    input left_button,
    input right_button,
    input current_time_setting,      //��ǰʱ������ģʽ
    input search_use,
    input search_on,
    input search_reminder,
    input [42:0] reminder_time,
    input [29:0] gesture_time,
    input [31:0] count,
    input start_count,
    input start_count_idle,
    input start_clean,
    output reg [7:0] seg_out_left,   // �������ܶ�ѡ�ź�
    output reg [7:0] seg_out_right,  // �ұ�����ܶ�ѡ�ź�
    output reg [3:0] seg_en_left,    // ��������Ƭѡ�ź�
    output reg [3:0] seg_en_right,    // �ұ������Ƭѡ�ź�
    output reg [5:0] led1
);
    
    //�ۼƹ���ʱ��
    wire [4:0] work_hours;
    wire [5:0] work_minutes;
    wire [5:0] work_seconds;
    
    assign work_hours = count / 3600;
    assign work_minutes = (count % 3600) / 60;
    assign work_seconds = (count % 3600) % 60;

    // ��������
    parameter DEBOUNCE_TIME = 20_000_000;    // ȥ����ʱ 200 ms
    // ʱ�ӷ�Ƶ����
    parameter CLOCK_FREQ = 100_000_000; // 100 MHz
    parameter ONE_SECOND = CLOCK_FREQ;  // 1 ���Ӧ��ʱ��������
    parameter REFRESH_FREQ = 500;     // �����ˢ��Ƶ�� 500Hz
    parameter REFRESH_DIV = CLOCK_FREQ / REFRESH_FREQ;
    
    //��������ʱ��
    wire [4:0] qrt_hours;
    wire [5:0] qrt_minutes;
    wire [5:0] qrt_seconds;
    
    assign qrt_seconds = (reminder_time % 3600) % 60;
    assign qrt_minutes = (reminder_time % 3600) / 60;
    assign qrt_hours = reminder_time / 3600;
    
    //���ƿ���ʱ��
    wire [4:0] qgt_hours;
    wire [5:0] qgt_minutes;    
    wire [5:0] qgt_seconds;
    
    assign qgt_seconds = gesture_time / 100000000;
    assign qgt_minutes = 0;
    assign qgt_hours = 0;
    
    //����ʱ
    reg [4:0] cd_hours;
    reg [5:0] cd_minutes;
    reg [5:0] cd_seconds;
   
    //������İ�ť�ź�
    wire up_stable;
    wire bottom_stable;
    wire left_stable;
    wire right_stable;
    
    //���尴ť�ź�
    wire up_pulse;
    wire bottom_pulse;
    wire left_pulse;
    wire right_pulse;
    
    //״̬����
    reg [2:0] time_select;              //000�����λ��001����ʮλ��010���ָ�λ��011����ʮλ��100��ʱ��λ��101��ʱʮλ

    // ��Ƶ�ź�
    reg [26:0] clk_counter = 0;         // 1Hz ��Ƶ������
    reg one_hz_enable = 0;              // 1Hz ʹ���ź�
    reg [15:0] refresh_counter = 0;     // �����ˢ�·�Ƶ������
    wire refresh_clk = refresh_counter[14]; // 500Hz ˢ��ʱ��

    // ʱ�������
    reg [5:0] seconds = 0;
    reg [5:0] minutes = 0;
    reg [4:0] hours = 0;

    // ��ʾѡ��
    reg [2:0] digit_select = 0;         // ��ǰѡ��������
    reg blink;                          // ð����˸�ź�

    // ͬ����λ�ź�
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
            
            if (one_hz_enable) begin // ��Դ����ʱ��������ģʽ�Ҵ���1Hzʱ����ʱ��
                if (cd_seconds == 0) begin
                    // ����Ϊ 0 ʱ���ȼ�����
                    if (cd_minutes > 0) begin
                        cd_seconds <= 59;  // ��������Ϊ59
                        cd_minutes <= cd_minutes - 1;  // ���ӵݼ�
                    end else begin
                        // ����Ϊ 0 ʱ�����Сʱ
                        if (cd_hours > 0) begin
                            cd_seconds <= 59;  // ��������Ϊ 59
                            cd_hours <= cd_hours - 1;  // Сʱ�ݼ�
                        end
                    end
                end else begin
                    // �����ݼ�
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


    // 1Hz ��Ƶ����
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

    // ð����˸�ź�
    always @(posedge clk or negedge rst_sync) begin
        if (~rst_sync)
            blink <= 0;
        else if (one_hz_enable)
            blink <= ~blink;
    end

    // ʱ������߼�
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
                3'b000: begin // ���λ
                    if (up_pulse) seconds <= (seconds == 59) ? 0 : (seconds + 1);
                    else if (bottom_pulse) seconds <= (seconds == 0) ? 59 : (seconds - 1);
                end
                3'b001: begin // ��ʮλ
                    if (up_pulse) seconds <= (seconds / 10 == 5) ? (seconds - 50) : (seconds + 10);
                    else if (bottom_pulse) seconds <= (seconds / 10 == 0) ? (seconds + 50) : (seconds - 10);
                end
                3'b010: begin // �ָ�λ
                    if (up_pulse) minutes <= (minutes == 59) ? 0 : (minutes + 1);
                    else if (bottom_pulse) minutes <= (minutes == 0) ? 59 : (minutes - 1);
                end
                3'b011: begin // ��ʮλ
                    if (up_pulse) minutes <= (minutes / 10 == 5) ? (minutes - 50) : (minutes + 10);
                    else if (bottom_pulse) minutes <= (minutes / 10 == 0) ? (minutes + 50) : (minutes - 10);
                end
                3'b100: begin // ʱ��λ
                    if (up_pulse) hours <= (hours == 23) ? 0 : (hours + 1);
                    else if (bottom_pulse) hours <= (hours == 0) ? 23 : (hours - 1);
                end
                3'b101: begin // ʱʮλ
                    if (up_pulse) hours <= (hours / 10 == 2) ? (hours - 20) : (hours + 10);
                    else if (bottom_pulse) hours <= (hours / 10 == 0) ? (hours + 20) : (hours - 10);
                end
            endcase
        end else if (one_hz_enable) begin // ��Դ����ʱ��������ģʽ�Ҵ���1Hzʱ����ʱ��
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

    // �����ˢ�·�Ƶ��
    always @(posedge clk or negedge rst_sync) begin
        if (~rst_sync)
            refresh_counter <= 0;
        else
            refresh_counter <= refresh_counter + 1;
    end

    // �������ʾ�߼�
    always @(posedge refresh_clk or negedge rst_sync) begin
        if (~rst_sync) begin
            digit_select <= 0;
            seg_en_left <= 4'b0000;
            seg_en_right <= 4'b0000;
        end else begin
            digit_select <= digit_select + 1; // ѭ��ѡ�������
            if (search_use) begin
                case (digit_select)            
                    3'b000: begin
                        seg_out_left <= 8'b0000_0000; // ���λ
                        seg_en_left <= 4'b0000;
                        seg_out_right <= digit_to_seg(qgt_seconds % 10);
                        seg_en_right <= 4'b0001;
                    end
                    3'b001: begin
                        seg_out_left <= 8'b0000_0000; // ��ʮλ
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
                        seg_out_left <= 8'b0000_0000;  // �ָ�λ
                        seg_en_left <= 4'b0000;
                        seg_out_right <= 8'b0000_0000;
                        seg_en_right <= 4'b0000;
                    end
                    3'b100: begin
                        seg_out_right <= 8'b0000_0000; //��ʮλ
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
                        seg_out_right <= 8'b0000_0000; // ʱ��λ
                        seg_en_right <= 4'b0000;
                        seg_out_left <= 8'b0000_0000;
                        seg_en_left <= 4'b0000;
                    end
                   3'b111: begin
                        seg_out_right <= 8'b0000_0000; // ʱʮλ
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
                    seg_out_left <= 8'b0000_0000; // ���λ
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(qrt_seconds % 10);
                    seg_en_right <= 4'b0001;
                end
                3'b001: begin
                    seg_out_left <= 8'b0000_0000; // ��ʮλ
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(qrt_seconds / 10);
                    seg_en_right <= 4'b0010;
                end
                3'b010: begin
                    seg_out_left <= 8'b0000_0000; // ��������
                    seg_en_left <= 4'b0000;
                    seg_out_right <= (blink ? 8'b0000_1100 : 8'b0000_0000); // ð����˸
                    seg_en_right <= 4'b0100;
                end
                3'b011: begin
                    seg_out_left <= 8'b0000_0000;  // �ָ�λ
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(qrt_minutes % 10);
                    seg_en_right <= 4'b1000;
                end
                3'b100: begin
                    seg_out_right <= 8'b0000_0000; //��ʮλ
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(qrt_minutes / 10);
                    seg_en_left <= 4'b0001;
                end
                3'b101: begin
                    seg_out_right <= 8'b0000_0000;
                    seg_en_right <= 4'b0000;
                    seg_out_left <= (blink ? 8'b0000_1100 : 8'b0000_0000); // ð����˸
                    seg_en_left <= 4'b0010;
                end
                3'b110: begin
                    seg_out_right <= 8'b0000_0000; // ʱ��λ
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(qrt_hours % 10);
                    seg_en_left <= 4'b0100;
                end
                3'b111: begin
                    seg_out_right <= 8'b0000_0000; // ʱʮλ
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
                    seg_out_left <= 8'b0000_0000; // ���λ
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(work_seconds % 10);
                    seg_en_right <= 4'b0001;
                end
                3'b001: begin
                    seg_out_left <= 8'b0000_0000; // ��ʮλ
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(work_seconds / 10);
                    seg_en_right <= 4'b0010;
                end
                3'b010: begin
                    seg_out_left <= 8'b0000_0000; // ��������
                    seg_en_left <= 4'b0000;
                    seg_out_right <= (blink ? 8'b0000_1100 : 8'b0000_0000); // ð����˸
                    seg_en_right <= 4'b0100;
                end
                3'b011: begin
                    seg_out_left <= 8'b0000_0000;  // �ָ�λ
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(work_minutes % 10);
                    seg_en_right <= 4'b1000;
                end
                3'b100: begin
                    seg_out_right <= 8'b0000_0000; //��ʮλ
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(work_minutes / 10);
                    seg_en_left <= 4'b0001;
                end
                3'b101: begin
                    seg_out_right <= 8'b0000_0000;
                    seg_en_right <= 4'b0000;
                    seg_out_left <= (blink ? 8'b0000_1100 : 8'b0000_0000); // ð����˸
                    seg_en_left <= 4'b0010;
                end
                3'b110: begin
                    seg_out_right <= 8'b0000_0000; // ʱ��λ
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(work_hours % 10);
                    seg_en_left <= 4'b0100;
                end
                3'b111: begin
                    seg_out_right <= 8'b0000_0000; // ʱʮλ
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
                    seg_out_left <= 8'b0000_0000; // ���λ
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(cd_seconds % 10);
                    seg_en_right <= 4'b0001;
                end
                3'b001: begin
                    seg_out_left <= 8'b0000_0000; // ��ʮλ
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(cd_seconds / 10);
                    seg_en_right <= 4'b0010;
                end
                3'b010: begin
                    seg_out_left <= 8'b0000_0000; // ��������
                    seg_en_left <= 4'b0000;
                    seg_out_right <= (blink ? 8'b0000_1100 : 8'b0000_0000); // ð����˸
                    seg_en_right <= 4'b0100;
                end
                3'b011: begin
                    seg_out_left <= 8'b0000_0000;  // �ָ�λ
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(cd_minutes % 10);
                    seg_en_right <= 4'b1000;
                end
                3'b100: begin
                    seg_out_right <= 8'b0000_0000; //��ʮλ
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(cd_minutes / 10);
                    seg_en_left <= 4'b0001;
                end
                3'b101: begin
                    seg_out_right <= 8'b0000_0000;
                    seg_en_right <= 4'b0000;
                    seg_out_left <= (blink ? 8'b0000_1100 : 8'b0000_0000); // ð����˸
                    seg_en_left <= 4'b0010;
                end
                3'b110: begin
                    seg_out_right <= 8'b0000_0000; // ʱ��λ
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(cd_hours % 10);
                    seg_en_left <= 4'b0100;
                end
                3'b111: begin
                    seg_out_right <= 8'b0000_0000; // ʱʮλ
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
                    seg_out_left <= 8'b0000_0000; // ���λ
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(seconds % 10);
                    seg_en_right <= 4'b0001;
                end
                3'b001: begin
                    seg_out_left <= 8'b0000_0000; // ��ʮλ
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(seconds / 10);
                    seg_en_right <= 4'b0010;
                end
                3'b010: begin
                    seg_out_left <= 8'b0000_0000; // ��������
                    seg_en_left <= 4'b0000;
                    seg_out_right <= (blink ? 8'b0000_1100 : 8'b0000_0000); // ð����˸
                    seg_en_right <= 4'b0100;
                end
                3'b011: begin
                    seg_out_left <= 8'b0000_0000;  // �ָ�λ
                    seg_en_left <= 4'b0000;
                    seg_out_right <= digit_to_seg(minutes % 10);
                    seg_en_right <= 4'b1000;
                end
                3'b100: begin
                    seg_out_right <= 8'b0000_0000; //��ʮλ
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(minutes / 10);
                    seg_en_left <= 4'b0001;
                end
                3'b101: begin
                    seg_out_right <= 8'b0000_0000;
                    seg_en_right <= 4'b0000;
                    seg_out_left <= (blink ? 8'b0000_1100 : 8'b0000_0000); // ð����˸
                    seg_en_left <= 4'b0010;
                end
                3'b110: begin
                    seg_out_right <= 8'b0000_0000; // ʱ��λ
                    seg_en_right <= 4'b0000;
                    seg_out_left <= digit_to_seg(hours % 10);
                    seg_en_left <= 4'b0100;
                end
                3'b111: begin
                    seg_out_right <= 8'b0000_0000; // ʱʮλ
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

    // ���ֵ���ѡ�źŵ�ת������
    function [7:0] digit_to_seg;
        input [3:0] digit;
        case (digit)
            4'd0: digit_to_seg = 8'b1111_1100; // ��ʾ 0
            4'd1: digit_to_seg = 8'b0110_0000; // ��ʾ 1
            4'd2: digit_to_seg = 8'b1101_1010; // ��ʾ 2
            4'd3: digit_to_seg = 8'b1111_0010; // ��ʾ 3
            4'd4: digit_to_seg = 8'b0110_0110; // ��ʾ 4
            4'd5: digit_to_seg = 8'b1011_0110; // ��ʾ 5
            4'd6: digit_to_seg = 8'b1011_1110; // ��ʾ 6
            4'd7: digit_to_seg = 8'b1110_0000; // ��ʾ 7
            4'd8: digit_to_seg = 8'b1111_1110; // ��ʾ 8
            4'd9: digit_to_seg = 8'b1111_0110; // ��ʾ 9
            default: digit_to_seg = 8'b0000_0000; // Ĭ�Ϲر�
        endcase
    endfunction
    
    // ȥ��ģ�� (ʹ�� debouncer_pulse)
     debouncer_pulse #(.DEBOUNCE_TIME(DEBOUNCE_TIME)) dp_up (
         .clk(clk),
         .rst(rst_sync),
         .button_in(up_button),
         .button_out(up_stable),     // �ȶ��������
         .button_pulse(up_pulse)    // ��������������
     );
     
     debouncer_pulse #(.DEBOUNCE_TIME(DEBOUNCE_TIME)) dp_bottom (
         .clk(clk),
         .rst(rst_sync),
         .button_in(bottom_button),
         .button_out(bottom_stable),  // �ȶ��������
         .button_pulse(bottom_pulse)  // ��������������
     );
     
     debouncer_pulse #(.DEBOUNCE_TIME(DEBOUNCE_TIME)) dp_left (
         .clk(clk),
         .rst(rst_sync),
         .button_in(left_button),
         .button_out(left_stable),   // �ȶ��������
         .button_pulse(left_pulse)   // ��������������
     );
     
     debouncer_pulse #(.DEBOUNCE_TIME(DEBOUNCE_TIME)) dp_right (
         .clk(clk),
         .rst(rst_sync),
         .button_in(right_button),
         .button_out(right_stable),  // �ȶ��������
         .button_pulse(right_pulse)  // ��������������
     );

endmodule


