library IEEE;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_1164.ALL;

use work.oscPackage.ALL;

entity controller is
	port (	data_out : out std_logic;
			clk_out : out std_logic;
			dc : out std_logic;
			cs : out std_logic; 
			ADC_in : in std_logic_vector(0 to 7);
			threshold_in : in std_logic_vector(0 to 7);
			CLOCK : in std_logic;
			RESET : in std_logic; 
			LED_OUT : out std_logic; 
			ADC_RD : out std_logic;
			ADC_CONVST : out std_logic; 
			ADC_EOC : in std_logic;
			ADCSPI_data_out : out std_logic;
			ADCSPI_clk_out : out std_logic;
			ADCSPI_cs : out std_logic;
			ADCSPI_data_in : in std_logic;
			test_out : out std_logic	);
end entity controller;

 
architecture controllerArch of controller is
signal frame_state_in : std_logic;

signal SPI_screen_updater_status : std_logic;
signal SPI_screen_updater_x : unsigned(0 to 8);
signal SPI_screen_updater_y : unsigned(0 to 7);
signal SPI_screen_updater_data : std_logic_vector(0 to 0);
signal SPI_screen_updater_threshold : unsigned(0 to 7);
signal SPI_screen_updater_hysteresis : std_logic_vector(0 to 7);
signal SPI_screen_updater_begin : std_logic;
signal SPI_screen_updater_switch_ram : std_logic;

type controllerState is (setting_up, waiting, writing);
signal controller_state : controllerState;
signal frame_state_seen : std_logic;
signal sample_num : integer;
signal trigger : std_logic;
signal triggerable : std_logic;
signal ADC_read : unsigned(0 to 7);

signal frame_refresh_seen : std_logic;
signal sample_width_read : integer;
type outputterState is (waiting, outputting);
signal outputter_state : outputterState;
signal threshold_old : unsigned(0 to 7);
signal frames_since_threshold_touched : unsigned(0 to 7);
signal draw_threshold : std_logic;
signal threshold_read : unsigned(0 to 7);
signal hysteresis_read : unsigned(0 to 7);

type ADCUpdateState is (waiting_for_conversion, read_in_data, delay, reset_part_1, reset_part_2);
type ADCUpdateState_vector is array (integer range <>) of ADCUpdateState;
constant ADC_update_states : ADCUpdateState_vector(0 to 5) := (waiting_for_conversion, read_in_data, delay, reset_part_1, delay, reset_part_2);
signal ADC_update_state_index : integer;
signal ADC_update_state : ADCUpdateState;

signal ADCSPI_address : std_logic_vector(0 to 2);
signal ADCSPI_begin : std_logic;
signal ADCSPI_status : std_logic;
signal ADCSPI_data_read : std_logic_vector (0 to 7);

type potADCObjectToRead is (threshold_val, sample_width_lower_val, sample_width_upper_val, hysteresis_val);
signal pot_ADC_object_to_read : potADCObjectToRead;

type updatePotADCState is (start_conversion, wait_for_SPI_to_finish);
signal update_pot_ADC_state : updatePotADCState;

signal test_output_counter : std_logic_vector (0 to 15);

signal sample_width_constant : std_logic_vector (0 to 31);
signal sample_width_constant_divisor : std_logic_vector (0 to 31);
signal sample_width_constant_divider : std_logic_vector (0 to 31);
signal sample_width_constant_output : std_logic_vector (0 to 31);
signal sample_width_constant_status : std_logic;
signal sample_width_constant_begin : std_logic;
type calculateSampleWidthState is (waiting, beginning_calculation);
signal calculate_sample_width_state : calculateSampleWidthState;
signal sample_width : std_logic_vector (0 to 31);


