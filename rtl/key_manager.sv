//=============================================================================
// Key Manager with Key-on-the-fly Support
// Description: Manages AES256 keys, supports dynamic key loading per packet
//              Keys can be provided via TUSER or packet prefix
//=============================================================================

module key_manager (
    input  wire         clk,
    input  wire         rst_n,
    
    // Control
    input  wire         key_load_enable,
    input  wire         key_load_via_tuser,  // 1=via TUSER, 0=via packet prefix
    
    // Key input via TUSER (256-bit)
    input  wire         tuser_key_valid,
    input  wire [255:0] tuser_key,
    
    // Key input via packet prefix
    input  wire         prefix_key_valid,
    input  wire [255:0] prefix_key,
    
    // Key output to AES core
    output reg          key_ready,
    output reg  [255:0] key_out,
    output reg          key_valid,
    
    // Packet tracking
    input  wire         packet_sof,
    input  wire         packet_eof
);

// Internal state
reg [255:0] current_key;
reg [255:0] next_key;
reg         key_pending;
reg         key_valid_reg;

// State machine
typedef enum logic [1:0] {
    IDLE,
    LOADING,
    READY
} key_state_t;

key_state_t state, next_state;

//-----------------------------------------------------------------------------
// Key Management Logic
//-----------------------------------------------------------------------------
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        current_key <= 0;
        next_key <= 0;
        key_pending <= 1'b0;
        key_ready <= 1'b1;
        key_valid <= 1'b0;
        key_valid_reg <= 1'b0;
    end else begin
        state <= next_state;
        
        // Load new key
        if (key_load_enable) begin
            if (key_load_via_tuser && tuser_key_valid) begin
                if (state == IDLE || packet_sof) begin
                    next_key <= tuser_key;
                    key_pending <= 1'b1;
                end
            end else if (!key_load_via_tuser && prefix_key_valid) begin
                if (state == IDLE || packet_sof) begin
                    next_key <= prefix_key;
                    key_pending <= 1'b1;
                end
            end
        end
        
        // Update current key at start of packet or when ready
        if (key_pending && (packet_sof || state == IDLE)) begin
            current_key <= next_key;
            key_valid_reg <= 1'b1;
            key_pending <= 1'b0;
        end
        
        // Output key
        key_out <= current_key;
        key_valid <= key_valid_reg && (state == READY);
        
        // Key ready signal
        key_ready <= (state == READY) && !key_pending;
    end
end

always_comb begin
    next_state = state;
    
    case (state)
        IDLE: begin
            if (key_pending || (key_load_enable && ((key_load_via_tuser && tuser_key_valid) || (!key_load_via_tuser && prefix_key_valid)))) begin
                next_state = LOADING;
            end
        end
        
        LOADING: begin
            if (key_valid_reg) begin
                next_state = READY;
            end
        end
        
        READY: begin
            // Stay ready, can load new key on next packet
            if (key_pending && packet_sof) begin
                next_state = LOADING;
            end
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule
