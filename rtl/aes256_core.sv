//=============================================================================
// AES256 Core Encryption/Decryption Engine
// Description: Pure AES-256 core implementing encryption and decryption
//              Supports 256-bit keys, 128-bit data blocks
//=============================================================================

module aes256_core (
    input  wire         clk,
    input  wire         rst_n,
    
    // Control signals
    input  wire         encrypt,      // 1=encrypt, 0=decrypt
    input  wire         valid_in,
    output reg          ready_out,
    
    // Data interfaces
    input  wire [127:0] data_in,
    input  wire [255:0] key,
    output reg  [127:0] data_out,
    output reg          valid_out
);

// AES constants
localparam int Nk = 8;        // Number of 32-bit words in key (256-bit = 8 words)
localparam int Nb = 4;        // Number of 32-bit words in state
localparam int Nr = 14;       // Number of rounds (AES-256)

// State machine
typedef enum logic [2:0] {
    IDLE,
    KEY_EXPAND,
    PROCESS_ROUNDS,
    FINAL_ROUND,
    DONE
} state_t;

state_t state, next_state;

// Round counter
reg [3:0] round_cnt;
reg [3:0] round_cnt_next;

// Key expansion storage
reg [127:0] round_key [0:Nr];
reg [255:0] key_reg;

// State storage (128-bit)
reg [127:0] state_reg;
reg [127:0] state_next;

// Key expansion signals
wire [31:0] w [0:59];  // Expanded key words (60 words for AES-256)

// Round processing signals
wire [127:0] sub_bytes_out;
wire [127:0] shift_rows_out;
wire [127:0] mix_columns_out;
wire [127:0] add_round_key_out;

