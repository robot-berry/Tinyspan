`timescale 1ns/1ps

module tb_span_tinyspan_w8a8_bicubic_base_x4_fast_vs_serial;
    localparam integer DATA_W = 24;
    localparam integer ACT_W = 8;
    localparam integer IMG_W = 4;
    localparam integer IMG_H = 4;
    localparam integer FRAME_PIXELS = IMG_W * IMG_H;
    localparam integer OUT_PIXELS = IMG_W * IMG_H * 16;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg s_valid = 1'b0;
    wire fast_s_ready;
    wire serial_s_ready;
    reg [DATA_W-1:0] s_data = {DATA_W{1'b0}};
    reg s_user = 1'b0;
    reg s_last = 1'b0;
    wire fast_valid;
    wire serial_valid;
    reg m_ready = 1'b1;
    wire signed [3*ACT_W-1:0] fast_rgb;
    wire signed [3*ACT_W-1:0] serial_rgb;
    wire fast_user;
    wire fast_last;
    wire serial_user;
    wire serial_last;

    reg signed [3*ACT_W-1:0] fast_out [0:OUT_PIXELS-1];
    reg signed [3*ACT_W-1:0] serial_out [0:OUT_PIXELS-1];
    integer fast_count = 0;
    integer serial_count = 0;
    integer i;
    integer mismatch_count;
    reg fast_user_seen = 1'b0;
    reg serial_user_seen = 1'b0;

    always #5 clk = ~clk;

    span_tinyspan_w8a8_bicubic_base_x4_streamed #(
        .DATA_W(DATA_W),
        .ACT_W(ACT_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H)
    ) u_fast (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(fast_s_ready),
        .s_data(s_data),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(fast_valid),
        .m_ready(m_ready),
        .m_rgb(fast_rgb),
        .m_user(fast_user),
        .m_last(fast_last)
    );

    span_tinyspan_w8a8_bicubic_base_x4_streamed_serial #(
        .DATA_W(DATA_W),
        .ACT_W(ACT_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H)
    ) u_serial (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(serial_s_ready),
        .s_data(s_data),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(serial_valid),
        .m_ready(m_ready),
        .m_rgb(serial_rgb),
        .m_user(serial_user),
        .m_last(serial_last)
    );

    always @(posedge clk) begin
        if (rst) begin
            fast_count <= 0;
            serial_count <= 0;
            fast_user_seen <= 1'b0;
            serial_user_seen <= 1'b0;
        end else begin
            if (fast_valid && m_ready) begin
                if (fast_count < OUT_PIXELS)
                    fast_out[fast_count] <= fast_rgb;
                if (fast_user)
                    fast_user_seen <= 1'b1;
                fast_count <= fast_count + 1;
            end
            if (serial_valid && m_ready) begin
                if (serial_count < OUT_PIXELS)
                    serial_out[serial_count] <= serial_rgb;
                if (serial_user)
                    serial_user_seen <= 1'b1;
                serial_count <= serial_count + 1;
            end
        end
    end

    task automatic drive_pixel;
        input integer idx;
        reg [7:0] r;
        reg [7:0] g;
        reg [7:0] b;
        begin
            r = (idx * 17 + 3) & 8'hff;
            g = (idx * 29 + 7) & 8'hff;
            b = (idx * 43 + 11) & 8'hff;
            s_data <= {r, g, b};
            s_user <= (idx == 0);
            s_last <= ((idx % IMG_W) == (IMG_W - 1));
            s_valid <= 1'b1;
            wait (fast_s_ready && serial_s_ready);
            @(posedge clk);
        end
    endtask

    initial begin
        repeat (8) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);

        for (i = 0; i < FRAME_PIXELS; i = i + 1)
            drive_pixel(i);

        s_valid <= 1'b0;
        s_user <= 1'b0;
        s_last <= 1'b0;

        fork
            begin
                wait ((fast_count >= OUT_PIXELS) && (serial_count >= OUT_PIXELS));
                #50;
                mismatch_count = 0;
                for (i = 0; i < OUT_PIXELS; i = i + 1) begin
                    if (fast_out[i] !== serial_out[i]) begin
                        if (mismatch_count < 16) begin
                            $display("MISMATCH idx=%0d fast=%0d/%0d/%0d serial=%0d/%0d/%0d",
                                i,
                                $signed(fast_out[i][0*ACT_W +: ACT_W]),
                                $signed(fast_out[i][1*ACT_W +: ACT_W]),
                                $signed(fast_out[i][2*ACT_W +: ACT_W]),
                                $signed(serial_out[i][0*ACT_W +: ACT_W]),
                                $signed(serial_out[i][1*ACT_W +: ACT_W]),
                                $signed(serial_out[i][2*ACT_W +: ACT_W]));
                        end
                        mismatch_count = mismatch_count + 1;
                    end
                end

                if (fast_count != OUT_PIXELS)
                    $fatal(1, "FAST_COUNT_MISMATCH got=%0d expected=%0d", fast_count, OUT_PIXELS);
                if (serial_count != OUT_PIXELS)
                    $fatal(1, "SERIAL_COUNT_MISMATCH got=%0d expected=%0d", serial_count, OUT_PIXELS);
                if (mismatch_count != 0)
                    $fatal(1, "FAST_SERIAL_MISMATCH count=%0d", mismatch_count);
                if (!fast_user_seen || !serial_user_seen)
                    $fatal(1, "Missing first-pixel user marker");
                $display("PASS tinyspan_w8a8_fast_base_equiv outputs=%0d", OUT_PIXELS);
                $finish;
            end
            begin
                #200000;
                $fatal(1, "TIMEOUT fast_count=%0d serial_count=%0d expected=%0d", fast_count, serial_count, OUT_PIXELS);
            end
        join_any
    end

    wire unused_last = fast_last ^ serial_last;
endmodule
