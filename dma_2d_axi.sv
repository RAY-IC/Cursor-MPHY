//=============================================================================
// 2D DMA Module with AXI Interface
// Top-level module integrating AXI Master and 2D DMA Engine
// Supports outstanding transactions and configurable tile-based transfers
//=============================================================================

module dma_2d_axi #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 64,
    parameter int AXI_ID_WIDTH   = 4,
    parameter int MAX_OUTSTANDING = 8,
    parameter int REG_ADDR_WIDTH = 8
)(
    // Clock and Reset
    input  logic                        clk,
    input  logic                        rst_n,

    // AXI4 Master Interface - Memory Access
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

    output logic [AXI_DATA_WIDTH-1:0]  m_axi_wdata,
    output logic [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    output logic                        m_axi_wlast,
    output logic                        m_axi_wvalid,
    input  logic                        m_axi_wready,

    input  logic [AXI_ID_WIDTH-1:0]    m_axi_bid,
    input  logic [1:0]                  m_axi_bresp,
    input  logic                        m_axi_bvalid,
    output logic                        m_axi_bready,

    output logic [AXI_ID_WIDTH-1:0]    m_axi_arid,
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

    input  logic [AXI_ID_WIDTH-1:0]    m_axi_rid,
    input  logic [AXI_DATA_WIDTH-1:0]  m_axi_rdata,
    input  logic [1:0]                  m_axi_rresp,
    input  logic                        m_axi_rlast,
    input  logic                        m_axi_rvalid,
    output logic                        m_axi_rready,

    // AXI4 Slave Interface - Register Access (optional, can use APB or other)
    input  logic                        s_axi_awvalid,
    output logic                        s_axi_awready,
    input  logic [REG_ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  logic [2:0]                  s_axi_awprot,

    input  logic                        s_axi_wvalid,
    output logic                        s_axi_wready,
    input  logic [31:0]                 s_axi_wdata,
    input  logic [3:0]                  s_axi_wstrb,

    output logic                        s_axi_bvalid,
    input  logic                        s_axi_bready,
    output logic [1:0]                  s_axi_bresp,

    input  logic                        s_axi_arvalid,
    output logic                        s_axi_arready,
    input  logic [REG_ADDR_WIDTH-1:0]  s_axi_araddr,
    input  logic [2:0]                  s_axi_arprot,

    output logic                        s_axi_rvalid,
    input  logic                        s_axi_rready,
    output logic [31:0]                 s_axi_rdata,
    output logic [1:0]                  s_axi_rresp
);

    // Register definitions
    typedef struct packed {
        logic [30:0] reserved;
        logic        start;      // Bit 31: Start DMA transfer
    } dma_ctrl_reg_t;

    typedef struct packed {
        logic [29:0] reserved;
        logic        error;      // Bit 30: Error occurred
        logic        done;       // Bit 31: Transfer complete
    } dma_status_reg_t;

    // Internal signals
    logic                        dma_start;
    logic                        dma_done;
    logic                        dma_error;
    
    logic [AXI_ADDR_WIDTH-1:0]  src_base_addr;
    logic [AXI_ADDR_WIDTH-1:0]  dst_base_addr;
    logic [15:0]                frame_width;
    logic [15:0]                frame_height;
    logic [15:0]                tile_width;
    logic [15:0]                tile_height;
    logic [15:0]                tile_stride;
    logic [15:0]                pixel_stride;
    logic                        direction;
    logic [2:0]                  transfer_size;

    // AXI Master interface signals
    logic                        axi_wr_req_valid;
    logic                        axi_wr_req_ready;
    logic [AXI_ADDR_WIDTH-1:0]  axi_wr_addr;
    logic [15:0]                axi_wr_length;
    logic [2:0]                 axi_wr_size;
    logic [AXI_ID_WIDTH-1:0]    axi_wr_id;

    logic                        axi_wr_data_valid;
    logic                        axi_wr_data_ready;
    logic [AXI_DATA_WIDTH-1:0]  axi_wr_data;
    logic                        axi_wr_data_last;

    logic                        axi_wr_resp_valid;
    logic                        axi_wr_resp_ready;
    logic [AXI_ID_WIDTH-1:0]    axi_wr_resp_id;
    logic [1:0]                 axi_wr_resp_status;

    logic                        axi_rd_req_valid;
    logic                        axi_rd_req_ready;
    logic [AXI_ADDR_WIDTH-1:0]  axi_rd_addr;
    logic [15:0]                axi_rd_length;
    logic [2:0]                 axi_rd_size;
    logic [AXI_ID_WIDTH-1:0]    axi_rd_id;

    logic                        axi_rd_data_valid;
    logic                        axi_rd_data_ready;
    logic [AXI_DATA_WIDTH-1:0]  axi_rd_data;
    logic                        axi_rd_data_last;
    logic [AXI_ID_WIDTH-1:0]    axi_rd_data_id;

    // Internal buffer (simplified - in real design would use BRAM or external memory)
    logic                        buf_wr_en;
    logic [AXI_ADDR_WIDTH-1:0]  buf_wr_addr;
    logic [AXI_DATA_WIDTH-1:0]  buf_wr_data;
    logic                        buf_rd_en;
    logic [AXI_ADDR_WIDTH-1:0]  buf_rd_addr;
    logic [AXI_DATA_WIDTH-1:0]  buf_rd_data;

    // Register File
    dma_ctrl_reg_t  ctrl_reg;
    dma_status_reg_t status_reg;
    logic [31:0] reg_file [0:15];

    // Register write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++) begin
                reg_file[i] <= '0;
            end
            ctrl_reg <= '0;
        end else begin
            if (s_axi_awvalid && s_axi_awready && s_axi_wvalid && s_axi_wready) begin
                case (s_axi_awaddr[7:2])
                    6'h00: begin  // CTRL_REG
                        if (s_axi_wstrb[3]) ctrl_reg.start <= s_axi_wdata[31];
                    end
                    6'h02: begin  // SRC_ADDR_REG
                        if (s_axi_wstrb[0]) reg_file[2][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_file[2][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_file[2][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_file[2][31:24] <= s_axi_wdata[31:24];
                    end
                    6'h03: begin  // DST_ADDR_REG
                        if (s_axi_wstrb[0]) reg_file[3][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_file[3][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_file[3][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_file[3][31:24] <= s_axi_wdata[31:24];
                    end
                    6'h04: begin  // FRAME_WIDTH
                        if (s_axi_wstrb[0]) reg_file[4][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_file[4][15:8]  <= s_axi_wdata[15:8];
                    end
                    6'h05: begin  // FRAME_HEIGHT
                        if (s_axi_wstrb[0]) reg_file[5][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_file[5][15:8]  <= s_axi_wdata[15:8];
                    end
                    6'h06: begin  // TILE_WIDTH
                        if (s_axi_wstrb[0]) reg_file[6][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_file[6][15:8]  <= s_axi_wdata[15:8];
                    end
                    6'h07: begin  // TILE_HEIGHT
                        if (s_axi_wstrb[0]) reg_file[7][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_file[7][15:8]  <= s_axi_wdata[15:8];
                    end
                    6'h08: begin  // TILE_STRIDE
                        if (s_axi_wstrb[0]) reg_file[8][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_file[8][15:8]  <= s_axi_wdata[15:8];
                    end
                    6'h09: begin  // PIXEL_STRIDE
                        if (s_axi_wstrb[0]) reg_file[9][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_file[9][15:8]  <= s_axi_wdata[15:8];
                    end
                    6'h0A: begin  // TRANSFER_SIZE
                        if (s_axi_wstrb[0]) reg_file[10][2:0] <= s_axi_wdata[2:0];
                    end
                endcase
            end
            
            // Clear start bit after one cycle
            if (ctrl_reg.start) begin
                ctrl_reg.start <= 1'b0;
            end
            
            // Update status register
            status_reg.done <= dma_done;
            status_reg.error <= dma_error;
        end
    end

    // Register read logic
    always_comb begin
        reg_file[0] = {ctrl_reg.reserved, ctrl_reg.start};
        reg_file[1] = {status_reg.reserved, status_reg.error, status_reg.done};
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata <= '0;
        end else begin
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rdata <= reg_file[s_axi_araddr[7:2]];
            end else if (s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    assign s_axi_awready = s_axi_awvalid && s_axi_wvalid;
    assign s_axi_wready = s_axi_awvalid && s_axi_wvalid;
    assign s_axi_bvalid = s_axi_awvalid && s_axi_awready && s_axi_wvalid && s_axi_wready;
    assign s_axi_bresp = 2'b00;
    assign s_axi_arready = !s_axi_rvalid;
    assign s_axi_rresp = 2'b00;

    // Connect registers to DMA engine
    assign dma_start = ctrl_reg.start;
    assign src_base_addr = reg_file[2];
    assign dst_base_addr = reg_file[3];
    assign frame_width = reg_file[4][15:0];
    assign frame_height = reg_file[5][15:0];
    assign tile_width = reg_file[6][15:0];
    assign tile_height = reg_file[7][15:0];
    assign tile_stride = reg_file[8][15:0];
    assign pixel_stride = reg_file[9][15:0];
    assign direction = reg_file[10][3];
    assign transfer_size = reg_file[10][2:0];

    // Internal buffer (simplified - in real design would use BRAM)
    // For now, this is a pass-through for write direction
    assign buf_rd_data = buf_wr_data;  // Simplified - real design needs BRAM

    // Instantiate AXI Master
    dma_axi_master #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .MAX_OUTSTANDING(MAX_OUTSTANDING)
    ) u_axi_master (
        .clk(clk),
        .rst_n(rst_n),
        
        .m_axi_awid(m_axi_awid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        
        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        
        .m_axi_arid(m_axi_arid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        
        .m_axi_rid(m_axi_rid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        
        .wr_req_valid(axi_wr_req_valid),
        .wr_req_ready(axi_wr_req_ready),
        .wr_addr(axi_wr_addr),
        .wr_length(axi_wr_length),
        .wr_size(axi_wr_size),
        .wr_id(axi_wr_id),
        
        .wr_data_valid(axi_wr_data_valid),
        .wr_data_ready(axi_wr_data_ready),
        .wr_data(axi_wr_data),
        .wr_data_last(axi_wr_data_last),
        
        .wr_resp_valid(axi_wr_resp_valid),
        .wr_resp_ready(axi_wr_resp_ready),
        .wr_resp_id(axi_wr_resp_id),
        .wr_resp_status(axi_wr_resp_status),
        
        .rd_req_valid(axi_rd_req_valid),
        .rd_req_ready(axi_rd_req_ready),
        .rd_addr(axi_rd_addr),
        .rd_length(axi_rd_length),
        .rd_size(axi_rd_size),
        .rd_id(axi_rd_id),
        
        .rd_data_valid(axi_rd_data_valid),
        .rd_data_ready(axi_rd_data_ready),
        .rd_data(axi_rd_data),
        .rd_data_last(axi_rd_data_last),
        .rd_data_id(axi_rd_data_id)
    );

    // Instantiate 2D DMA Engine
    dma_2d_engine #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .MAX_OUTSTANDING(MAX_OUTSTANDING)
    ) u_dma_2d_engine (
        .clk(clk),
        .rst_n(rst_n),
        
        .start(dma_start),
        .done(dma_done),
        .error(dma_error),
        
        .src_base_addr(src_base_addr),
        .dst_base_addr(dst_base_addr),
        .frame_width(frame_width),
        .frame_height(frame_height),
        .tile_width(tile_width),
        .tile_height(tile_height),
        .tile_stride(tile_stride),
        .pixel_stride(pixel_stride),
        .direction(direction),
        .transfer_size(transfer_size),
        
        .axi_wr_req_valid(axi_wr_req_valid),
        .axi_wr_req_ready(axi_wr_req_ready),
        .axi_wr_addr(axi_wr_addr),
        .axi_wr_length(axi_wr_length),
        .axi_wr_size(axi_wr_size),
        .axi_wr_id(axi_wr_id),
        
        .axi_wr_data_valid(axi_wr_data_valid),
        .axi_wr_data_ready(axi_wr_data_ready),
        .axi_wr_data(axi_wr_data),
        .axi_wr_data_last(axi_wr_data_last),
        
        .axi_wr_resp_valid(axi_wr_resp_valid),
        .axi_wr_resp_ready(axi_wr_resp_ready),
        .axi_wr_resp_id(axi_wr_resp_id),
        .axi_wr_resp_status(axi_wr_resp_status),
        
        .axi_rd_req_valid(axi_rd_req_valid),
        .axi_rd_req_ready(axi_rd_req_ready),
        .axi_rd_addr(axi_rd_addr),
        .axi_rd_length(axi_rd_length),
        .axi_rd_size(axi_rd_size),
        .axi_rd_id(axi_rd_id),
        
        .axi_rd_data_valid(axi_rd_data_valid),
        .axi_rd_data_ready(axi_rd_data_ready),
        .axi_rd_data(axi_rd_data),
        .axi_rd_data_last(axi_rd_data_last),
        .axi_rd_data_id(axi_rd_data_id),
        
        .buf_wr_en(buf_wr_en),
        .buf_wr_addr(buf_wr_addr),
        .buf_wr_data(buf_wr_data),
        
        .buf_rd_en(buf_rd_en),
        .buf_rd_addr(buf_rd_addr),
        .buf_rd_data(buf_rd_data)
    );

endmodule