//-----------------------------------------------------------------------------
// S-box lookup table (encryption)
//-----------------------------------------------------------------------------
function automatic [7:0] sbox_enc(input [7:0] byte);
    case (byte)
        8'h00: sbox_enc = 8'h63; 8'h01: sbox_enc = 8'h7c; 8'h02: sbox_enc = 8'h77; 8'h03: sbox_enc = 8'h7b;
        8'h04: sbox_enc = 8'hf2; 8'h05: sbox_enc = 8'h6b; 8'h06: sbox_enc = 8'h6f; 8'h07: sbox_enc = 8'hc5;
        8'h08: sbox_enc = 8'h30; 8'h09: sbox_enc = 8'h01; 8'h0a: sbox_enc = 8'h67; 8'h0b: sbox_enc = 8'h2b;
        8'h0c: sbox_enc = 8'hfe; 8'h0d: sbox_enc = 8'hd7; 8'h0e: sbox_enc = 8'hab; 8'h0f: sbox_enc = 8'h76;
        8'h10: sbox_enc = 8'hca; 8'h11: sbox_enc = 8'h82; 8'h12: sbox_enc = 8'hc9; 8'h13: sbox_enc = 8'h7d;
        8'h14: sbox_enc = 8'hfa; 8'h15: sbox_enc = 8'h59; 8'h16: sbox_enc = 8'h47; 8'h17: sbox_enc = 8'hf0;
        8'h18: sbox_enc = 8'had; 8'h19: sbox_enc = 8'hd4; 8'h1a: sbox_enc = 8'ha2; 8'h1b: sbox_enc = 8'haf;
        8'h1c: sbox_enc = 8'h9c; 8'h1d: sbox_enc = 8'ha4; 8'h1e: sbox_enc = 8'h72; 8'h1f: sbox_enc = 8'hc0;
        8'h20: sbox_enc = 8'hb7; 8'h21: sbox_enc = 8'hfd; 8'h22: sbox_enc = 8'h93; 8'h23: sbox_enc = 8'h26;
        8'h24: sbox_enc = 8'h36; 8'h25: sbox_enc = 8'h3f; 8'h26: sbox_enc = 8'hf7; 8'h27: sbox_enc = 8'hcc;
        8'h28: sbox_enc = 8'h34; 8'h29: sbox_enc = 8'ha5; 8'h2a: sbox_enc = 8'he5; 8'h2b: sbox_enc = 8'hf1;
        8'h2c: sbox_enc = 8'h71; 8'h2d: sbox_enc = 8'hd8; 8'h2e: sbox_enc = 8'h31; 8'h2f: sbox_enc = 8'h15;
        8'h30: sbox_enc = 8'h04; 8'h31: sbox_enc = 8'hc7; 8'h32: sbox_enc = 8'h23; 8'h33: sbox_enc = 8'hc3;
        8'h34: sbox_enc = 8'h18; 8'h35: sbox_enc = 8'h96; 8'h36: sbox_enc = 8'h05; 8'h37: sbox_enc = 8'h9a;
        8'h38: sbox_enc = 8'h07; 8'h39: sbox_enc = 8'h12; 8'h3a: sbox_enc = 8'h80; 8'h3b: sbox_enc = 8'he2;
        8'h3c: sbox_enc = 8'heb; 8'h3d: sbox_enc = 8'h27; 8'h3e: sbox_enc = 8'hb2; 8'h3f: sbox_enc = 8'h75;
        8'h40: sbox_enc = 8'h09; 8'h41: sbox_enc = 8'h83; 8'h42: sbox_enc = 8'h2c; 8'h43: sbox_enc = 8'h1a;
        8'h44: sbox_enc = 8'h1b; 8'h45: sbox_enc = 8'h6e; 8'h46: sbox_enc = 8'h5a; 8'h47: sbox_enc = 8'ha0;
        8'h48: sbox_enc = 8'h52; 8'h49: sbox_enc = 8'h3b; 8'h4a: sbox_enc = 8'hd6; 8'h4b: sbox_enc = 8'hb3;
        8'h4c: sbox_enc = 8'h29; 8'h4d: sbox_enc = 8'he3; 8'h4e: sbox_enc = 8'h2f; 8'h4f: sbox_enc = 8'h84;
        8'h50: sbox_enc = 8'h53; 8'h51: sbox_enc = 8'hd1; 8'h52: sbox_enc = 8'h00; 8'h53: sbox_enc = 8'hed;
        8'h54: sbox_enc = 8'h20; 8'h55: sbox_enc = 8'hfc; 8'h56: sbox_enc = 8'hb1; 8'h57: sbox_enc = 8'h5b;
        8'h58: sbox_enc = 8'h6a; 8'h59: sbox_enc = 8'hcb; 8'h5a: sbox_enc = 8'hbe; 8'h5b: sbox_enc = 8'h39;
        8'h5c: sbox_enc = 8'h4a; 8'h5d: sbox_enc = 8'h4c; 8'h5e: sbox_enc = 8'h58; 8'h5f: sbox_enc = 8'hcf;
        8'h60: sbox_enc = 8'hd0; 8'h61: sbox_enc = 8'hef; 8'h62: sbox_enc = 8'haa; 8'h63: sbox_enc = 8'hfb;
        8'h64: sbox_enc = 8'h43; 8'h65: sbox_enc = 8'h4d; 8'h66: sbox_enc = 8'h33; 8'h67: sbox_enc = 8'h85;
        8'h68: sbox_enc = 8'h45; 8'h69: sbox_enc = 8'hf9; 8'h6a: sbox_enc = 8'h02; 8'h6b: sbox_enc = 8'h7f;
        8'h6c: sbox_enc = 8'h50; 8'h6d: sbox_enc = 8'h3c; 8'h6e: sbox_enc = 8'h9f; 8'h6f: sbox_enc = 8'ha8;
        8'h70: sbox_enc = 8'h51; 8'h71: sbox_enc = 8'ha3; 8'h72: sbox_enc = 8'h40; 8'h73: sbox_enc = 8'h8f;
        8'h74: sbox_enc = 8'h92; 8'h75: sbox_enc = 8'h9d; 8'h76: sbox_enc = 8'h38; 8'h77: sbox_enc = 8'hf5;
        8'h78: sbox_enc = 8'hbc; 8'h79: sbox_enc = 8'hb6; 8'h7a: sbox_enc = 8'hda; 8'h7b: sbox_enc = 8'h21;
        8'h7c: sbox_enc = 8'h10; 8'h7d: sbox_enc = 8'hff; 8'h7e: sbox_enc = 8'hf3; 8'h7f: sbox_enc = 8'hd2;
        8'h80: sbox_enc = 8'hcd; 8'h81: sbox_enc = 8'h0c; 8'h82: sbox_enc = 8'h13; 8'h83: sbox_enc = 8'hec;
        8'h84: sbox_enc = 8'h5f; 8'h85: sbox_enc = 8'h97; 8'h86: sbox_enc = 8'h44; 8'h87: sbox_enc = 8'h17;
        8'h88: sbox_enc = 8'hc4; 8'h89: sbox_enc = 8'ha7; 8'h8a: sbox_enc = 8'h7e; 8'h8b: sbox_enc = 8'h3d;
        8'h8c: sbox_enc = 8'h64; 8'h8d: sbox_enc = 8'h5d; 8'h8e: sbox_enc = 8'h19; 8'h8f: sbox_enc = 8'h73;
        8'h90: sbox_enc = 8'h60; 8'h91: sbox_enc = 8'h81; 8'h92: sbox_enc = 8'h4f; 8'h93: sbox_enc = 8'hdc;
        8'h94: sbox_enc = 8'h22; 8'h95: sbox_enc = 8'h2a; 8'h96: sbox_enc = 8'h90; 8'h97: sbox_enc = 8'h88;
        8'h98: sbox_enc = 8'h46; 8'h99: sbox_enc = 8'hee; 8'h9a: sbox_enc = 8'hb8; 8'h9b: sbox_enc = 8'h14;
        8'h9c: sbox_enc = 8'hde; 8'h9d: sbox_enc = 8'h5e; 8'h9e: sbox_enc = 8'h0b; 8'h9f: sbox_enc = 8'hdb;
        8'ha0: sbox_enc = 8'he0; 8'ha1: sbox_enc = 8'h32; 8'ha2: sbox_enc = 8'h3a; 8'ha3: sbox_enc = 8'h0a;
        8'ha4: sbox_enc = 8'h49; 8'ha5: sbox_enc = 8'h06; 8'ha6: sbox_enc = 8'h24; 8'ha7: sbox_enc = 8'h5c;
        8'ha8: sbox_enc = 8'hc2; 8'ha9: sbox_enc = 8'hd3; 8'haa: sbox_enc = 8'hac; 8'hab: sbox_enc = 8'h62;
        8'hac: sbox_enc = 8'h91; 8'had: sbox_enc = 8'h95; 8'hae: sbox_enc = 8'he4; 8'haf: sbox_enc = 8'h79;
        8'hb0: sbox_enc = 8'he7; 8'hb1: sbox_enc = 8'hc8; 8'hb2: sbox_enc = 8'h37; 8'hb3: sbox_enc = 8'h6d;
        8'hb4: sbox_enc = 8'h8d; 8'hb5: sbox_enc = 8'hd5; 8'hb6: sbox_enc = 8'h4e; 8'hb7: sbox_enc = 8'ha9;
        8'hb8: sbox_enc = 8'h6c; 8'hb9: sbox_enc = 8'h56; 8'hba: sbox_enc = 8'hf4; 8'hbb: sbox_enc = 8'hea;
        8'hbc: sbox_enc = 8'h65; 8'hbd: sbox_enc = 8'h7a; 8'hbe: sbox_enc = 8'hae; 8'hbf: sbox_enc = 8'h08;
        8'hc0: sbox_enc = 8'hba; 8'hc1: sbox_enc = 8'h78; 8'hc2: sbox_enc = 8'h25; 8'hc3: sbox_enc = 8'h2e;
        8'hc4: sbox_enc = 8'h1c; 8'hc5: sbox_enc = 8'ha6; 8'hc6: sbox_enc = 8'hb4; 8'hc7: sbox_enc = 8'hc6;
        8'hc8: sbox_enc = 8'he8; 8'hc9: sbox_enc = 8'hdd; 8'hca: sbox_enc = 8'h74; 8'hcb: sbox_enc = 8'h1f;
        8'hcc: sbox_enc = 8'h4b; 8'hcd: sbox_enc = 8'hbd; 8'hce: sbox_enc = 8'h8b; 8'hcf: sbox_enc = 8'h8a;
        8'hd0: sbox_enc = 8'h70; 8'hd1: sbox_enc = 8'h3e; 8'hd2: sbox_enc = 8'hb5; 8'hd3: sbox_enc = 8'h66;
        8'hd4: sbox_enc = 8'h48; 8'hd5: sbox_enc = 8'h03; 8'hd6: sbox_enc = 8'hf6; 8'hd7: sbox_enc = 8'h0e;
        8'hd8: sbox_enc = 8'h61; 8'hd9: sbox_enc = 8'h35; 8'hda: sbox_enc = 8'h57; 8'hdb: sbox_enc = 8'hb9;
        8'hdc: sbox_enc = 8'h86; 8'hdd: sbox_enc = 8'hc1; 8'hde: sbox_enc = 8'h1d; 8'hdf: sbox_enc = 8'h9e;
        8'he0: sbox_enc = 8'he1; 8'he1: sbox_enc = 8'hf8; 8'he2: sbox_enc = 8'h98; 8'he3: sbox_enc = 8'h11;
        8'he4: sbox_enc = 8'h69; 8'he5: sbox_enc = 8'hd9; 8'he6: sbox_enc = 8'h8e; 8'he7: sbox_enc = 8'h94;
        8'he8: sbox_enc = 8'h9b; 8'he9: sbox_enc = 8'h1e; 8'hea: sbox_enc = 8'h87; 8'heb: sbox_enc = 8'he9;
        8'hec: sbox_enc = 8'hce; 8'hed: sbox_enc = 8'h55; 8'hee: sbox_enc = 8'h28; 8'hef: sbox_enc = 8'hdf;
        8'hf0: sbox_enc = 8'h8c; 8'hf1: sbox_enc = 8'ha1; 8'hf2: sbox_enc = 8'h89; 8'hf3: sbox_enc = 8'h0d;
        8'hf4: sbox_enc = 8'hbf; 8'hf5: sbox_enc = 8'he6; 8'hf6: sbox_enc = 8'h42; 8'hf7: sbox_enc = 8'h68;
        8'hf8: sbox_enc = 8'h41; 8'hf9: sbox_enc = 8'h99; 8'hfa: sbox_enc = 8'h2d; 8'hfb: sbox_enc = 8'h0f;
        8'hfc: sbox_enc = 8'hb0; 8'hfd: sbox_enc = 8'h54; 8'hfe: sbox_enc = 8'hbb; 8'hff: sbox_enc = 8'h16;
        default: sbox_enc = 8'h00;
    endcase
