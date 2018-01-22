

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.oscPackage.ALL;


entity SPI is 
	port (data_out, clk_out: out std_logic; status_out : out oscSPIStatus; data_in : in std_logic_vector(0 to 7); CLOCK, begin_in, RESET, enable_CLOCK: in std_logic);
end entity SPI;

architecture SPIArch of SPI is 
	type SPIState is (waiting, writing); 
	signal current_state : SPIState := waiting;  
	
	subtype byteCount is integer range 0 to 8;  
	signal current_bit : integer := 0;  
	
	signal data_set : std_logic := '0'; 
	
	signal data_to_write : std_logic_vector(0 to 7);

	
begin  
	shiftOut : process (CLOCK, RESET)   
	begin 
		if (RESET = '1') then
			current_bit <= 0;  
			data_set <= '0'; 
			clk_out <= '0';  
			data_out  <= '0'; 
			status_out <= COMPLETE;
			current_state <= waiting;
			data_to_write <= B"00000000";
		elsif (CLOCK = '1' and CLOCK'event) then  
			if (enable_CLOCK = '1') then
				case current_state is
					when waiting =>
						if (begin_in = '1') then
							status_out <= LOADED; 
							current_state <= writing;
							data_to_write <= data_in;
						end if;
					when writing =>
						status_out <= OUTPUTTING;
						if (current_bit /= 8) then
							if (data_set = '1') then  
								clk_out <= '1';
								data_set <= '0';
								current_bit <= current_bit + 1;
							end if;
							if (data_set = '0') then
								data_out <= data_to_write(current_bit);
								clk_out <= '0';
								data_set <= '1'; 
							end if; 
						elsif (begin_in = '1') then
							data_out <= data_in(0);
							clk_out <= '0'; 
							current_bit <= 0;
							status_out <= LOADED;
							data_set <= '1';
							current_state <= writing;
							data_to_write <= data_in;
						else
							data_out <= '0';
							clk_out <= '0'; 
							current_bit <= 0;  
							status_out <= COMPLETE;
							data_set <= '0';
							current_state <= waiting; 
							data_to_write <= B"00000000";
						end if;
				end case; 
			end if;
		end if;
	end process shiftOut;
end architecture SPIArch;
