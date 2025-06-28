`timescale 1ns / 1ps

module lighting_mode(
    input clk,
    input rst,
    input lighting_button,
    input power_status,
    output reg light
);

    always @(posedge clk or negedge rst) begin
        if (~rst || ~power_status) begin
            light <= 0;
        end else begin
            if (lighting_button) light <= 1;
            else light <= 0;
        end
    end

endmodule