endfunction

//-----------------------------------------------------------------------------
// Inverse S-box lookup table (decryption)
//-----------------------------------------------------------------------------
function automatic [7:0] sbox_dec(input [7:0] byte);
    case (byte)
        8'h00: sbox_dec = 8'h52; 8'h01: sbox_dec = 8'h09; 8'h02: sbox_dec = 8'h6a; 8'h03: sbox_dec = 8'hd5;
        8'h04: sbox_dec = 8'h30; 8'h05: sbox_dec = 8'h36; 8'h06: sbox_dec = 8'ha5; 8'h07: sbox_dec = 8'h38;
        8'h08: sbox_dec = 8'hbf; 8'h09: sbox_dec = 8'h40; 8'h0a: sbox_dec = 8'ha3; 8'h0b: sbox_dec = 8'h9e;
        8'h0c: sbox_dec = 8'h81; 8'h0d: sbox_dec = 8'hf3; 8'h0e: sbox_dec = 8'hd7; 8'h0f: sbox_dec = 8'hfb;
        8'h10: sbox_dec = 8'h7c; 8'h11: sbox_dec = 8'he3; 8'h12: sbox_dec = 8'h39; 8'h13: sbox_dec = 8'h82;
        8'h14: sbox_dec = 8'h9b; 8'h15: sbox_dec = 8'h2f; 8'h16: sbox_dec = 8'hff; 8'h17: sbox_dec = 8'h87;
        8'h18: sbox_dec = 8'h34; 8'h19: sbox_dec = 8'h8e; 8'h1a: sbox_dec = 8'h43; 8'h1b: sbox_dec = 8'h44;
        8'h1c: sbox_dec = 8'hc4; 8'h1d: sbox_dec = 8'hde; 8'h1e: sbox_dec = 8'he9; 8'h1f: sbox_dec = 8'hcb;
        8'h20: sbox_dec = 8'h54; 8'h21: sbox_dec = 8'h7b; 8'h22: sbox_dec = 8'h94; 8'h23: sbox_dec = 8'h32;
        8'h24: sbox_dec = 8'ha6; 8'h25: sbox_dec = 8'hc2; 8'h26: sbox_dec = 8'h23; 8'h27: sbox_dec = 8'h3d;
        8'h28: sbox_dec = 8'hee; 8'h29: sbox_dec = 8'h4c; 8'h2a: sbox_dec = 8'h95; 8'h2b: sbox_dec = 8'h0b;
        8'h2c: sbox_dec = 8'h42; 8'h2d: sbox_dec = 8'hfa; 8'h2e: sbox_dec = 8'hc3; 8'h2f: sbox_dec = 8'h4e;
        8'h30: sbox_dec = 8'h08; 8'h31: sbox_dec = 8'h2e; 8'h32: sbox_dec = 8'ha1; 8'h33: sbox_dec = 8'h66;
        8'h34: sbox_dec = 8'h28; 8'h35: sbox_dec = 8'hd9; 8'h36: sbox_dec = 8'h24; 8'h37: sbox_dec = 8'hb2;
        8'h38: sbox_dec = 8'h76; 8'h39: sbox_dec = 8'h5b; 8'h3a: sbox_dec = 8'ha2; 8'h3b: sbox_dec = 8'h49;
        8'h3c: sbox_dec = 8'h6d; 8'h3d: sbox_dec = 8'h8b; 8'h3e: sbox_dec = 8'hd1; 8'h3f: sbox_dec = 8'h25;
        8'h40: sbox_dec = 8'h72; 8'h41: sbox_dec = 8'hf8; 8'h42: sbox_dec = 8'hf6; 8'h43: sbox_dec = 8'h64;
        8'h44: sbox_dec = 8'h86; 8'h45: sbox_dec = 8'h68; 8'h46: sbox_dec = 8'h98; 8'h47: sbox_dec = 8'h16;
        8'h48: sbox_dec = 8'hd4; 8'h49: sbox_dec = 8'ha4; 8'h4a: sbox_dec = 8'h5c; 8'h4b: sbox_dec = 8'hcc;
        8'h4c: sbox_dec = 8'h5d; 8'h4d: sbox_dec = 8'h65; 8'h4e: sbox_dec = 8'hb6; 8'h4f: sbox_dec = 8'h92;
        8'h50: sbox_dec = 8'h6c; 8'h51: sbox_dec = 8'h70; 8'h52: sbox_dec = 8'h48; 8'h53: sbox_dec = 8'h50;
        8'h54: sbox_dec = 8'hfd; 8'h55: sbox_dec = 8'hed; 8'h56: sbox_dec = 8'hb9; 8'h57: sbox_dec = 8'hda;
        8'h58: sbox_dec = 8'h5e; 8'h59: sbox_dec = 8'h15; 8'h5a: sbox_dec = 8'h46; 8'h5b: sbox_dec = 8'h57;
        8'h5c: sbox_dec = 8'ha7; 8'h5d: sbox_dec = 8'h8d; 8'h5e: sbox_dec = 8'h9d; 8'h5f: sbox_dec = 8'h84;
        8'h60: sbox_dec = 8'h90; 8'h61: sbox_dec = 8'hd8; 8'h62: sbox_dec = 8'hab; 8'h63: sbox_dec = 8'h00;
        8'h64: sbox_dec = 8'h8c; 8'h65: sbox_dec = 8'hbc; 8'h66: sbox_dec = 8'hd3; 8'h67: sbox_dec = 8'h0a;
        8'h68: sbox_dec = 8'hf7; 8'h69: sbox_dec = 8'he4; 8'h6a: sbox_dec = 8'h58; 8'h6b: sbox_dec = 8'h05;
        8'h6c: sbox_dec = 8'hb8; 8'h6d: sbox_dec = 8'hb3; 8'h6e: sbox_dec = 8'h45; 8'h6f: sbox_dec = 8'h06;
        8'h70: sbox_dec = 8'hd0; 8'h71: sbox_dec = 8'h2c; 8'h72: sbox_dec = 8'h1e; 8'h73: sbox_dec = 8'h8f;
        8'h74: sbox_dec = 8'hca; 8'h75: sbox_dec = 8'h3f; 8'h76: sbox_dec = 8'h0f; 8'h77: sbox_dec = 8'h02;
        8'h78: sbox_dec = 8'hc1; 8'h79: sbox_dec = 8'haf; 8'h7a: sbox_dec = 8'hbd; 8'h7b: sbox_dec = 8'h03;
        8'h7c: sbox_dec = 8'h01; 8'h7d: sbox_dec = 8'h13; 8'h7e: sbox_dec = 8'h8a; 8'h7f: sbox_dec = 8'h6b;
        8'h80: sbox_dec = 8'h3a; 8'h81: sbox_dec = 8'h91; 8'h82: sbox_dec = 8'h11; 8'h83: sbox_dec = 8'h41;
        8'h84: sbox_dec = 8'h4f; 8'h85: sbox_dec = 8'h67; 8'h86: sbox_dec = 8'hdc; 8'h87: sbox_dec = 8'hea;
        8'h88: sbox_dec = 8'h97; 8'h89: sbox_dec = 8'hf2; 8'h8a: sbox_dec = 8'hcf; 8'h8b: sbox_dec = 8'hce;
        8'h8c: sbox_dec = 8'hf0; 8'h8d: sbox_dec = 8'hb4; 8'h8e: sbox_dec = 8'he6; 8'h8f: sbox_dec = 8'h73;
        8'h90: sbox_dec = 8'h96; 8'h91: sbox_dec = 8'hac; 8'h92: sbox_dec = 8'h74; 8'h93: sbox_dec = 8'h22;
        8'h94: sbox_dec = 8'he7; 8'h95: sbox_dec = 8'had; 8'h96: sbox_dec = 8'h35; 8'h97: sbox_dec = 8'h85;
        8'h98: sbox_dec = 8'he2; 8'h99: sbox_dec = 8'hf9; 8'h9a: sbox_dec = 8'h37; 8'h9b: sbox_dec = 8'he8;
        8'h9c: sbox_dec = 8'h1c; 8'h9d: sbox_dec = 8'h75; 8'h9e: sbox_dec = 8'hdf; 8'h9f: sbox_dec = 8'h6e;
        8'ha0: sbox_dec = 8'h47; 8'ha1: sbox_dec = 8'hf1; 8'ha2: sbox_dec = 8'h1a; 8'ha3: sbox_dec = 8'h71;
        8'ha4: sbox_dec = 8'h1d; 8'ha5: sbox_dec = 8'h29; 8'ha6: sbox_dec = 8'hc5; 8'ha7: sbox_dec = 8'h89;
        8'ha8: sbox_dec = 8'h6f; 8'ha9: sbox_dec = 8'hb7; 8'haa: sbox_dec = 8'h62; 8'hab: sbox_dec = 8'h0e;
        8'hac: sbox_dec = 8'haa; 8'had: sbox_dec = 8'h18; 8'hae: sbox_dec = 8'hbe; 8'haf: sbox_dec = 8'h1b;
        8'hb0: sbox_dec = 8'hfc; 8'hb1: sbox_dec = 8'h56; 8'hb2: sbox_dec = 8'h3e; 8'hb3: sbox_dec = 8'h4b;
        8'hb4: sbox_dec = 8'hc6; 8'hb5: sbox_dec = 8'hd2; 8'hb6: sbox_dec = 8'h79; 8'hb7: sbox_dec = 8'h20;
        8'hb8: sbox_dec = 8'h9a; 8'hb9: sbox_dec = 8'hdb; 8'hba: sbox_dec = 8'hc0; 8'hbb: sbox_dec = 8'hfe;
        8'hbc: sbox_dec = 8'h78; 8'hbd: sbox_dec = 8'hcd; 8'hbe: sbox_dec = 8'h5a; 8'hbf: sbox_dec = 8'hf4;
        8'hc0: sbox_dec = 8'h1f; 8'hc1: sbox_dec = 8'hdd; 8'hc2: sbox_dec = 8'ha8; 8'hc3: sbox_dec = 8'h33;
        8'hc4: sbox_dec = 8'h88; 8'h5c: sbox_dec = 8'h07; 8'hc6: sbox_dec = 8'hc7; 8'hc7: sbox_dec = 8'h31;
        8'hc8: sbox_dec = 8'hb1; 8'hc9: sbox_dec = 8'h12; 8'hca: sbox_dec = 8'h10; 8'hcb: sbox_dec = 8'h59;
        8'hcc: sbox_dec = 8'h27; 8'hcd: sbox_dec = 8'h80; 8'hce: sbox_dec = 8'hec; 8'hcf: sbox_dec = 8'h5f;
        8'hd0: sbox_dec = 8'h60; 8'hd1: sbox_dec = 8'h51; 8'hd2: sbox_dec = 8'h7f; 8'hd3: sbox_dec = 8'ha9;
        8'hd4: sbox_dec = 8'h19; 8'hd5: sbox_dec = 8'hb5; 8'hd6: sbox_dec = 8'h4a; 8'hd7: sbox_dec = 8'h0d;
        8'hd8: sbox_dec = 8'h2d; 8'hd9: sbox_dec = 8'he5; 8'hda: sbox_dec = 8'h7a; 8'hdb: sbox_dec = 8'h9f;
        8'hdc: sbox_dec = 8'h93; 8'hdd: sbox_dec = 8'hc9; 8'hde: sbox_dec = 8'h9c; 8'hdf: sbox_dec = 8'hef;
        8'he0: sbox_dec = 8'ha0; 8'he1: sbox_dec = 8'he0; 8'he2: sbox_dec = 8'h3b; 8'he3: sbox_dec = 8'h4d;
        8'he4: sbox_dec = 8'hae; 8'he5: sbox_dec = 8'h2a; 8'he6: sbox_dec = 8'hf5; 8'he7: sbox_dec = 8'hb0;
        8'he8: sbox_dec = 8'hc8; 8'he9: sbox_dec = 8'heb; 8'hea: sbox_dec = 8'hbb; 8'heb: sbox_dec = 8'h3c;
        8'hec: sbox_dec = 8'h83; 8'hed: sbox_dec = 8'h53; 8'hee: sbox_dec = 8'h99; 8'hef: sbox_dec = 8'h61;
        8'hf0: sbox_dec = 8'h17; 8'hf1: sbox_dec = 8'h2b; 8'hf2: sbox_dec = 8'h04; 8'hf3: sbox_dec = 8'h7e;
        8'hf4: sbox_dec = 8'hba; 8'hf5: sbox_dec = 8'h77; 8'hf6: sbox_dec = 8'hd6; 8'hf7: sbox_dec = 8'h26;
        8'hf8: sbox_dec = 8'he1; 8'hf9: sbox_dec = 8'h69; 8'hfa: sbox_dec = 8'h14; 8'hfb: sbox_dec = 8'h63;
        8'hfc: sbox_dec = 8'h55; 8'hfd: sbox_dec = 8'h21; 8'hfe: sbox_dec = 8'h0c; 8'hff: sbox_dec = 8'h7d;
        default: sbox_dec = 8'h00;
    endcase
