//=============================================================================
// DMA AXI Master Interface Module
// Supports AXI4 protocol with outstanding transactions
//=============================================================================

module dma_axi_master #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 64,
    parameter int AXI_ID_WIDTH   = 4,
    parameter int MAX_OUTSTANDING = 8
)(
    // Clock and Reset
    input  logic                        clk,
    input  logic                        rst_n,

    // AXI4 Write Address Channel
    output logic [AXI_ID_WIDTH-1:0]     m_axi_awid,
    output logic [AXI_ADDR_WIDTH-1:0]  m_axi_awaddr,
    output logic [7:0]                  m_axi_awlen,
    output logic [2:0]                  m_axi_awsize,
    output logic [1:0]                  m_axi_awburst,
    output logic                        m_axi_awlock,
    output logic [3:0]                  m_axi_awcache,
    output logic [2:0]                  m_axi_awprot,
    output logic [3:0]                  m_axi_awqos,
    output logic                        m_axi_awvalid,
    input  logic                        m_axi_awready,

    // AXI4 Write Data Channel
    output logic [AXI_DATA_WIDTH-1:0]  m_axi_wdata,
    output logic [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    output logic                        m_axi_wlast,
    output logic                        m_axi_wvalid,
    input  logic                        m_axi_wready,

    // AXI4 Write Response Channel
    input  logic [AXI_ID_WIDTH-1:0]    m_axi_bid,
    input  logic [1:0]                  m_axi_bresp,
    input  logic                        m_axi_bvalid,
    output logic                        m_axi_bready,

    // AXI4 Read Address Channel
    output logic [AXI_ID_WIDTH-1:0]     m_axi_arid,
    output logic [AXI_ADDR_WIDTH-1:0]  m_axi_araddr,
    output logic [7:0]                  m_axi_arlen,
    output logic [2:0]                  m_axi_arsize,
    output logic [1:0]                  m_axi_arburst,
    output logic                        m_axi_arlock,
    output logic [3:0]                  m_axi_arcache,
    output logic [2:0]                  m_axi_arprot,
    output logic [3:0]                  m_axi_arqos,
    output logic                        m_axi_arvalid,
    input  logic                        m_axi_arready,

    // AXI4 Read Data Channel
    input  logic [AXI_ID_WIDTH-1:0]    m_axi_rid,
    input  logic [AXI_DATA_WIDTH-1:0]  m_axi_rdata,
    input  logic [1:0]                  m_axi_rresp,
    input  logic                        m_axi_rlast,
    input  logic                        m_axi_rvalid,
    output logic                        m_axi_rready,

    // DMA Engine Interface - Write
    input  logic                        wr_req_valid,
    output logic                        wr_req_ready,
    input  logic [AXI_ADDR_WIDTH-1:0]  wr_addr,
    input  logic [15:0]                 wr_length,  // Number of beats
    input  logic [2:0]                  wr_size,    // Transfer size
    input  logic [AXI_ID_WIDTH-1:0]     wr_id,

    input  logic                        wr_data_valid,
    output logic                        wr_data_ready,
    input  logic [AXI_DATA_WIDTH-1:0]   wr_data,
    input  logic                        wr_data_last,

    output logic                        wr_resp_valid,
    input  logic                        wr_resp_ready,
    output logic [AXI_ID_WIDTH-1:0]    wr_resp_id,
    output logic [1:0]                  wr_resp_status,

    // DMA Engine Interface - Read
    input  logic                        rd_req_valid,
    output logic                        rd_req_ready,
    input  logic [AXI_ADDR_WIDTH-1:0]  rd_addr,
    input  logic [15:0]                 rd_length,  // Number of beats
    input  logic [2:0]                  rd_size,    // Transfer size
    input  logic [AXI_ID_WIDTH-1:0]     rd_id,

    output logic                        rd_data_valid,
    input  logic                        rd_data_ready,
    output logic [AXI_DATA_WIDTH-1:0]  rd_data,
    output logic                        rd_data_last,
    output logic [AXI_ID_WIDTH-1:0]    rd_data_id
);

    // Outstanding transaction tracking
    typedef struct packed {
        logic [AXI_ID_WIDTH-1:0] id;
        logic                     valid;
    } outstanding_entry_t;

    outstanding_entry_t [MAX_OUTSTANDING-1:0] wr_outstanding;
    outstanding_entry_t [MAX_OUTSTANDING-1:0] rd_outstanding;
    
    logic [$clog2(MAX_OUTSTANDING):0] wr_outstanding_count;
    logic [$clog2(MAX_OUTSTANDING):0] rd_outstanding_count;

    // Write Address Channel FSM
    typedef enum logic [1:0] {
        WR_ADDR_IDLE,
        WR_ADDR_SEND
    } wr_addr_state_t;

    wr_addr_state_t wr_addr_state;
    logic [AXI_ADDR_WIDTH-1:0] wr_addr_reg;
    logic [15:0] wr_length_reg;
    logic [2:0] wr_size_reg;
    logic [AXI_ID_WIDTH-1:0] wr_id_reg;

    // Write Data Channel FSM
    typedef enum logic [1:0] {
        WR_DATA_IDLE,
        WR_DATA_SEND
    } wr_data_state_t;

    wr_data_state_t wr_data_state;
    logic [15:0] wr_beat_count;

    // Write Response Channel
    logic [AXI_ID_WIDTH-1:0] wr_resp_id_reg;
    logic [1:0] wr_resp_status_reg;

    // Read Address Channel FSM
    typedef enum logic [1:0] {
        RD_ADDR_IDLE,
        RD_ADDR_SEND
    } rd_addr_state_t;

    rd_addr_state_t rd_addr_state;
    logic [AXI_ADDR_WIDTH-1:0] rd_addr_reg;
    logic [15:0] rd_length_reg;
    logic [2:0] rd_size_reg;
    logic [AXI_ID_WIDTH-1:0] rd_id_reg;

    // Read Data Channel
    logic [AXI_ID_WIDTH-1:0] rd_data_id_reg;
    logic [15:0] rd_beat_count;
    logic [MAX_OUTSTANDING-1:0] rd_active_id;

    // Outstanding count management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_outstanding_count <= '0;
            rd_outstanding_count <= '0;
        end else begin
            // Write outstanding count
            if (wr_req_valid && wr_req_ready && m_axi_awvalid && m_axi_awready) begin
                wr_outstanding_count <= wr_outstanding_count + 1;
            end else if (m_axi_bvalid && m_axi_bready) begin
                wr_outstanding_count <= wr_outstanding_count - 1;
            end

            // Read outstanding count
            if (rd_req_valid && rd_req_ready && m_axi_arvalid && m_axi_arready) begin
                rd_outstanding_count <= rd_outstanding_count + 1;
            end else if (m_axi_rvalid && m_axi_rready && m_axi_rlast) begin
                rd_outstanding_count <= rd_outstanding_count - 1;
            end
        end
    end

    //=========================================================================
    // Write Address Channel
    //=========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_addr_state <= WR_ADDR_IDLE;
            m_axi_awvalid <= 1'b0;
        end else begin
            case (wr_addr_state)
                WR_ADDR_IDLE: begin
                    if (wr_req_valid && (wr_outstanding_count < MAX_OUTSTANDING)) begin
                        wr_addr_reg <= wr_addr;
                        wr_length_reg <= wr_length;
                        wr_size_reg <= wr_size;
                        wr_id_reg <= wr_id;
                        m_axi_awaddr <= wr_addr;
                        m_axi_awlen <= wr_length - 1;  // AXI length is number of beats - 1
                        m_axi_awsize <= wr_size;
                        m_axi_awburst <= 2'b01;  // INCR burst
                        m_axi_awid <= wr_id;
                        m_axi_awvalid <= 1'b1;
                        wr_addr_state <= WR_ADDR_SEND;
                    end
                end
                WR_ADDR_SEND: begin
                    if (m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        wr_addr_state <= WR_ADDR_IDLE;
                    end
                end
            endcase
        end
    end

    assign wr_req_ready = (wr_addr_state == WR_ADDR_IDLE) && 
                          (wr_outstanding_count < MAX_OUTSTANDING);

    // AXI Write Address Channel defaults
    assign m_axi_awlock = 1'b0;
    assign m_axi_awcache = 4'b0011;  // Normal, Non-cacheable, Bufferable
    assign m_axi_awprot = 3'b000;
    assign m_axi_awqos = 4'b0000;

    //=========================================================================
    // Write Data Channel
    //=========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_data_state <= WR_DATA_IDLE;
            m_axi_wvalid <= 1'b0;
            wr_beat_count <= '0;
        end else begin
            case (wr_data_state)
                WR_DATA_IDLE: begin
                    if (wr_data_valid && (wr_outstanding_count > 0)) begin
                        m_axi_wdata <= wr_data;
                        m_axi_wstrb <= {(AXI_DATA_WIDTH/8){1'b1}};  // All bytes valid
                        m_axi_wlast <= wr_data_last;
                        m_axi_wvalid <= 1'b1;
                        wr_beat_count <= wr_beat_count + 1;
                        if (wr_data_last) begin
                            wr_data_state <= WR_DATA_IDLE;
                            wr_beat_count <= '0;
                        end else begin
                            wr_data_state <= WR_DATA_SEND;
                        end
                    end
                end
                WR_DATA_SEND: begin
                    if (m_axi_wready) begin
                        if (wr_data_valid) begin
                            m_axi_wdata <= wr_data;
                            m_axi_wlast <= wr_data_last;
                            wr_beat_count <= wr_beat_count + 1;
                            if (wr_data_last) begin
                                m_axi_wvalid <= 1'b0;
                                wr_data_state <= WR_DATA_IDLE;
                                wr_beat_count <= '0;
                            end
                        end else begin
                            m_axi_wvalid <= 1'b0;
                        end
                    end
                end
            endcase
        end
    end

    assign wr_data_ready = (wr_data_state == WR_DATA_IDLE && wr_data_valid) ||
                           (wr_data_state == WR_DATA_SEND && m_axi_wready && wr_data_valid);

    //=========================================================================
    // Write Response Channel
    //=========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_bready <= 1'b1;
            wr_resp_valid <= 1'b0;
        end else begin
            if (m_axi_bvalid && m_axi_bready) begin
                wr_resp_id_reg <= m_axi_bid;
                wr_resp_status_reg <= m_axi_bresp;
                wr_resp_valid <= 1'b1;
            end else if (wr_resp_ready) begin
                wr_resp_valid <= 1'b0;
            end
        end
    end

    assign wr_resp_id = wr_resp_id_reg;
    assign wr_resp_status = wr_resp_status_reg;

    //=========================================================================
    // Read Address Channel
    //=========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_addr_state <= RD_ADDR_IDLE;
            m_axi_arvalid <= 1'b0;
        end else begin
            case (rd_addr_state)
                RD_ADDR_IDLE: begin
                    if (rd_req_valid && (rd_outstanding_count < MAX_OUTSTANDING)) begin
                        rd_addr_reg <= rd_addr;
                        rd_length_reg <= rd_length;
                        rd_size_reg <= rd_size;
                        rd_id_reg <= rd_id;
                        m_axi_araddr <= rd_addr;
                        m_axi_arlen <= rd_length - 1;  // AXI length is number of beats - 1
                        m_axi_arsize <= rd_size;
                        m_axi_arburst <= 2'b01;  // INCR burst
                        m_axi_arid <= rd_id;
                        m_axi_arvalid <= 1'b1;
                        rd_addr_state <= RD_ADDR_SEND;
                    end
                end
                RD_ADDR_SEND: begin
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        rd_addr_state <= RD_ADDR_IDLE;
                    end
                end
            endcase
        end
    end

    assign rd_req_ready = (rd_addr_state == RD_ADDR_IDLE) && 
                          (rd_outstanding_count < MAX_OUTSTANDING);

    // AXI Read Address Channel defaults
    assign m_axi_arlock = 1'b0;
    assign m_axi_arcache = 4'b0011;  // Normal, Non-cacheable, Bufferable
    assign m_axi_arprot = 3'b000;
    assign m_axi_arqos = 4'b0000;

    //=========================================================================
    // Read Data Channel
    //=========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_data_valid <= 1'b0;
            rd_beat_count <= '0;
            m_axi_rready <= 1'b1;
        end else begin
            if (m_axi_rvalid && m_axi_rready) begin
                rd_data <= m_axi_rdata;
                rd_data_id_reg <= m_axi_rid;
                rd_data_last <= m_axi_rlast;
                rd_data_valid <= 1'b1;
                if (m_axi_rlast) begin
                    rd_beat_count <= '0;
                end else begin
                    rd_beat_count <= rd_beat_count + 1;
                end
            end else if (rd_data_ready) begin
                rd_data_valid <= 1'b0;
            end
        end
    end

    assign rd_data_id = rd_data_id_reg;

endmodule
