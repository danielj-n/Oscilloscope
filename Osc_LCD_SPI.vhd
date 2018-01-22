library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.oscPackage.ALL;

entity LCDSPI is
	port (data_out, clk_out, dc, cs : out std_logic; status_out : out oscSPIStatus; data_in : in std_logic_vector(0 to 7); CLOCK, begin_in, RESET, command_or_data, enable_CLOCK : in std_logic);
end entity LCDSPI;

architecture LCDSPIArch of LCDSPI is

signal begin_spi : std_logic;
signal status_spi : oscSPIStatus;
signal start_spi : std_logic;

type SPIWritingState is (FINISHED, STARTING, OUTPUTTING);
signal SPI_write_state : SPIWritingState := FINISHED;

begin
	SPIControl : entity work.SPI(SPIArch) 
		port map (data_out, clk_out, status_spi, data_in, CLOCK, begin_spi, RESET, enable_CLOCK); 
		
	process (CLOCK, RESET) 

	begin	  
		if (RESET = '1') then
			SPI_write_state <= FINISHED;
			dc <= '0';
			cs <= '1';
		elsif (CLOCK = '1' and CLOCK'event) then
			case SPI_write_state is
				when FINISHED =>
					if (enable_CLOCK = '1' and begin_in = '1') then 
						if (command_or_data = '1') then 
							dc <= '0'; 
							cs <= '0';
						else
							dc <= '1'; 
							cs <= '0';
						end if;
						start_spi <= '1';
						SPI_write_state <= STARTING;
					end if;
				when STARTING =>
					if (enable_CLOCK = '1') then
						start_spi <= '0';
						SPI_write_state <= OUTPUTTING;
					end if;
				when OUTPUTTING =>
					if (status_spi = COMPLETE) then 
						cs <= '1';
						SPI_write_state <= FINISHED;
					end if; 
			end case;
		end if; 
	end process; 
	
	updateSPIStatus : process (status_spi, start_spi, begin_in) 
	begin
		status_out <= status_spi;
		if (start_spi = '1') then
			begin_spi <= '1';
		elsif (begin_in = '0') then
			begin_spi <= '0';
		end if;
	end process updateSPIStatus;
	
end architecture LCDSPIArch; 