endfunction

// Rcon (Round Constant) table
function automatic [31:0] rcon(input [3:0] round);
    case (round)
        4'd1:  rcon = 32'h01000000;
        4'd2:  rcon = 32'h02000000;
        4'd3:  rcon = 32'h04000000;
        4'd4:  rcon = 32'h08000000;
        4'd5:  rcon = 32'h10000000;
        4'd6:  rcon = 32'h20000000;
        4'd7:  rcon = 32'h40000000;
        4'd8:  rcon = 32'h80000000;
        4'd9:  rcon = 32'h1b000000;
        4'd10: rcon = 32'h36000000;
        default: rcon = 32'h00000000;
    endcase
endfunction

//-----------------------------------------------------------------------------
// Key Expansion for AES-256
//-----------------------------------------------------------------------------
always_comb begin
    // Initialize first 8 words from key
    for (int i = 0; i < 8; i++) begin
        w[i] = key_reg[32*i +: 32];
    end
    
    // Expand remaining words
    for (int i = 8; i < 60; i++) begin
        if (i % 8 == 0) begin
            // RotWord(SubWord(w[i-1])) ^ Rcon[i/8] ^ w[i-8]
            w[i] = {sbox_enc(w[i-1][23:16]), sbox_enc(w[i-1][15:8]), 
                    sbox_enc(w[i-1][7:0]), sbox_enc(w[i-1][31:24])} ^ rcon(i/8) ^ w[i-8];
        end else if (i % 8 == 4) begin
            // SubWord(w[i-1]) ^ w[i-8]
            w[i] = {sbox_enc(w[i-1][31:24]), sbox_enc(w[i-1][23:16]),
                    sbox_enc(w[i-1][15:8]), sbox_enc(w[i-1][7:0])} ^ w[i-8];
        end else begin
            // w[i-1] ^ w[i-8]
            w[i] = w[i-1] ^ w[i-8];
        end
    end
    
    // Generate round keys
    for (int r = 0; r <= Nr; r++) begin
        round_key[r] = {w[4*r+3], w[4*r+2], w[4*r+1], w[4*r]};
    end