begin 	
	SPIScreenUpdater : entity work.SPIScreenUpdate(SPIScreenUpdateArch)
		port map (	data_out, 
					clk_out, 
					dc, 
					cs, 
					SPI_screen_updater_status, 
					SPI_screen_updater_threshold, 
					SPI_screen_updater_hysteresis,
					SPI_screen_updater_x, 
					SPI_screen_updater_y, 
					SPI_screen_updater_data, 
					CLOCK, 
					SPI_screen_updater_begin, 
					SPI_screen_updater_switch_ram, 
					RESET	);
                                             
	potADCSPIUpdater : entity work.potADCSPI(potADCSPIArch)
		port map (	ADCSPI_data_out,
					ADCSPI_clk_out,
					ADCSPI_begin,
					ADCSPI_status,
					ADCSPI_cs,
					ADCSPI_address,
					ADCSPI_data_in,
					ADCSPI_data_read,
					CLOCK,
					RESET	);	
	
	sampleWidthDivider : entity work.divider(dividerArch)
		port map (	CLOCK,
					RESET,
					sample_width_constant_divider,
					sample_width_constant_divisor,
					sample_width_constant_begin,
					sample_width_constant_output,	
					sample_width_constant_status	);
	
		
	updateScreen : process (CLOCK, RESET)
		variable x : unsigned(0 to 8);
		variable y : unsigned(0 to 7);

	begin
		if (RESET = '1') then
			SPI_screen_updater_data <= (others => '0');
			SPI_screen_updater_x <= to_unsigned(0, 9);
			SPI_screen_updater_y <= to_unsigned(0, 8);
			SPI_screen_updater_begin <= '0';
			SPI_screen_updater_threshold <= to_unsigned(255, 8);
			SPI_screen_updater_hysteresis <= X"00";
			SPI_screen_updater_switch_ram <= '0';
			controller_state <= setting_up;
			frame_state_seen <= '0';
			sample_num <= 0;
			frame_refresh_seen <= '1'; 
			outputter_state <= waiting;
			threshold_old <= to_unsigned(0, 8);
			frames_since_threshold_touched <= to_unsigned(0, 8);
			draw_threshold <= '1';
		elsif (CLOCK = '1' and CLOCK'event) then
			case controller_state is
				when setting_up =>
					if (SPI_screen_updater_status = '1' and frame_state_in = '1') then
						controller_state <= waiting;
						frame_state_seen <= '1';
					end if;

				when waiting =>
					if (trigger = '1') then
						sample_num <= 0;
						controller_state <= writing;
					end if;
					
				when writing => 
					
					x := to_unsigned((to_integer(shift_left(shift_right(to_unsigned((sample_num * to_integer(unsigned(sample_width_constant))), 32), 20), 1))), 9); 
					y := shift_right(ADC_read, 1); 
					SPI_screen_updater_data <= B"1";
					SPI_screen_updater_x <= x;
					SPI_screen_updater_y <= y; 
					
					if (sample_num = to_integer(unsigned(sample_width)) - 1) then
						controller_state <= waiting;
					else 
						sample_num <= sample_num + 1;
					end if;
			end case;
			
			if (controller_state = waiting or controller_state = writing) then
				case outputter_state is 
					when waiting =>
						if (frame_state_in = '1' and frame_refresh_seen = '0') then
							frame_refresh_seen <= '1';
							controller_state <= waiting;
							SPI_screen_updater_switch_ram <= '1';
							outputter_state <= outputting;
							if (threshold_read /= threshold_old ) then 
								frames_since_threshold_touched <= to_unsigned(0, 8);
								SPI_screen_updater_threshold <= threshold_read; 
								SPI_screen_updater_hysteresis <= std_logic_vector(hysteresis_read);
								threshold_old <= threshold_read;
								draw_threshold <= '1';
							elsif (draw_threshold = '1') then
								frames_since_threshold_touched <= frames_since_threshold_touched + to_unsigned(1, 8);
								SPI_screen_updater_threshold <= threshold_read; 
								SPI_screen_updater_hysteresis <= std_logic_vector(hysteresis_read);
								if (frames_since_threshold_touched = to_unsigned(30, 8)) then
									SPI_screen_updater_threshold <= to_unsigned(255, 8);
									frames_since_threshold_touched <= to_unsigned(0, 8);
									draw_threshold <= '0';
								end if;
							end if;
						end if;
						SPI_screen_updater_begin <= '0';
					when outputting =>
						SPI_screen_updater_x <= to_unsigned(0, 9);
						SPI_screen_updater_y <= to_unsigned(0, 8);
						SPI_screen_updater_data <= B"0";
						SPI_screen_updater_begin <= '1'; 
						outputter_state <= waiting;
						SPI_screen_updater_switch_ram <= '0';
				end case;
				if (frame_state_in = '0' and frame_refresh_seen = '1') then
					frame_refresh_seen <= '0';
				end if;
			end if;
		end if;
	end process;

	
	triggerControl : process (CLOCK, RESET)
	begin
		if (RESET = '1') then
			triggerable <= '0';
			trigger <= '0';
		elsif (rising_edge(CLOCK)) then
		
			if (trigger = '1') then
				trigger <= '0';
			end if;
		
			if ( (to_integer(shift_right(ADC_read, 1)) > to_integer(threshold_read) + to_integer(hysteresis_read)) and (triggerable = '1') ) then
				trigger <= '1';
				triggerable <= '0';
			end if;
			
			if ( (to_integer(shift_right(ADC_read, 1)) < to_integer(threshold_read) -  to_integer(hysteresis_read)) and (triggerable = '0' ) ) then
				triggerable <= '1';
			end if;
		end if;
		
	end process triggerControl;

	
	updatePotADCRead : process (CLOCK, RESET)
		procedure readPotADCOutput is 
		begin
			case pot_ADC_object_to_read is 
				when threshold_val =>
					threshold_read <= shift_left(shift_right(unsigned(ADCSPI_data_read), 2), 1);
					pot_ADC_object_to_read <= sample_width_lower_val;
					ADCSPI_address <= B"000";
				when sample_width_lower_val =>
					sample_width_read <= to_integer(unsigned(std_logic_vector(to_unsigned(sample_width_read, 32)) and B"00000000000000001111100000000000")) + to_integer(shift_left(shift_right(to_unsigned(to_integer(unsigned(ADCSPI_data_read)), 16), 3), 6));
					pot_ADC_object_to_read <= sample_width_upper_val;
					ADCSPI_address <= B"001";
				when sample_width_upper_val =>
					sample_width_read <= to_integer(unsigned(std_logic_vector(to_unsigned(sample_width_read, 32)) and B"00000000000000000000011111111111")) + to_integer(shift_left(shift_right(to_unsigned(to_integer(unsigned(ADCSPI_data_read)), 16), 3), 11));
					pot_ADC_object_to_read <= hysteresis_val;                                                                              
					ADCSPI_address <= B"010";
				when hysteresis_val => 
					hysteresis_read <= shift_right(unsigned(ADCSPI_data_read), 2); 
					pot_ADC_object_to_read <= threshold_val;
					ADCSPI_address <= "011";
			end case;
		end procedure readPotADCOutput;
	
	begin
		if (RESET = '1') then
			update_pot_ADC_state <= start_conversion;
			ADCSPI_begin <= '0';
			pot_ADC_object_to_read <= threshold_val;
			sample_width_read  <= 1000;
			ADCSPI_address <= B"000";
		elsif (rising_edge(CLOCK)) then
			case update_pot_ADC_state is 
				when start_conversion =>
					ADCSPI_begin <= '1';
					if (ADCSPI_status = '0') then
						update_pot_ADC_state <= wait_for_SPI_to_finish;
					end if;
				when wait_for_SPI_to_finish =>
					if (ADCSPI_status = '1') then
						readPotADCOutput;
						update_pot_ADC_state <= start_conversion;
					end if;
			end case;
			if (ADCSPI_begin = '1' and ADCSPI_status = '0') then
				ADCSPI_begin <= '0';
			end if;
			if (sample_width_read < 32) then
				sample_width_read <= 32;
			end if;
		end if;
	end process updatePotADCRead;
	

	updateADCRead : process (CLOCK, RESET)
	procedure setADCUpdateStateIndex(index_val : integer) is 
	begin
		ADC_update_state_index <= index_val;
		ADC_update_state <= ADC_update_states(index_val);
	end procedure setADCUpdateStateIndex;
	
	begin
		if (RESET = '1') then
			ADC_RD <= '0';
			ADC_RD <= '1';
			ADC_update_state_index <= 3;
			ADC_CONVST <= '0';
			ADC_update_state <= reset_part_1;
			ADC_read <= to_unsigned(23, 8);
		elsif (rising_edge(CLOCK)) then
			case ADC_update_state is
				when waiting_for_conversion =>
					if (ADC_EOC = '1') then
						ADC_RD <= '0';
						setADCUpdateStateIndex(ADC_update_state_index + 1);
					end if;
				when read_in_data =>
					ADC_read <= unsigned(ADC_in);
					ADC_RD <= '1';
					setADCUpdateStateIndex(ADC_update_state_index + 1);
				when delay =>
					setADCUpdateStateIndex(ADC_update_state_index + 1);
				when reset_part_1 =>
					ADC_CONVST <= '1';
					setADCUpdateStateIndex(ADC_update_state_index + 1);
				when reset_part_2 =>
					ADC_CONVST <= '0';
					setADCUpdateStateIndex(0);
			end case;
		end if;
	end process updateADCRead;
	
	
	generateFrameClock : process(CLOCK, RESET)
		variable randomCounter : integer;
	begin
		if (RESET = '1') then
			frame_state_in <= '1';
			randomCounter := 0;
		elsif (rising_edge(CLOCK)) then
			randomCounter := randomCounter + 1;
			if (randomCounter = 1000000) then  
				randomCounter := 0;
				frame_state_in <= not frame_state_in;
			end if;
		end if; 
	end process generateFrameClock;
	

	generateTestOutput  : process (CLOCK, RESET) 
	begin	
		if (RESET = '1') then
			test_output_counter <= X"0000";
			test_out <= '0';
		elsif (rising_edge(CLOCK)) then
			test_output_counter <= std_logic_vector(unsigned(test_output_counter) + to_unsigned(1, 16));
			if (test_output_counter = X"0078") then
				test_out <= '1';
			elsif (test_output_counter = X"00F0") then
				test_out <= '0';
				test_output_counter <= X"0000";
			end if;
		end if;
	end process generateTestOutput;
	

	calculateSampleWidth : process (CLOCK, RESET)
	begin
		if (RESET = '1') then
			sample_width_constant_divisor <= std_logic_vector(to_unsigned(167772160, 32));
			sample_width_constant_divider <= X"00000001";
			calculate_sample_width_state <= waiting;
			sample_width_constant <= X"00000FFF";
			sample_width_constant_begin <= '0';
			led_out <= '1';
		elsif (rising_edge(CLOCK)) then
			case calculate_sample_width_state is 
				when waiting =>
					if (frame_state_in = '1' and frame_refresh_seen = '0' and sample_width_constant_status = '1') then
						led_out <= '0';
						sample_width_constant <= sample_width_constant_output;
						calculate_sample_width_state <= beginning_calculation;
						sample_width <= sample_width_constant_divider;
					end if;
				when beginning_calculation =>
					led_out <= '0';
					sample_width_constant_divider <= std_logic_vector(to_unsigned(sample_width_read, 32));
					sample_width_constant_begin <= '1';
					calculate_sample_width_state <= waiting;
			end case;
			if (sample_width_constant_begin = '1') then
				sample_width_constant_begin <= '0';
			end if;
		end if;
	end process calculateSampleWidth;
end architecture controllerArch;
