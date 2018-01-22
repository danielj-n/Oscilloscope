library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.oscPackage.ALL;
       
entity potADCSPI is 
	port (	SPI_out_data_out : out std_logic;
			SPI_out_clk_out : out std_logic;
			begin_in : in std_logic;
			status_out : out std_logic;
			cs_out : out std_logic;
			address_in : in std_logic_vector(0 to 2);
			SPI_in_data_in : std_logic;
			SPI_in_data_out : out std_logic_vector (0 to 7);
			CLOCK : in std_logic;
			RESET : in std_logic);
		
end entity potADCSPI;

architecture potADCSPIArch of potADCSPI is 

	type SPIControlState is (	signalling_beginning, 
					starting_SPI, 
					waiting_for_first_SPI_load_in,
					waiting_to_start_second_transfer, 
					waiting_for_second_SPI_load_in,
					waiting_to_end	);
								
	signal SPI_control_state : SPIControlState;
	signal SPI_out_status : oscSPIStatus;
	signal SPI_out_begin : std_logic;
	signal enable_CLOCK : std_logic;
	signal SPI_out_data_in : std_logic_vector(0 to 7);
	signal SPI_in_status : std_logic;
	signal SPI_in_begin : std_logic;
	signal CLOCK_count : integer;
	signal SPI_out_clk : std_logic;
	constant CLOCK_divider : integer := 100;
	
begin

	SPIOut : entity work.SPI(SPIArch)
	port map (SPI_out_data_out, SPI_out_clk, SPI_out_status, SPI_out_data_in, CLOCK, SPI_out_begin, RESET, enable_CLOCK);
		
	SPIIn : entity work.SPIReader(SPIReaderArch)
		port map (	SPI_in_status,
				enable_CLOCK,
				SPI_in_data_in,
				CLOCK,
				RESET,
				SPI_in_data_out,
				SPI_in_begin,
				SPI_out_clk	);
	
	
	SPIControl : process (CLOCK, RESET)
	
		procedure begin_SPI(to_send : std_logic_vector(0 to 7)) is 
		begin
			SPI_out_data_in <= to_send;
			SPI_out_begin <= '1';
			SPI_in_begin <= '1';
		end procedure begin_SPI;
		
		procedure signal_beginning is
		begin
			status_out <= '0';
			cs_out <= '0';
		end procedure signal_beginning;
		
		procedure signal_ending is
		begin
			status_out <= '1';
			cs_out <= '1';
		end procedure signal_ending;
		
	begin
		if (RESET = '1') then
			cs_out <= '1';
			status_out <= '1';
			spi_control_state <= signalling_beginning;			
			
		elsif (rising_edge(CLOCK)) then
			case SPI_control_state is
				
				when signalling_beginning =>
					if (enable_CLOCK = '1') then
						signal_beginning;
						SPI_control_state <= starting_SPI;
					end if;
				
				when starting_SPI =>
					begin_SPI(std_logic_vector(shift_left(to_unsigned(to_integer(unsigned(address_in)), 8), 3)) or B"11000000"); 
					SPI_control_state <= waiting_for_first_SPI_load_in;
				
				when waiting_for_first_SPI_load_in =>
					if (SPI_out_status = LOADED) then
						SPI_out_begin <= '0';
						SPI_control_state <= waiting_to_start_second_transfer;
					end if;

				when waiting_to_start_second_transfer =>
					if (SPI_out_status = COMPLETE) then
						begin_SPI(B"00000000");
						SPI_control_state <= waiting_for_second_SPI_load_in;
					end if;
				
				when waiting_for_second_SPI_load_in =>
					if (SPI_out_status = LOADED) then
						SPI_out_begin <= '0';
						SPI_control_state <= waiting_to_end;
					end if;
				
				when waiting_to_end =>
					if (SPI_out_status = COMPLETE and SPI_in_status = '1') then
						signal_ending;
						SPI_control_state <= signalling_beginning;
					end if;
			end case;
			
			if (SPI_in_begin = '1' and SPI_in_status = '0') then
				SPI_in_begin <= '0';
			end if;
			
		end if;
		
	end process SPIControl;
	
	SPIClockGen : process (CLOCK, RESET)
	begin
		if (RESET = '1') then
			enable_CLOCK <= '0';
			CLOCK_count <= 0;
		elsif (rising_edge(CLOCK)) then
			CLOCK_count <= CLOCK_count + 1;
			if (CLOCK_count = CLOCK_divider)
			then
				enable_CLOCK <= '1';
				CLOCK_count <= 0;
			end if;
			if (enable_CLOCK = '1') then
				enable_CLOCK <= '0';
			end if;
		end if;
	end process SPIClockGen;
	
	SPIOutClkOut : process (SPI_out_clk)
	begin
		SPI_out_clk_out <= SPI_out_clk;
	end process SPIOutClkOut;
				
end architecture potADCSPIArch;
