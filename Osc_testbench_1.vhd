library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity testBench1 is
end entity testBench1;

architecture testBench1Arch of testBench1 is

signal LED_OUT, data_out, clk_out, dc, cs, CLOCK, RESET, trigger_in, frame_state_in : std_logic := '0';
signal ADC_in, threshold_in, sample_width_in : std_logic_vector(0 to 7);
signal ADC_RD, ADC_CONVST, ADC_EOC : std_logic;
signal ADCSPI_data_out, ADCSPI_clk_out, ADCSPI_cs, ADCSPI_data_in : std_logic;
signal some_new_output : std_logic;
signal debug : std_logic_vector (0 to 31);


begin
	testing : entity work.controller(controllerArch)
		port map (data_out, clk_out, dc, cs, ADC_in, threshold_in, CLOCK, RESET, LED_OUT, ADC_RD, ADC_CONVST, ADC_EOC, ADCSPI_data_out, ADCSPI_clk_out, ADCSPI_cs, ADCSPI_data_in, some_new_output);
	
	process 
	begin
		RESET <= '1';
		ADC_in <= B"00001000";
		wait for 20 ns; 
		RESET <= '0';
		while (true) loop 
			wait for 20 ns;
			CLOCK <= not CLOCK;
		end loop;  
		
	end process; 
	
	process
	begin
		wait for 25000000 ns;
		frame_state_in <= not frame_state_in;
	end process;
	
	process
	begin
		wait for 20000 ns;
		trigger_in <= not trigger_in;
	end process;
	
	process
	begin
		if (ADC_CONVST = '1') then
			ADC_EOC <= '0';
			wait for 2000 ns;
			ADC_EOC <= '1';
		end if;
		wait for 1ns;
	end process;
	
	process (ADCSPI_clk_out, ADCSPI_cs, RESET)
		constant thingToWrite : std_logic_vector(0 to 16) := B"11111101111111111";
		variable index : integer := 0;
	begin
		if (RESET = '1') then
			ADCSPI_data_in <= '1';
		elsif (falling_edge(ADCSPI_clk_out) and ADCSPI_cs = '0') then
			ADCSPI_data_in <= thingToWrite(index);
			index := index + 1;
		elsif(ADCSPI_cs = '1') then
			index := 0;
		end if;
	end process;

end architecture testBench1Arch;
