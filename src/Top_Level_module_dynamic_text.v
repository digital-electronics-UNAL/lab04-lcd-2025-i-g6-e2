
// Top-level module: dynamic text insertion
module lcd_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  data1,        // dinámico 1
    input  wire [7:0]  data2,        // dinámico 2
    output wire        lcd_rs,
    output wire        lcd_rw,
    output wire        lcd_e,
    output wire [3:0]  lcd_db        // modo 4 bits
);

    // Señal de habilitación para refresco (detecta cambio)
    wire refresh;
    reg  [7:0] prev1, prev2;

    // Detecta cambio en data1/data2
    assign refresh = (data1 != prev1) || (data2 != prev2);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev1 <= 8'd0;
            prev2 <= 8'd0;
        end else if (refresh) begin
            prev1 <= data1;
            prev2 <= data2;
        end
    end

    // Instancia del controlador LCD
    lcd_controller #(
        .INIT_TEXT1("Hello, UNAL!"),  // ejemplo de texto estático
        .INIT_TEXT2("Lab04 Part2")
    ) u_lcd_ctrl (
        .clk        (clk),
        .rst_n      (rst_n),
        .refresh    (refresh),
        .dyn1       (data1),
        .dyn2       (data2),
        .rs         (lcd_rs),
        .rw         (lcd_rw),
        .e          (lcd_e),
        .db         (lcd_db)
    );

endmodule