end

//-----------------------------------------------------------------------------
// SubBytes transformation
//-----------------------------------------------------------------------------
function automatic [127:0] sub_bytes_enc(input [127:0] state);
    for (int i = 0; i < 16; i++) begin
        sub_bytes_enc[8*i +: 8] = sbox_enc(state[8*i +: 8]);
    end
endfunction

function automatic [127:0] sub_bytes_dec(input [127:0] state);
    for (int i = 0; i < 16; i++) begin
        sub_bytes_dec[8*i +: 8] = sbox_dec(state[8*i +: 8]);
    end
endfunction

//-----------------------------------------------------------------------------
// ShiftRows transformation
//-----------------------------------------------------------------------------
function automatic [127:0] shift_rows_enc(input [127:0] state);
    reg [7:0] temp [0:15];
    // Convert to matrix
    for (int i = 0; i < 4; i++) begin
        for (int j = 0; j < 4; j++) begin
            temp[4*j + i] = state[8*(4*i+j) +: 8];
        end
    end
    // Shift rows
    shift_rows_enc[127:120] = temp[0];  // Row 0: no shift
    shift_rows_enc[119:112] = temp[5];  // Row 1: shift 1
    shift_rows_enc[111:104] = temp[10]; // Row 2: shift 2
    shift_rows_enc[103:96]  = temp[15]; // Row 3: shift 3
    shift_rows_enc[95:88]  = temp[4];
    shift_rows_enc[87:80]  = temp[9];
    shift_rows_enc[79:72]  = temp[14];
    shift_rows_enc[71:64]  = temp[3];
    shift_rows_enc[63:56]  = temp[8];
    shift_rows_enc[55:48]  = temp[13];
    shift_rows_enc[47:40]  = temp[2];
    shift_rows_enc[39:32]  = temp[7];
    shift_rows_enc[31:24]  = temp[12];
    shift_rows_enc[23:16]  = temp[1];
    shift_rows_enc[15:8]   = temp[6];
    shift_rows_enc[7:0]    = temp[11];
