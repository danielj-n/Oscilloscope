library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SPIReader is
	port (	status_out : out std_logic; 
		enable_CLOCK : in std_logic;
		data_in : in std_logic;
		CLOCK : in std_logic;
		RESET : in std_logic;
		data_out : out std_logic_vector(0 to 7);
		begin_in : in std_logic;
		SPI_out_clk_out_in : in std_logic);
end entity SPIReader;

Architecture SPIReaderArch of SPIReader is

	type SPIReadState is (waiting, reading);
	signal SPI_read_state : SPIReadState;
	signal num_of_reads : integer;
	
Begin

	SPIRead : process (clock, RESET)
	begin
		if (RESET = '1') then
			status_out <= '1';
			SPI_read_state <= waiting;
			num_of_reads <= 0;
			data_out <= B"00000000";
		elsif (rising_edge(CLOCK)) then
			if (enable_CLOCK = '1' and SPI_out_clk_out_in = '1') then 
				case SPI_read_state is
					when waiting =>
						if(begin_in = '1' and data_in = '0') then
							SPI_read_state <= reading;
							status_out <= '0';
							num_of_reads <= 0;
						end if;
					when reading => 
						if (num_of_reads = 7) then
							SPI_read_state <= waiting;
							status_out <= '1';
						end if;
						data_out(num_of_reads) <= data_in;
						num_of_reads <= num_of_reads + 1;
				end case;
			end if;
		end if;
	end process SPIRead;
end architecture SPIReaderArch;

	
