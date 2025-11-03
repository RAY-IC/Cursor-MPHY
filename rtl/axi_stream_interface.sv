//=============================================================================
// AXI4-Stream Interface Wrapper
// Description: Wraps data paths with AXI4-Stream protocol
//              Supports 512-bit data width, TUSER for metadata
//=============================================================================

module axi_stream_interface (
    input  wire         clk,
    input  wire         rst_n,
    
    // AXI4-Stream Slave (Input)
    input  wire         s_axis_tvalid,
    output reg          s_axis_tready,
    input  wire [511:0] s_axis_tdata,
    input  wire [63:0]  s_axis_tkeep,     // Byte enables
    input  wire         s_axis_tlast,
    input  wire [255:0] s_axis_tuser_key,  // Key in TUSER (256-bit)
    input  wire [127:0] s_axis_tuser_iv,   // IV in TUSER (128-bit)
    input  wire [1:0]   s_axis_tuser_ctrl, // Control: [0]=SOF, [1]=key_valid
    
    // AXI4-Stream Master (Output)
    output reg          m_axis_tvalid,
    input  wire         m_axis_tready,
    output reg  [511:0] m_axis_tdata,
    output reg  [63:0]  m_axis_tkeep,
    output reg          m_axis_tlast,
    output reg  [127:0] m_axis_tuser_status, // Status info
    
    // Internal interface to engine
    output reg          engine_data_valid,
    output reg          engine_data_sof,
    output reg          engine_data_eof,
    output reg  [511:0] engine_data,
    output reg  [5:0]   engine_data_bytes,
    output reg          engine_key_valid,
    output reg  [255:0] engine_key,
    output reg          engine_iv_load,
    output reg  [127:0] engine_iv,
    
    input  wire         engine_result_valid,
    input  wire         engine_result_sof,
    input  wire         engine_result_eof,
    input  wire [511:0] engine_result,
    input  wire [5:0]   engine_result_bytes
);

// Internal registers
reg sof_seen;
reg eof_seen;

// Extract metadata from TUSER
wire key_in_tuser;
wire iv_valid;

assign key_in_tuser = s_axis_tuser_ctrl[1];
assign iv_valid = s_axis_tuser_ctrl[0];  // SOF flag also indicates IV valid

//-----------------------------------------------------------------------------
// Input path: AXI4-Slave to Engine
//-----------------------------------------------------------------------------
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s_axis_tready <= 1'b0;
        engine_data_valid <= 1'b0;
        engine_data_sof <= 1'b0;
        engine_data_eof <= 1'b0;
        engine_data <= 0;
        engine_data_bytes <= 0;
        engine_key_valid <= 1'b0;
        engine_key <= 0;
        engine_iv_load <= 1'b0;
        engine_iv <= 0;
        sof_seen <= 1'b0;
        eof_seen <= 1'b0;
    end else begin
        // AXI handshaking
        s_axis_tready <= 1'b1;  // Assume engine is always ready (backpressure handled elsewhere)
        
        // Detect SOF/EOF
        if (s_axis_tvalid && s_axis_tready) begin
            if (s_axis_tuser_ctrl[0] && !sof_seen) begin
                engine_data_sof <= 1'b1;
                sof_seen <= 1'b1;
            end else begin
                engine_data_sof <= 1'b0;
            end
            
            if (s_axis_tlast && !eof_seen) begin
                engine_data_eof <= 1'b1;
                eof_seen <= 1'b1;
                sof_seen <= 1'b0;  // Reset for next packet
            end else begin
                engine_data_eof <= 1'b0;
            end
            
            // Data transfer
            engine_data_valid <= s_axis_tvalid;
            engine_data <= s_axis_tdata;
            
            // Calculate valid bytes from tkeep
            engine_data_bytes <= count_valid_bytes(s_axis_tkeep);
            
            // Key from TUSER
            if (key_in_tuser) begin
                engine_key_valid <= 1'b1;
                engine_key <= s_axis_tuser_key;
            end else begin
                engine_key_valid <= 1'b0;
            end
            
            // IV from TUSER
            if (iv_valid) begin
                engine_iv_load <= 1'b1;
                engine_iv <= s_axis_tuser_iv;
            end else begin
                engine_iv_load <= 1'b0;
            end
        end else begin
            engine_data_valid <= 1'b0;
            engine_key_valid <= 1'b0;
            engine_iv_load <= 1'b0;
            engine_data_sof <= 1'b0;
            engine_data_eof <= 1'b0;
        end
        
        if (s_axis_tlast && s_axis_tvalid && s_axis_tready) begin
            eof_seen <= 1'b0;
        end
    end
end

//-----------------------------------------------------------------------------
// Output path: Engine to AXI4-Master
//-----------------------------------------------------------------------------
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tdata <= 0;
        m_axis_tkeep <= 0;
        m_axis_tlast <= 1'b0;
        m_axis_tuser_status <= 0;
    end else begin
        if (engine_result_valid) begin
            m_axis_tvalid <= 1'b1;
            m_axis_tdata <= engine_result;
            m_axis_tkeep <= bytes_to_tkeep(engine_result_bytes);
            m_axis_tlast <= engine_result_eof;
            m_axis_tuser_status <= {120'b0, engine_result_bytes};
        end else if (m_axis_tready && m_axis_tvalid) begin
            m_axis_tvalid <= 1'b0;
        end
    end
end

//-----------------------------------------------------------------------------
// Helper functions
//-----------------------------------------------------------------------------
function automatic [5:0] count_valid_bytes(input [63:0] tkeep);
    integer i;
    count_valid_bytes = 0;
    for (i = 0; i < 64; i++) begin
        if (tkeep[i]) count_valid_bytes = count_valid_bytes + 1;
    end
endfunction

function automatic [63:0] bytes_to_tkeep(input [5:0] bytes);
    integer i;
    bytes_to_tkeep = 64'h0;
    for (i = 0; i < 64 && i < bytes; i++) begin
        bytes_to_tkeep[i] = 1'b1;
    end
endfunction

endmodule
