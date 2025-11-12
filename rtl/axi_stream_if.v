// AXI-Stream Interface Module
// Handles AXI-Stream protocol handshaking and data buffering

module axi_stream_if (
    input  wire        clk,
    input  wire        rst_n,
    
    // AXI-Stream Slave Interface (Input)
    input  wire [255:0] s_axis_tdata,
    input  wire         s_axis_tvalid,
    output reg          s_axis_tready,
    input  wire         s_axis_tlast,
    input  wire [31:0]  s_axis_tkeep,
    
    // Internal Interface (to CRC Engine)
    output reg  [255:0] data_out,
    output reg          data_valid,
    input  wire         data_ready,
    output reg          packet_last,
    output reg  [31:0]  data_keep
);

    // Simple pass-through with handshaking
    // Assuming CRC engine can always accept data (or has small buffer)
    
    always @(posedge clk) begin
        if (!rst_n) begin
            s_axis_tready <= 1'b1;
            data_valid <= 1'b0;
            packet_last <= 1'b0;
        end else begin
            // Ready when downstream is ready
            s_axis_tready <= data_ready;
            
            // Forward data when valid and ready
            if (s_axis_tvalid && s_axis_tready && data_ready) begin
                data_out <= s_axis_tdata;
                data_valid <= 1'b1;
                packet_last <= s_axis_tlast;
                data_keep <= s_axis_tkeep;
            end else begin
                data_valid <= 1'b0;
            end
        end
    end

endmodule
