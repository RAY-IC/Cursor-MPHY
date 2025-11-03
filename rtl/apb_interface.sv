//=============================================================================
// APB Control Interface
// Description: APB slave interface for configuration and status registers
//=============================================================================

module apb_interface (
    input  wire         clk,
    input  wire         rst_n,
    
    // APB Interface
    input  wire         psel,
    input  wire         penable,
    input  wire         pwrite,
    input  wire [11:0]  paddr,      // 4KB address space
    input  wire [31:0]  pwdata,
    output reg  [31:0]  prdata,
    output reg          pready,
    output reg          pslverr,
    
    // Control outputs
    output reg          enable,
    output reg          encrypt_mode,
    output reg          loopback_mode,
    output reg          key_load_via_tuser,
    
    // Status inputs
    input  wire         engine_busy,
    input  wire         engine_error,
    input  wire [31:0]  byte_count,
    input  wire [31:0]  packet_count
);

// Register map
// 0x000: Control Register
//   [0]     - Enable
//   [1]     - Encrypt mode (1=encrypt, 0=decrypt)
//   [2]     - Loopback mode
//   [3]     - Key load via TUSER
//   [31:4]  - Reserved
// 0x004: Status Register (Read-only)
//   [0]     - Engine busy
//   [1]     - Engine error
//   [31:2]  - Reserved
// 0x008: Byte Count Register (Read-only)
// 0x00C: Packet Count Register (Read-only)
// 0x010-0xFFF: Reserved

localparam ADDR_CTRL        = 12'h000;
localparam ADDR_STATUS      = 12'h004;
localparam ADDR_BYTE_COUNT  = 12'h008;
localparam ADDR_PACKET_COUNT = 12'h00C;

// Internal registers
reg [31:0] ctrl_reg;
reg [31:0] status_reg;

// APB state machine
typedef enum logic {
    IDLE,
    ACCESS
} apb_state_t;

apb_state_t apb_state, apb_next_state;

//-----------------------------------------------------------------------------
// APB State Machine
//-----------------------------------------------------------------------------
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        apb_state <= IDLE;
        ctrl_reg <= 0;
        prdata <= 0;
        pready <= 1'b0;
        pslverr <= 1'b0;
        enable <= 1'b0;
        encrypt_mode <= 1'b1;
        loopback_mode <= 1'b0;
        key_load_via_tuser <= 1'b1;
    end else begin
        apb_state <= apb_next_state;
        
        case (apb_state)
            IDLE: begin
                pready <= 1'b0;
                pslverr <= 1'b0;
                if (psel && !penable) begin
                    apb_state <= ACCESS;
                end
            end
            
            ACCESS: begin
                if (psel && penable) begin
                    if (pwrite) begin
                        // Write access
                        case (paddr)
                            ADDR_CTRL: begin
                                ctrl_reg <= pwdata;
                                enable <= pwdata[0];
                                encrypt_mode <= pwdata[1];
                                loopback_mode <= pwdata[2];
                                key_load_via_tuser <= pwdata[3];
                            end
                            default: begin
                                pslverr <= 1'b1;
                            end
                        endcase
                    end else begin
                        // Read access
                        case (paddr)
                            ADDR_CTRL:        prdata <= ctrl_reg;
                            ADDR_STATUS:      prdata <= status_reg;
                            ADDR_BYTE_COUNT:  prdata <= byte_count;
                            ADDR_PACKET_COUNT: prdata <= packet_count;
                            default: begin
                                prdata <= 32'h0;
                                pslverr <= 1'b1;
                            end
                        endcase
                    end
                    pready <= 1'b1;
                    apb_state <= IDLE;
                end
            end
        endcase
        
        // Update status register
        status_reg <= {30'b0, engine_error, engine_busy};
    end
end

always_comb begin
    apb_next_state = apb_state;
    
    case (apb_state)
        IDLE: begin
            if (psel && !penable) begin
                apb_next_state = ACCESS;
            end
        end
        
        ACCESS: begin
            if (psel && penable) begin
                apb_next_state = IDLE;
            end
        end
    endcase
end

endmodule
