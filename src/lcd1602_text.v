module lcd1602_text #(parameter num_commands = 4, 
                                      num_data_all = 32,  
                                      num_data_perline = 16, 
                                      num_in_data = 2,
                                      COUNT_MAX = 800000)
(   input clk,            
    input reset,          
    input ready_i,
    input [7:0] input_data1,
    input [7:0] input_data2, 
    output reg rs,        
    output reg rw,
    output enable,
    output ready2wr,    
    output reg [7:0] data
);

// Definir los estados del controlador
localparam IDLE = 3'b000;
localparam CONFIG_CMD1 = 3'b001;
localparam WR_STATIC_TEXT_1L = 3'b010;
localparam CONFIG_CMD2 = 3'b011;
localparam WR_STATIC_TEXT_2L = 3'b100;
localparam WR_IN_DATA = 3'b101;

localparam SET_CURSOR = 2'b00;
localparam WRITE = 2'b01;
localparam COUNT_DATA = 2'b10;

reg [2:0] fsm_state;
reg [2:0] next;
reg clk_16ms;
reg [$clog2(COUNT_MAX)-1:0] counter;
reg [1:0] wr_in_data_state;

// Comandos de configuración
localparam CLEAR_DISPLAY = 8'h01; 
localparam SHIFT_CURSOR_RIGHT = 8'h06;
localparam DISPON_CURSOROFF = 8'h0C;
localparam DISPON_CURSORBLINK = 8'h0E;
localparam LINES2_MATRIX5x8_MODE8bit = 8'h38;
localparam LINES2_MATRIX5x8_MODE4bit = 8'h28;
localparam LINES1_MATRIX5x8_MODE8bit = 8'h30;
localparam LINES1_MATRIX5x8_MODE4bit = 8'h20;
localparam START_2LINE = 8'hC0;

reg [7:0] binary_value;
reg [1:0] digit_counter;

// Definir un contador para controlar el envío de comandos
reg [$clog2(num_commands):0] command_counter;
// Definir un contador para controlar el envío de datos
reg [$clog2(num_data_perline):0] data_counter;
reg [$clog2(num_in_data):0] in_data_counter;

// Banco de registros
reg [7:0] static_text_mem [0: num_data_all-1];
reg [7:0] config_mem [0:num_commands-1]; 
reg [7:0] in_data_mem [0:num_in_data-1];
reg [7:0] in_cursors_mem [0:num_in_data-1];

initial begin
    fsm_state <= IDLE;
    command_counter <= 'b0;
    data_counter <= 'b0;
    rs <= 'b0;
    rw <= 0;
    data <= 'b0;
    clk_16ms <= 1'b0;
    counter <= 0;
    $readmemh("/home/oem/Documents/Lab4/data.txt", static_text_mem);    
	config_mem[0] <= LINES2_MATRIX5x8_MODE8bit;
	config_mem[1] <= SHIFT_CURSOR_RIGHT;
	config_mem[2] <= DISPON_CURSOROFF;
	config_mem[3] <= CLEAR_DISPLAY;
    wr_in_data_state <= 2'b00;
    in_cursors_mem[0] <= 8'h8D;
    in_cursors_mem[1] <= 8'hCD;  // Segunda línea, posición 13 (0x4D)
    in_data_counter <= 'b0;
    digit_counter <= 'b0;
    binary_value <= 'b0;
end

always @(posedge clk) begin
    if (counter == COUNT_MAX-1) begin
        clk_16ms <= ~clk_16ms;
        counter <= 0;
    end else begin
        counter <= counter + 1;
    end
end


always @(posedge clk_16ms)begin
    if(reset == 0)begin
        fsm_state <= IDLE;
    end else begin
        fsm_state <= next;
    end
end

always @(*) begin
    case(fsm_state)
        IDLE: begin
            next <= (ready_i)? CONFIG_CMD1 : IDLE;
        end
        CONFIG_CMD1: begin 
            next <= (command_counter == num_commands)? WR_STATIC_TEXT_1L : CONFIG_CMD1;
        end
        WR_STATIC_TEXT_1L:begin
            if (data_counter == num_data_perline) begin
				if (config_mem[0] == LINES2_MATRIX5x8_MODE8bit) begin
				    next <= CONFIG_CMD2;
				end else begin
					next <= IDLE;
				end
            end else next = WR_STATIC_TEXT_1L;
        end
        CONFIG_CMD2: begin 
            next <= WR_STATIC_TEXT_2L;
        end
		WR_STATIC_TEXT_2L: begin
			next <= (data_counter == num_data_perline)? WR_IN_DATA : WR_STATIC_TEXT_2L;
		end
        WR_IN_DATA: begin
            next <= (ready_i == 0)? IDLE : WR_IN_DATA;
        end
        default: next = IDLE;
    endcase
end

// Asignar el estado inicial
always @(posedge clk_16ms) begin
    if (reset == 0) begin
        command_counter <= 'b0;
        data_counter <= 'b0;
		data <= 'b0;
        wr_in_data_state <= 2'b00;
        in_data_counter <= 'b0;
        digit_counter <= 'b0;
        binary_value <= 'b0;
        $readmemh("/home/oem/Documents/Lab4/data.txt", static_text_mem);
    end else begin
        case (next)
            IDLE: begin
                command_counter <= 'b0;
                data_counter <= 'b0;
                data <= 'b0;
                rs <= 'b0;
            end
            CONFIG_CMD1: begin
                command_counter <= command_counter + 1;
				rs <= 0; 
			    data <= config_mem[command_counter];
            end
            WR_STATIC_TEXT_1L: begin
                data_counter <= data_counter + 1;
                rs <= 1; 
				data <= static_text_mem[data_counter];
            end
            CONFIG_CMD2: begin
                data_counter <= 'b0;
				rs <= 0; 
                data <= START_2LINE;
            end
			WR_STATIC_TEXT_2L: begin
                data_counter <= data_counter + 1;
                rs <= 1; 
				data <= static_text_mem[num_data_perline + data_counter];
            end
            WR_IN_DATA: begin
                case (wr_in_data_state)
                    SET_CURSOR: begin
                        rs <= 0;
                        data <= in_cursors_mem[in_data_counter];
                        wr_in_data_state <= WRITE;
                    end
                    WRITE:begin
                        rs <= 1;
                        binary_value = in_data_mem[in_data_counter];
                        case(digit_counter)
                            2'b00: data <= (binary_value / 100) + 8'h30;  // Convertir centena a ASCII
                            2'b01:data <= ((binary_value % 100) / 10) + 8'h30;  // Convertir decena a ASCII
                            2'b10:data <= (binary_value % 10) + 8'h30;  // Convertir unidad a ASCII
                        endcase
                        if (digit_counter == 2) begin
                            wr_in_data_state <= COUNT_DATA;
                            digit_counter = 0;
                        end else begin
                            digit_counter = digit_counter + 1;
                        end
                    end
                    COUNT_DATA:begin
                        rs <= 1;
                        digit_counter = 0;
                        wr_in_data_state <= SET_CURSOR;
                        if (in_data_counter == num_in_data-1) begin
                            in_data_counter <= 0;
                        end else begin
                            in_data_counter = in_data_counter + 1;
                        end
                    end
                endcase
            end
        endcase
    end
end

assign enable = clk_16ms;

always @(posedge clk) begin
    in_data_mem[0] <= input_data1;
    in_data_mem[1] <= input_data2;
end

assign ready2wr = (fsm_state == WR_IN_DATA);
endmodule
