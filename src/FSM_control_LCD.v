// FSM de control de LCD con texto estático y dinámico
module lcd_controller #(
    parameter string INIT_TEXT1 = "                ",
    parameter string INIT_TEXT2 = "                "
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        refresh,
    input  wire [7:0]  dyn1,
    input  wire [7:0]  dyn2,
    output reg         rs,
    output reg         rw,
    output reg         e,
    output reg  [3:0]  db
);

    // Estados de la FSM
    typedef enum logic [4:0] {
        ST_RESET,
        ST_INIT1, ST_INIT1_WAIT,
        ST_INIT2, ST_INIT2_WAIT,
        ST_TEXT1, ST_TEXT1_WAIT,
        ST_TEXT2, ST_TEXT2_WAIT,
        ST_POS_DYN,          // posiciona para dinámicos
        ST_HI1, ST_HI1_WAIT,
        ST_LO1, ST_LO1_WAIT,
        ST_SEP,              // opcional
        ST_HI2, ST_HI2_WAIT,
        ST_LO2, ST_LO2_WAIT,
        ST_IDLE
    } state_t;
    state_t state, next_state;

    // Contador de retardos
    reg [19:0] delay_cnt;
    wire delay_done = (delay_cnt == 20'd0);

    // Registro de nibble a enviar
    reg [3:0] nibble;
    reg [7:0] ascii;

    // Conversión nibble->ASCII
    function automatic [7:0] nibble2ascii(input [3:0] nib);
        if (nib < 4'd10)
            nibble2ascii = 8'h30 + nib;
        else
            nibble2ascii = 8'h41 + (nib - 4'd10);
    endfunction

    // FSM secuencial
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_RESET;
            delay_cnt <= 20'd0;
        end else begin
            state <= next_state;
            if (delay_cnt != 20'd0)
                delay_cnt <= delay_cnt - 1;
        end
    end

    // FSM combinacional
    always @(*) begin
        // Defaults
        rs = 1'b0; rw = 1'b0; e = 1'b0; db = nibble;
        ascii = 8'd0;
        next_state = state;

        case (state)
            ST_RESET: begin
                delay_cnt = 20'd100000;  // espera reset
                next_state = ST_INIT1;
            end
            // --- Texto estático línea 1 ---
            ST_INIT1: begin
                // comando Set DDRAM addr inicio línea1
                rs = 1'b0; db = 4'h0; e = 1'b1;
                next_state = ST_INIT1_WAIT;
            end
            ST_INIT1_WAIT: if (delay_done) next_state = ST_TEXT1;
            ST_TEXT1: begin
                rs = 1'b1;
                ascii = INIT_TEXT1[state - ST_INIT1]; // simplificación
                nibble = ascii[7:4]; e = 1'b1;
                next_state = ST_TEXT1_WAIT;
            end
            ST_TEXT1_WAIT: if (delay_done) next_state = ST_INIT2;
            // Similar para INIT2/TEXT2... omito detalles
            // --- Posicionar cursor dinámico ---
            ST_POS_DYN: begin
                // Set DDRAM addr para pos libre
                rs = 1'b0; db = 4'hC; e = 1'b1;
                next_state = ST_HI1;
            end
            // --- Escribir dyn1 high nibble ---
            ST_HI1: begin
                ascii = nibble2ascii(dyn1[7:4]);
                rs = 1'b1; nibble = ascii[7:4]; e = 1'b1;
                next_state = ST_HI1_WAIT;
            end
            ST_HI1_WAIT: if (delay_done) next_state = ST_LO1;
            // --- dyn1 low nibble ---
            ST_LO1: begin
                ascii = nibble2ascii(dyn1[3:0]);
                rs = 1'b1; nibble = ascii[7:4]; e = 1'b1;
                next_state = ST_LO1_WAIT;
            end
            ST_LO1_WAIT: if (delay_done) next_state = ST_HI2;
            // --- dyn2 high nibble ---
            ST_HI2: begin
                ascii = nibble2ascii(dyn2[7:4]);
                rs = 1'b1; nibble = ascii[7:4]; e = 1'b1;
                next_state = ST_HI2_WAIT;
            end
            ST_HI2_WAIT: if (delay_done) next_state = ST_LO2;
            // --- dyn2 low nibble ---
            ST_LO2: begin
                ascii = nibble2ascii(dyn2[3:0]);
                rs = 1'b1; nibble = ascii[7:4]; e = 1'b1;
                next_state = ST_LO2_WAIT;
            end
            ST_LO2_WAIT: if (delay_done) next_state = ST_IDLE;
            // --- Espera refresh ---
            ST_IDLE: begin
                if (refresh) next_state = ST_POS_DYN;
            end
            default: next_state = ST_RESET;
        endcase
    end
endmodule