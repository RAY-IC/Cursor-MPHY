// CRC Accelerator Top Module
// High-performance CRC acceleration engine with AXI-Stream interface

module crc_accelerator_top (
    input  wire        clk,
    input  wire        rst_n,
    
    // AXI-Stream Slave Interface (Input Data)
    input  wire [255:0] s_axis_tdata,
    input  wire         s_axis_tvalid,
    output reg          s_axis_tready,
    input  wire         s_axis_tlast,
    input  wire [31:0]  s_axis_tkeep,
    
    // AXI-Stream Master Interface (Output CRC Result)
    output reg  [63:0]  m_axis_tdata,
    output reg          m_axis_tvalid,
    input  wire         m_axis_tready,
    output reg          m_axis_tlast,
    
    // Control Interface
    input  wire [1:0]   crc_type,      // 00: CRC32, 01: CRC32C, 10: CRC64
    input  wire [63:0]  crc_init,
    input  wire         crc_enable,
    input  wire         crc_reset
);

    // Internal signals
    wire [255:0] data_to_engine;
    wire         data_valid_to_engine;
    wire         data_ready_from_engine;
    wire         packet_last_to_engine;
    wire [31:0]  data_keep_to_engine;
    
    wire [63:0]  crc_result_from_engine;
    wire         crc_valid_from_engine;
    wire         crc_last_from_engine;
    
    wire         engine_rst_n;
    
    // Reset logic
    assign engine_rst_n = rst_n && !crc_reset;
    
    // AXI-Stream Input Interface
    axi_stream_if u_axi_stream_if (
        .clk(clk),
        .rst_n(engine_rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tkeep(s_axis_tkeep),
        .data_out(data_to_engine),
        .data_valid(data_valid_to_engine),
        .data_ready(data_ready_from_engine),
        .packet_last(packet_last_to_engine),
        .data_keep(data_keep_to_engine)
    );
    
    // CRC Calculation Engine
    crc_engine u_crc_engine (
        .clk(clk),
        .rst_n(engine_rst_n),
        .data_in(data_to_engine),
        .data_valid(data_valid_to_engine),
        .data_ready(data_ready_from_engine),
        .packet_last(packet_last_to_engine),
        .data_keep(data_keep_to_engine),
        .crc_type(crc_type),
        .crc_init(crc_init),
        .crc_enable(crc_enable),
        .crc_result(crc_result_from_engine),
        .crc_valid(crc_valid_from_engine),
        .crc_last(crc_last_from_engine)
    );
    
    // AXI-Stream Output Interface
    always @(posedge clk) begin
        if (!engine_rst_n) begin
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
            m_axis_tdata <= 64'b0;
        end else begin
            if (crc_valid_from_engine && m_axis_tready) begin
                m_axis_tdata <= crc_result_from_engine;
                m_axis_tvalid <= 1'b1;
                m_axis_tlast <= crc_last_from_engine;
            end else if (m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
            end
        end
    end

endmodule
