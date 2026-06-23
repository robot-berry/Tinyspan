`timescale 1ns/1ps

module tb_sr_stream_dynamic_cropper;
    localparam int DATA_W = 24;
    localparam int IN_W = 8;
    localparam int IN_H = 6;
    localparam int COORD_W = 16;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic start = 1'b0;
    logic [COORD_W-1:0] valid_w = 16'd5;
    logic [COORD_W-1:0] valid_h = 16'd4;
    logic s_valid = 1'b0;
    wire s_ready;
    logic [DATA_W-1:0] s_data = '0;
    logic s_user = 1'b0;
    logic s_last = 1'b0;
    wire m_valid;
    logic m_ready = 1'b1;
    wire [DATA_W-1:0] m_data;
    wire m_user;
    wire m_last;
    wire busy;
    wire done;
    wire error;

    int in_idx;
    int out_count;
    int ready_tick;

    always #5 clk = ~clk;

    sr_stream_dynamic_cropper #(
        .DATA_W(DATA_W),
        .IN_W(IN_W),
        .IN_H(IN_H),
        .COORD_W(COORD_W)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .valid_w_i(valid_w),
        .valid_h_i(valid_h),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_data(m_data),
        .m_user(m_user),
        .m_last(m_last),
        .busy(busy),
        .done(done),
        .error(error)
    );

    function automatic [DATA_W-1:0] pix(input int idx);
        pix = {8'(idx), 8'(idx + 1), 8'(idx + 2)};
    endfunction

    function automatic [DATA_W-1:0] expected(input int out_idx);
        int x;
        int y;
        begin
            x = out_idx % valid_w;
            y = out_idx / valid_w;
            expected = pix(y * IN_W + x);
        end
    endfunction

    initial begin
        repeat (4) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;

        for (in_idx = 0; in_idx < IN_W * IN_H; in_idx++) begin
            s_valid <= 1'b1;
            s_data <= pix(in_idx);
            s_user <= (in_idx == 0);
            s_last <= ((in_idx % IN_W) == (IN_W - 1));
            do @(posedge clk); while (!s_ready);
        end
        s_valid <= 1'b0;
        s_user <= 1'b0;
        s_last <= 1'b0;

        wait(done);
        @(posedge clk);
        if (error)
            $fatal(1, "unexpected cropper error");
        if (out_count != valid_w * valid_h)
            $fatal(1, "expected %0d outputs, got %0d", valid_w * valid_h, out_count);
        $display("PASS sr_stream_dynamic_cropper outputs=%0d", out_count);
        $finish;
    end

    always @(posedge clk) begin
        if (rst) begin
            ready_tick <= 0;
            m_ready <= 1'b1;
        end else begin
            ready_tick <= ready_tick + 1;
            m_ready <= (ready_tick % 5) != 3;
        end
    end

    always @(posedge clk) begin
        if (!rst && m_valid && m_ready) begin
            if (m_data !== expected(out_count)) begin
                $fatal(1, "data mismatch idx=%0d got=%06x exp=%06x",
                       out_count, m_data, expected(out_count));
            end
            if (m_user !== (out_count == 0)) begin
                $fatal(1, "user mismatch idx=%0d got=%0d", out_count, m_user);
            end
            if (m_last !== ((out_count % valid_w) == (valid_w - 1))) begin
                $fatal(1, "last mismatch idx=%0d got=%0d", out_count, m_last);
            end
            out_count++;
        end
    end
endmodule
