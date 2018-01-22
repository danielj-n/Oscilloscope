library IEEE;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_1164.ALL;

use work.oscPackage.ALL;


entity SPIScreenUpdate is
	port (data_out, clk_out, dc, cs, status_out: out std_logic; threshold_in : in unsigned(0 to 7); hysteresis_in : in std_logic_vector(0 to 7); x_in : in unsigned(0 to 8); y_in : in unsigned(0 to 7); data_in : in std_logic_vector(0 to 0); CLOCK, begin_in, switch_ram_in, RESET : in std_logic);
end entity SPIScreenUpdate; 

architecture SPIScreenUpdateArch of SPIScreenUpdate is 
 
	signal LCDSPI_enable_clock : std_logic; 
	signal LCDSPI_enable_clock_control : std_logic; 
	constant LCDSPI_prescaler : unsigned(0 to 7) := to_unsigned(2, 8);  
	signal LCDSPI_clk_count : integer;   
	signal total_clock_cycles : unsigned (0 to 63);
	signal millis : unsigned(0 to 7);  
	constant CLOCK_freq : integer := 12000000; 
	constant millis_divider : integer := 12000;
	constant setup_command_or_data : std_logic_vector(0 to 72) := B"1110100100101001010101000010000101010100000000000000010000000000000001110";  
	type values is array (integer range <>) of std_logic_vector (0 to 7);
	constant setup_values : values (0 to 72) := (X"01", X"11", X"26", X"04", X"b1", X"0b", X"14", X"c0", X"08", X"00", X"c1", X"05", X"c5", X"41", X"30", X"c7", X"c1", X"ec", X"1b", X"3a", X"55", X"2a", X"00", X"00", X"00", X"7f", X"2b", X"00", X"00", X"00", X"9f", X"36", X"c8", X"b7", X"00", X"f2", X"00", X"e0", X"28", X"24", X"22", X"31", X"2b", X"0e", X"53", X"a5", X"42", X"16", X"18", X"12", X"1a", X"14", X"03", X"e1", X"17", X"1b", X"1d", X"0e", X"14", X"11", X"2c", X"a5", X"3d", X"09", X"27", X"2d", X"25", X"2b", X"3c", X"13", X"29", X"36", X"A8");
	
	type int_array is array (integer range <>) of unsigned(0 to 7); 
    	constant setup_delays : int_array(0 to 72) := (	to_unsigned(50, 8), to_unsigned(100, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(100, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(50, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(0, 8), to_unsigned(50, 8), to_unsigned(10, 8), to_unsigned(255, 8), to_unsigned(0, 8), to_unsigned(0, 8) );  
	signal setup_num : unsigned(0 to 7);
	signal delay_time : unsigned(0 to 7);

	signal LCDSPI_status: oscSPIStatus;  
	signal LCDSPI_data : std_logic_vector(0 to 7); 
	signal LCDSPI_begin, LCDSPI_command_or_data: std_logic;
	
	type byte_vector is array (integer range <>) of std_logic_vector(0 to 7);
	constant start_output_command_list : byte_vector(0 to 10) := (X"2A", X"00", X"00", X"00", X"9F", X"2B", X"00", X"00", X"00", X"7F", X"2C");
	constant start_output_command_or_data : std_logic_vector := B"10000100001";
	signal start_output_byte : unsigned(0 to 7) := to_unsigned(0, 8);
	
	type drawingState is (BEGIN_POWERUP, SETTING_UP_POWERUP, OUTPUTTING_POWERUP, DELAYING_POWERUP, FINISHED, OUTPUTTING_START, WAITING_START, BEGIN_DATA, OUTPUTTING_DATA, WAITING_DATA);
	signal drawing_state : drawingState := FINISHED;
	
	type integer_vector is array (integer range <>) of unsigned(0 to 7);
	type ramAddr_vector is array (integer range <>) of std_logic_vector(0 to 15);
	type ramIO_vector is array (integer range <>) of std_logic_vector(0 to 0);
	signal ram_output : ramIO_vector(0 to 3) ;
	signal ram_input : ramIO_vector(0 to 3); 
	signal ram_addr : ramAddr_vector(0 to 3);
	signal ram_write : std_logic_vector(0 to 3);
	
	signal ram_to_erase : unsigned(0 to 2);
	signal ram_to_read : unsigned(0 to 2);
	signal ram_to_write : unsigned(0 to 2);
	signal ram_to_edit : unsigned(0 to 2);
	
	signal switched_this_round : std_logic; 
	signal restart_ram : std_logic;
	
begin 
	LCDSPIController : entity work.LCDSPI(LCDSPIArch)
		port map (data_out, clk_out, dc, cs, LCDSPI_status, LCDSPI_data, CLOCK, LCDSPI_begin, RESET, LCDSPI_command_or_data, LCDSPI_enable_CLOCK);
	
	pixelRam0 : entity work.pixelRam2(pixelRam2Arch)
		port map (CLOCK, '1', RESET, ram_write(0), ram_addr(0), ram_input(0), ram_output(0));
		
	pixelRam1 : entity work.pixelRam2(pixelRam2Arch)
		port map (CLOCK, '1', RESET, ram_write(1), ram_addr(1), ram_input(1), ram_output(1));
		
	pixelRam2 : entity work.pixelRam2(pixelRam2Arch)
		port map (CLOCK, '1', RESET, ram_write(2), ram_addr(2), ram_input(2), ram_output(2));
		
	pixelRam3 : entity work.pixelRam2(pixelRam2Arch)
		port map (CLOCK, '1', RESET, ram_write(3), ram_addr(3), ram_input(3), ram_output(3));
	
	generateLCDSPIClock : process (CLOCK, RESET) 
	begin
		if (RESET = '1') then
			LCDSPI_clk_count <= 0; 
		elsif (CLOCK = '1' and CLOCK'event) then 
			LCDSPI_clk_count <= LCDSPI_clk_count + 1; 
			if (LCDSPI_clk_count = to_integer(LCDSPI_prescaler) - 1) then
				LCDSPI_clk_count <= 0;
				LCDSPI_enable_CLOCK_control <= '1';
			else
				LCDSPI_enable_CLOCK_control <= '0';
			end if;	
		end if;
	end process generateLCDSPIClock;
	
	controlLCDSPIClock : process (LCDSPI_enable_CLOCK_control, RESET) 
	begin	
		if (RESET = '1') then
			LCDSPI_enable_CLOCK <= '0';
		else
			LCDSPI_enable_CLOCK <=LCDSPI_enable_CLOCK_control;
		end if;
	end process controlLCDSPIClock;
	
	countMilliseconds : process (CLOCK, RESET) 
	begin
		if (RESET = '1') then
			total_clock_cycles <= to_unsigned(0, 64);
			millis <= to_unsigned(0, 8); 
		elsif (CLOCK = '1' and CLOCK'event) then 
			total_clock_cycles <= total_clock_cycles + 1;
			if (total_clock_cycles = to_unsigned(millis_divider, 64)) then
				millis <= millis + 1;
				total_clock_cycles <= to_unsigned(0, 64);
			end if; 
		end if;
	end process countMilliseconds;
	
	updateScreen : process (CLOCK, RESET)
		variable temp : std_logic_vector(0 to 15);
	begin
		if (RESET = '1') then
			delay_time <= to_unsigned(0, 8);
			setup_num <=  to_unsigned(0, 8);
			drawing_state <= BEGIN_POWERUP;
			status_out <= '0'; 
			start_output_byte <= to_unsigned(0, 8);
			for ram_num in 0 to 3 loop
				ram_write(ram_num) <= '0';
				ram_addr(ram_num) <= (others => '0');
				ram_input(ram_num) <= (others => '0');
			end loop;
		elsif(CLOCK'event and CLOCK = '1') then
			case drawing_state is
				when BEGIN_POWERUP =>
					LCDSPI_data <= setup_values(to_integer(setup_num));
					LCDSPI_command_or_data <= setup_command_or_data(to_integer(setup_num));
					LCDSPI_begin <= '1';
					
					drawing_state <= SETTING_UP_POWERUP;
				when SETTING_UP_POWERUP =>
					if (LCDSPI_status = LOADED) then
						LCDSPI_begin <= '0'; 
						
						drawing_state <= OUTPUTTING_POWERUP;
					end if;
				when OUTPUTTING_POWERUP =>
					if (LCDSPI_status = COMPLETE) then
						delay_time <= millis + setup_delays(to_integer(setup_num));
						drawing_state <= DELAYING_POWERUP;
					end if;
				when DELAYING_POWERUP =>
					if (millis >= delay_time) then
						delay_time <= to_unsigned(0, 8); 
						if (setup_num /= to_unsigned(72, 8)) then
							drawing_state <= BEGIN_POWERUP;
							setup_num <= setup_num + to_unsigned(1, 8);
						else 
							status_out <= '1';
							drawing_state <= FINISHED;
						end if;
					end if;
					
				when FINISHED =>
					if (begin_in = '1') then
						status_out <= '0';
						
						LCDSPI_data <= start_output_command_list(0);
						LCDSPI_command_or_data <= start_output_command_or_data(0);
						LCDSPI_begin <= '1';
						start_output_byte <= start_output_byte + 1;
						
						drawing_state <= OUTPUTTING_START;
					else 
						LCDSPI_begin <= '0';
					end if;
				when OUTPUTTING_START =>
					if (LCDSPI_status = OUTPUTTING) then
						LCDSPI_begin <= '0';
						
						if (start_output_byte /= 11) then
							drawing_state <= WAITING_START;
						else 
							start_output_byte <= to_unsigned(0, 8);
							drawing_state <= BEGIN_DATA;
						end if;
					end if;
				when WAITING_START =>
					if (LCDSPI_status = COMPLETE) then
						LCDSPI_data <= start_output_command_list(to_integer(start_output_byte));
						LCDSPI_command_or_data <= start_output_command_or_data(to_integer(start_output_byte));
						LCDSPI_begin <= '1';
						start_output_byte <= start_output_byte + 1;
						
						drawing_state <= OUTPUTTING_START;
					end if;
				when BEGIN_DATA =>
					ram_addr(to_integer(ram_to_read)) <= (others => '0');
					if (LCDSPI_status = COMPLETE) then 
						if (ram_output(to_integer(ram_to_read)) = B"1") then
							LCDSPI_data <= B"11111111";
						else 
							LCDSPI_data <= B"00000000";
						end if;
						LCDSPI_command_or_data <= '0';
						LCDSPI_begin <= '1';
						 
						ram_addr(to_integer(ram_to_read)) <= std_logic_vector(unsigned(ram_addr(to_integer(ram_to_read)))+to_unsigned(128, 16));
						drawing_state <= WAITING_DATA; 
					end if;
				when OUTPUTTING_DATA =>
					if (LCDSPI_status = OUTPUTTING) then
						temp := std_logic_vector(unsigned(ram_addr(to_integer(ram_to_read)))+to_unsigned(128, 16)); 
						if (temp /= std_logic_vector(to_unsigned(41087, 16))) then
							if (unsigned(temp and std_logic_vector(shift_left(to_unsigned(511, 16), 7))) = to_unsigned(40960, 16)) then 
								ram_addr(to_integer(ram_to_read)) <= std_logic_vector((unsigned(ram_addr(to_integer(ram_to_read))) and to_unsigned(127, 16)) + to_unsigned(1, 16)); 
							else 
								ram_addr(to_integer(ram_to_read)) <= temp;
							end if;
							drawing_state <= WAITING_DATA;
						else 
							ram_addr(to_integer(ram_to_read)) <= (others => '0'); 
							status_out <= '1';
							drawing_state <= FINISHED;
						end if;
						
					end if; 
				when WAITING_DATA => 
					if (LCDSPI_status = LOADED) then 
						if (ram_output(to_integer(ram_to_read)) = B"1") then
							LCDSPI_data <= B"11111111";
						else 
							LCDSPI_data <= B"00000000";
						end if;
						LCDSPI_command_or_data <= '0';
						LCDSPI_begin <= '1';
						
						drawing_state <= OUTPUTTING_DATA;
					end if;
			end case;
				
			ram_write(to_integer(ram_to_write)) <= '1';
			ram_addr(to_integer(ram_to_write)) <= std_logic_vector(to_unsigned((to_integer(y_in) + to_integer(shift_left(to_unsigned(to_integer(x_in), 16), 7))), 16)); 
			ram_input(to_integer(ram_to_write)) <= data_in;

			if (restart_ram = '1') then
				ram_write(to_integer(ram_to_erase)) <= '1';
				ram_input(to_integer(ram_to_erase)) <= B"0";
				ram_addr(to_integer(ram_to_erase)) <= (others => '0');
			elsif (unsigned(ram_addr(to_integer(ram_to_erase))) /= to_unsigned(40960, 16)) then
				ram_addr(to_integer(ram_to_erase)) <= std_logic_vector(unsigned(ram_addr(to_integer(ram_to_erase))) + to_unsigned(1, 16));
			else 
				ram_write(to_integer(ram_to_erase)) <= '0';
			end if;
			
			if (restart_ram = '1') then 
				ram_write(to_integer(ram_to_edit)) <= '1';
				ram_input(to_integer(ram_to_edit)) <= B"0";
				ram_addr(to_integer(ram_to_edit)) <= (others => '0');
				if (threshold_in /= to_unsigned(255, 8)) then
					ram_addr(to_integer(ram_to_edit)) <= std_logic_vector(to_unsigned((to_integer(threshold_in) - to_integer(unsigned(hysteresis_in))), 16)); 
				else 
					ram_write(to_integer(ram_to_edit)) <= '0';
				end if;
			elsif ((unsigned((ram_addr(to_integer(ram_to_edit))) and std_logic_vector(shift_left(to_unsigned(511, 16), 7))) /= to_unsigned(40960, 16)) and (threshold_in /= to_unsigned(255, 8))) then 
				if (unsigned((ram_addr(to_integer(ram_to_edit))) and std_logic_vector(to_unsigned(128, 16))) = to_unsigned(0, 16)) then 
					ram_input(to_integer(ram_to_edit)) <= B"1"; 
				else 
					ram_input(to_integer(ram_to_edit)) <= B"1"; 
				end if;
				ram_addr(to_integer(ram_to_edit)) <= std_logic_vector(unsigned(ram_addr(to_integer(ram_to_edit))) + to_unsigned(128, 16));
			else
				report integer'Image(to_integer(unsigned(ram_addr(to_integer(ram_to_edit)))));
				if (to_integer(unsigned(ram_addr(to_integer(ram_to_edit)) and std_logic_vector(to_unsigned(127, 16)))) /= to_integer(unsigned(threshold_in)) + to_integer(unsigned(hysteresis_in))) then
					ram_addr(to_integer(ram_to_edit)) <= std_logic_vector(to_unsigned((to_integer(unsigned(ram_addr(to_integer(ram_to_edit)) and std_logic_vector(to_unsigned(127, 16)))) + 1), 16));
				else
					ram_write(to_integer(ram_to_edit)) <= '0';
				end if;
			end if;	
		end if; 
	end process; 
	
	switchRam : process (CLOCK, RESET) 
	begin
		if (RESET = '1') then 
			ram_to_read <= to_unsigned(0, 3); 
			ram_to_erase <= to_unsigned(1, 3);
			ram_to_write <= to_unsigned(2, 3);
			ram_to_edit <= to_unsigned(3, 3);
		elsif (CLOCK'event and CLOCK = '1') then
			if (switch_ram_in = '1') then
				ram_to_erase <= ram_to_read;
				ram_to_read <= ram_to_edit;
				ram_to_write <= ram_to_erase;
				ram_to_edit <= ram_to_write;
				restart_ram <= '1';
			else
				restart_ram <= '0';
			end if;
		end if;
	end process switchRam;
	 
end architecture SPIScreenUpdateArch;