endfunction

function automatic [127:0] shift_rows_dec(input [127:0] state);
    reg [7:0] temp [0:15];
    // Convert to matrix
    for (int i = 0; i < 4; i++) begin
        for (int j = 0; j < 4; j++) begin
            temp[4*j + i] = state[8*(4*i+j) +: 8];
        end
    end
    // Inverse shift rows
    shift_rows_dec[127:120] = temp[0];
    shift_rows_dec[119:112] = temp[13];
    shift_rows_dec[111:104] = temp[10];
    shift_rows_dec[103:96]  = temp[7];
    shift_rows_dec[95:88]  = temp[4];
    shift_rows_dec[87:80]  = temp[1];
    shift_rows_dec[79:72]  = temp[14];
    shift_rows_dec[71:64]  = temp[11];
    shift_rows_dec[63:56]  = temp[8];
    shift_rows_dec[55:48]  = temp[5];
    shift_rows_dec[47:40]  = temp[2];
    shift_rows_dec[39:32]  = temp[15];
    shift_rows_dec[31:24]  = temp[12];
    shift_rows_dec[23:16]  = temp[9];
    shift_rows_dec[15:8]   = temp[6];
    shift_rows_dec[7:0]    = temp[3];
endfunction

//-----------------------------------------------------------------------------
// MixColumns transformation (using Galois Field multiplication)
//-----------------------------------------------------------------------------
function automatic [7:0] gf_mult_2(input [7:0] a);
    gf_mult_2 = (a[7]) ? ((a << 1) ^ 8'h1b) : (a << 1);
endfunction

function automatic [7:0] gf_mult_3(input [7:0] a);
    gf_mult_3 = gf_mult_2(a) ^ a;
endfunction

function automatic [31:0] mix_column_enc(input [31:0] col);
    reg [7:0] a, b, c, d;
    a = col[31:24];
    b = col[23:16];
    c = col[15:8];
    d = col[7:0];
    
    mix_column_enc[31:24] = gf_mult_2(a) ^ gf_mult_3(b) ^ c ^ d;
    mix_column_enc[23:16] = a ^ gf_mult_2(b) ^ gf_mult_3(c) ^ d;
    mix_column_enc[15:8]  = a ^ b ^ gf_mult_2(c) ^ gf_mult_3(d);
    mix_column_enc[7:0]   = gf_mult_3(a) ^ b ^ c ^ gf_mult_2(d);
endfunction

function automatic [31:0] mix_column_dec(input [31:0] col);
    reg [7:0] a, b, c, d;
    reg [7:0] a2, b2, c2, d2;
    a = col[31:24];
    b = col[23:16];
    c = col[15:8];
    d = col[7:0];
    
    a2 = gf_mult_2(a);
    b2 = gf_mult_2(b);
    c2 = gf_mult_2(c);
    d2 = gf_mult_2(d);
    
    // Inverse MixColumns: multiply by {0e, 0b, 0d, 09}
    mix_column_dec[31:24] = gf_mult_2(gf_mult_2(gf_mult_2(a) ^ a)) ^ gf_mult_2(gf_mult_2(b) ^ b) ^ gf_mult_2(c2 ^ c) ^ (gf_mult_2(gf_mult_2(d2)) ^ d);
    mix_column_dec[23:16] = (gf_mult_2(gf_mult_2(a2)) ^ a) ^ gf_mult_2(gf_mult_2(gf_mult_2(b) ^ b)) ^ gf_mult_2(gf_mult_2(c) ^ c) ^ (gf_mult_2(d2) ^ d);
    mix_column_dec[15:8]  = (gf_mult_2(a2) ^ a) ^ (gf_mult_2(b2) ^ b) ^ gf_mult_2(gf_mult_2(gf_mult_2(c) ^ c)) ^ (gf_mult_2(gf_mult_2(d2) ^ d) ^ d);
    mix_column_dec[7:0]   = (gf_mult_2(gf_mult_2(a2) ^ a) ^ a) ^ (gf_mult_2(b2) ^ b) ^ (gf_mult_2(c2) ^ c) ^ gf_mult_2(gf_mult_2(gf_mult_2(d) ^ d));
endfunction

function automatic [127:0] mix_columns_enc(input [127:0] state);
    mix_columns_enc[127:96] = mix_column_enc(state[127:96]);
    mix_columns_enc[95:64]  = mix_column_enc(state[95:64]);
    mix_columns_enc[63:32]  = mix_column_enc(state[63:32]);
    mix_columns_enc[31:0]   = mix_column_enc(state[31:0]);
endfunction

function automatic [127:0] mix_columns_dec(input [127:0] state);
    mix_columns_dec[127:96] = mix_column_dec(state[127:96]);
    mix_columns_dec[95:64]  = mix_column_dec(state[95:64]);
    mix_columns_dec[63:32]  = mix_column_dec(state[63:32]);
    mix_columns_dec[31:0]   = mix_column_dec(state[31:0]);
endfunction

//-----------------------------------------------------------------------------
// AddRoundKey transformation
//-----------------------------------------------------------------------------
function automatic [127:0] add_round_key(input [127:0] state, input [127:0] rk);
    add_round_key = state ^ rk;
endfunction

//-----------------------------------------------------------------------------
// State Machine and Processing Logic
//-----------------------------------------------------------------------------
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        round_cnt <= 0;
        state_reg <= 0;
        key_reg <= 0;
        ready_out <= 1'b1;
        valid_out <= 1'b0;
        data_out <= 0;
    end else begin
        state <= next_state;
        round_cnt <= round_cnt_next;
        state_reg <= state_next;
        ready_out <= (next_state == IDLE);
        valid_out <= (next_state == DONE);
        
        if (next_state == DONE) begin
            data_out <= state_reg;
        end
        
        if (valid_in && state == IDLE) begin
            key_reg <= key;
        end
    end
end

always_comb begin
    next_state = state;
    round_cnt_next = round_cnt;
    state_next = state_reg;
    
    case (state)
        IDLE: begin
            if (valid_in) begin
                next_state = KEY_EXPAND;
                state_next = data_in;
                round_cnt_next = 0;
            end
        end
        
        KEY_EXPAND: begin
            // Key expansion is combinational, proceed to first round
            next_state = PROCESS_ROUNDS;
            state_next = add_round_key(state_reg, round_key[0]);
            round_cnt_next = 1;
        end
        
        PROCESS_ROUNDS: begin
            if (round_cnt < Nr) begin
                if (encrypt) begin
                    state_next = add_round_key(
                        mix_columns_enc(shift_rows_enc(sub_bytes_enc(state_reg))),
                        round_key[round_cnt]
                    );
                end else begin
                    state_next = add_round_key(
                        sub_bytes_dec(shift_rows_dec(mix_columns_dec(state_reg))),
                        round_key[round_cnt]
                    );
                end
                round_cnt_next = round_cnt + 1;
            end else begin
                next_state = FINAL_ROUND;
            end
        end
        
        FINAL_ROUND: begin
            if (encrypt) begin
                state_next = add_round_key(
                    shift_rows_enc(sub_bytes_enc(state_reg)),
                    round_key[Nr]
                );
            end else begin
                state_next = add_round_key(
                    sub_bytes_dec(shift_rows_dec(state_reg)),
                    round_key[Nr]
                );
            end
            next_state = DONE;
        end
        
        DONE: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule
