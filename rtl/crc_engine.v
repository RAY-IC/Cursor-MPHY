// CRC Calculation Engine
// Supports CRC32, CRC32C, and CRC64 with 256-bit data width
// Implements parallel processing for high throughput

module crc_engine (
    input  wire        clk,
    input  wire        rst_n,
    
    // Data Interface
    input  wire [255:0] data_in,
    input  wire         data_valid,
    output reg          data_ready,
    input  wire         packet_last,
    input  wire [31:0]  data_keep,
    
    // Control Interface
    input  wire [1:0]   crc_type,      // 00: CRC32, 01: CRC32C, 10: CRC64
    input  wire [63:0]  crc_init,
    input  wire         crc_enable,
    
    // Result Interface
    output reg  [63:0]  crc_result,
    output reg          crc_valid,
    output reg          crc_last
);

    // Internal signals
    wire [31:0] crc32_result;
    wire [31:0] crc32c_result;
    wire [63:0] crc64_result;
    
    wire crc32_valid;
    wire crc32c_valid;
    wire crc64_valid;
    
    // Pipeline registers
    reg [255:0] data_pipe [0:2];
    reg [1:0]   crc_type_pipe [0:2];
    reg         packet_last_pipe [0:2];
    reg [31:0]  crc_init_reg;
    reg [31:0]  crc32_accum;
    reg [31:0]  crc32c_accum;
    reg [63:0]  crc64_accum;
    reg         crc_enable_pipe;
    
    integer i;
    
    // Pipeline stage 1: Data input and splitting
    wire [31:0] data_chunks_32 [0:7];
    wire [63:0] data_chunks_64 [0:3];
    
    // Split 256-bit data into chunks
    genvar j;
    generate
        for (j = 0; j < 8; j = j + 1) begin : gen_chunks_32
            assign data_chunks_32[j] = data_in[(j+1)*32-1:j*32];
        end
        for (j = 0; j < 4; j = j + 1) begin : gen_chunks_64
            assign data_chunks_64[j] = data_in[(j+1)*64-1:j*64];
        end
    endgenerate
    
    // CRC32 parallel unit for 256-bit data
    wire [31:0] crc32_result;
    wire        crc32_valid;
    
    // CRC32 unit: uses crc32_accum which is initialized to crc_init on first use
    crc32_parallel_256 u_crc32 (
        .clk(clk),
        .rst_n(rst_n),
        .enable(data_valid && (crc_type == 2'b00) && crc_enable),
        .data_in(data_in),
        .crc_init(crc32_accum),  // Will be crc_init[31:0] on first packet, then accumulated value
        .crc_out(crc32_result),
        .crc_valid(crc32_valid)
    );
    
    // CRC32C parallel unit for 256-bit data
    wire [31:0] crc32c_result;
    wire        crc32c_valid;
    
    crc32c_parallel_256 u_crc32c (
        .clk(clk),
        .rst_n(rst_n),
        .enable(data_valid && (crc_type == 2'b01) && crc_enable),
        .data_in(data_in),
        .crc_init(crc32c_accum),
        .crc_out(crc32c_result),
        .crc_valid(crc32c_valid)
    );
    
    // CRC64 parallel unit for 256-bit data
    wire [63:0] crc64_result;
    wire        crc64_valid;
    
    crc64_parallel_256 u_crc64 (
        .clk(clk),
        .rst_n(rst_n),
        .enable(data_valid && (crc_type == 2'b10) && crc_enable),
        .data_in(data_in),
        .crc_init(crc64_accum),
        .crc_out(crc64_result),
        .crc_valid(crc64_valid)
    );
    
    // Pipeline stage 2: CRC result combination
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < 3; i = i + 1) begin
                data_pipe[i] <= 256'b0;
                crc_type_pipe[i] <= 2'b0;
                packet_last_pipe[i] <= 1'b0;
            end
            crc_init_reg <= 32'b0;
            // Initialize accumulators with initial CRC values
            crc32_accum <= crc_init[31:0];
            crc32c_accum <= crc_init[31:0];
            crc64_accum <= crc_init;
            data_ready <= 1'b1;
            crc_valid <= 1'b0;
            crc_last <= 1'b0;
            crc_enable_pipe <= 1'b0;
        end else begin
            // Pipeline stage 1: Input data
            if (data_valid && data_ready) begin
                data_pipe[0] <= data_in;
                crc_type_pipe[0] <= crc_type;
                packet_last_pipe[0] <= packet_last;
                crc_init_reg <= crc_init[31:0];
                crc_enable_pipe <= crc_enable;
            end
            
            // Update CRC accumulator when CRC unit outputs valid result
            // CRC units have 1-cycle latency, so update on valid signal
            if (crc_enable && crc32_valid && (crc_type_pipe[0] == 2'b00)) begin
                if (packet_last_pipe[0]) begin
                    // Reset for next packet - use crc_init for next packet
                    crc32_accum <= crc_init[31:0];
                end else begin
                    // Update accumulator with new CRC result from CRC unit's internal register
                    // Note: crc32_result is already the accumulated value from the CRC unit
                    crc32_accum <= crc32_result;
                end
            end
            
            if (crc_enable && crc32c_valid && (crc_type_pipe[0] == 2'b01)) begin
                if (packet_last_pipe[0]) begin
                    crc32c_accum <= crc_init[31:0];
                end else begin
                    crc32c_accum <= crc32c_result;
                end
            end
            
            if (crc_enable && crc64_valid && (crc_type_pipe[0] == 2'b10)) begin
                if (packet_last_pipe[0]) begin
                    crc64_accum <= crc_init;
                end else begin
                    crc64_accum <= crc64_result;
                end
            end
            
            // Pipeline stage 2: Shift pipeline
            data_pipe[1] <= data_pipe[0];
            crc_type_pipe[1] <= crc_type_pipe[0];
            packet_last_pipe[1] <= packet_last_pipe[0];
            
            data_pipe[2] <= data_pipe[1];
            crc_type_pipe[2] <= crc_type_pipe[1];
            packet_last_pipe[2] <= packet_last_pipe[1];
            
            // Pipeline stage 3: Output result
            if (packet_last_pipe[2] && crc_enable_pipe) begin
                case (crc_type_pipe[2])
                    2'b00: begin
                        crc_result[31:0] <= ~crc32_accum;  // Final inversion for CRC32
                        crc_result[63:32] <= 32'b0;
                        crc_valid <= 1'b1;
                    end
                    2'b01: begin
                        crc_result[31:0] <= ~crc32c_accum;  // Final inversion for CRC32C
                        crc_result[63:32] <= 32'b0;
                        crc_valid <= 1'b1;
                    end
                    2'b10: begin
                        crc_result <= ~crc64_accum;  // Final inversion for CRC64
                        crc_valid <= 1'b1;
                    end
                    default: begin
                        crc_result <= 64'b0;
                        crc_valid <= 1'b0;
                    end
                endcase
                crc_last <= 1'b1;
                
                // Reset accumulators for next packet (already done above when packet_last detected)
            end else begin
                crc_valid <= 1'b0;
                crc_last <= 1'b0;
            end
        end
    end

endmodule
