// Testbench con estímulos dinámicos (Part 2)
`timescale 1ns/1ps
module tb_lcd;
    reg         clk;
    reg         rst_n;
    reg  [7:0]  data1_tb;
    reg  [7:0]  data2_tb;
    wire        lcd_rs;
    wire        lcd_rw;
    wire        lcd_e;
    wire [3:0]  lcd_db;

    // Instancia DUT
    lcd_top uut (
        .clk    (clk),
        .rst_n  (rst_n),
        .data1  (data1_tb),
        .data2  (data2_tb),
        .lcd_rs (lcd_rs),
        .lcd_rw (lcd_rw),
        .lcd_e  (lcd_e),
        .lcd_db (lcd_db)
    );

    // Generador de reloj
    initial clk = 0;
    always #10 clk = ~clk;

    initial begin
        // Reset
        rst_n = 0;
        #100;
        rst_n = 1;

        // Valores iniciales dinámicos
        data1_tb = 8'h3C;
        data2_tb = 8'hA7;
        #200000;

        // Cambiar valores
        data1_tb = 8'h1F;
        data2_tb = 8'hB2;
        #200000;

        $stop;
    end
endmodule