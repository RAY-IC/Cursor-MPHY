//=============================================================================
// CTR Mode Engine
// Description: Implements NIST SP 800-38A CTR mode for AES256
//              Supports independent IV per packet, counter incrementation
//=============================================================================

module ctr_mode_engine (
    input  wire         clk,
    input  wire         rst_n,
    
    // Control
    input  wire         enable,
    input  wire         encrypt_mode,  // 1=encrypt, 0=decrypt (CTR uses same logic)
    
    // IV and counter management
    input  wire         iv_load,       // Load new IV (start of packet)
    input  wire [127:0] iv_in,         // Initial counter value
    
    // AES core interface
    output reg          aes_valid,
    output reg  [127:0] aes_counter,   // Counter value to encrypt
    input  wire         aes_ready,
    input  wire [127:0] aes_keystream, // Encrypted counter (keystream)
    input  wire         aes_valid_out,
    
    // Data interface (512-bit for high throughput)
    input  wire         data_valid,
    input  wire         data_sof,      // Start of frame
    input  wire         data_eof,      // End of frame
    input  wire [511:0] data_in,       // 512-bit = 4 x 128-bit blocks
    input  wire [5:0]   data_bytes,    // Valid bytes in last transfer (0-63)
    
    output reg          result_valid,
    output reg          result_sof,
    output reg          result_eof,
    output reg  [511:0] result_out,
    output reg  [5:0]   result_bytes
);

// Internal state
reg [127:0] counter [0:3];  // 4 counters for parallel processing
reg [127:0] keystream [0:3];
reg [3:0]   keystream_valid;
reg [127:0] iv_reg;

// State machine
typedef enum logic [2:0] {
    IDLE,
    LOAD_IV,
    REQUEST_KEYSTREAM,
    WAIT_KEYSTREAM,
    XOR_DATA,
    OUTPUT
} ctr_state_t;

ctr_state_t state, next_state;

// Counter for tracking which block we're processing
reg [1:0] block_idx;
reg [1:0] block_idx_next;

// Pipeline registers
reg [511:0] data_pipe;
reg         sof_pipe, eof_pipe;
reg [5:0]   bytes_pipe;

//-----------------------------------------------------------------------------
// Counter increment function (standard 128-bit big-endian increment)
//-----------------------------------------------------------------------------
function automatic [127:0] increment_counter(input [127:0] cnt);
    increment_counter = cnt + 1;
endfunction

//-----------------------------------------------------------------------------
// State machine and processing
//-----------------------------------------------------------------------------
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        block_idx <= 0;
        iv_reg <= 0;
        for (int i = 0; i < 4; i++) begin
            counter[i] <= 0;
            keystream[i] <= 0;
        end
        keystream_valid <= 4'b0;
        aes_valid <= 1'b0;
        aes_counter <= 0;
        result_valid <= 1'b0;
        result_sof <= 1'b0;
        result_eof <= 1'b0;
        result_out <= 0;
        result_bytes <= 0;
        data_pipe <= 0;
        sof_pipe <= 1'b0;
        eof_pipe <= 1'b0;
        bytes_pipe <= 0;
    end else begin
        state <= next_state;
        block_idx <= block_idx_next;
        
        // Pipeline data
        if (data_valid && (state == IDLE || state == OUTPUT)) begin
            data_pipe <= data_in;
            sof_pipe <= data_sof;
            eof_pipe <= data_eof;
            bytes_pipe <= data_bytes;
        end
        
        // IV loading
        if (iv_load && data_sof) begin
            iv_reg <= iv_in;
        end
        
        // Counter management
        if (state == LOAD_IV && data_sof) begin
            counter[0] <= iv_in;
            counter[1] <= increment_counter(iv_in);
            counter[2] <= increment_counter(increment_counter(iv_in));
            counter[3] <= increment_counter(increment_counter(increment_counter(iv_in)));
        end else if (state == OUTPUT && enable) begin
            // Increment counters for next set
            for (int i = 0; i < 4; i++) begin
                counter[i] <= increment_counter(counter[i]);
            end
        end
        
        // AES core interface
        if (next_state == REQUEST_KEYSTREAM) begin
            aes_valid <= 1'b1;
            aes_counter <= counter[block_idx];
        end else if (aes_ready && aes_valid) begin
            aes_valid <= 1'b0;
        end
        
        // Capture keystream
        if (aes_valid_out) begin
            keystream[block_idx] <= aes_keystream;
            keystream_valid[block_idx] <= 1'b1;
        end
        
        // Clear keystream valid flags
        if (next_state == OUTPUT) begin
            keystream_valid <= 4'b0;
        end
        
        // Output results
        if (next_state == OUTPUT) begin
            result_valid <= 1'b1;
            result_sof <= sof_pipe;
            result_eof <= eof_pipe;
            result_bytes <= bytes_pipe;
            
            // XOR with keystream
            result_out[127:0]   <= data_pipe[127:0]   ^ keystream[0];
            result_out[255:128] <= data_pipe[255:128] ^ keystream[1];
            result_out[383:256] <= data_pipe[383:256] ^ keystream[2];
            result_out[511:384] <= data_pipe[511:384] ^ keystream[3];
        end else begin
            result_valid <= 1'b0;
        end
    end
end

always_comb begin
    next_state = state;
    block_idx_next = block_idx;
    
    case (state)
        IDLE: begin
            if (enable && data_valid) begin
                if (data_sof && iv_load) begin
                    next_state = LOAD_IV;
                end else begin
                    next_state = REQUEST_KEYSTREAM;
                    block_idx_next = 0;
                end
            end
        end
        
        LOAD_IV: begin
            next_state = REQUEST_KEYSTREAM;
            block_idx_next = 0;
        end
        
        REQUEST_KEYSTREAM: begin
            if (aes_ready) begin
                next_state = WAIT_KEYSTREAM;
            end
        end
        
        WAIT_KEYSTREAM: begin
            if (keystream_valid[block_idx]) begin
                if (block_idx == 3) begin
                    next_state = XOR_DATA;
                end else begin
                    next_state = REQUEST_KEYSTREAM;
                    block_idx_next = block_idx + 1;
                end
            end
        end
        
        XOR_DATA: begin
            next_state = OUTPUT;
        end
        
        OUTPUT: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule
