library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity Divider is 
	port (	CLOCK : in std_logic;
			RESET : in std_logic;
			divider_in : in std_logic_vector (0 to 31);
			divisor_in : in std_logic_vector (0 to 31);
			begin_in : in std_logic;
			output_out : out std_logic_vector (0 to 31);	
			status_out : out std_logic	);
end entity Divider;

architecture dividerArch of Divider is 

	signal divider : std_logic_vector (0 to 31);
	signal divisor : std_logic_vector (0 to 31);
	signal bit_num : std_logic_vector (0 to 7);
	signal output : std_logic_vector (0 to 31);

	type divisionState is (waiting, dividing, finishing);
	signal division_state : divisionState;
	

begin

	divide : process (CLOCK, RESET)
		variable temp : std_logic_vector(0 to 31);
	begin	
		if (RESET = '1') then
			division_state <= waiting;
			status_out <= '1';
			output <= X"00000000";
			output_out <= X"00000000";
		elsif (rising_edge(CLOCK)) then
			case division_state is 
				when waiting =>
					if (begin_in = '1') then
						divider <= divider_in;
						divisor <= divisor_in;
						bit_num <= X"20";
						division_state <= dividing;
						status_out <= '0';
					end if;
				when dividing =>
					temp := std_logic_vector(shift_right(unsigned(divisor), to_integer(unsigned(bit_num)))); 
					if (unsigned(temp) > unsigned(divider)) then
						output <= std_logic_vector(shift_left(unsigned(output), 1) + to_unsigned(1, 32));
						divisor <= std_logic_vector(unsigned(divisor) - shift_left(unsigned(divider), to_integer(unsigned(bit_num))));
					else
						output <= std_logic_vector(shift_left(unsigned(output), 1));
					end if;
					bit_num <= std_logic_vector(unsigned(bit_num) - to_unsigned(1, 8));
					if (bit_num = X"00") then
						division_state <= finishing;
					end if;
				when finishing =>
					output_out <= output;
					output <= X"00000000";
					division_state <= waiting;
					status_out <= '1';
			end case;
		end if;	
	end process divide;
end architecture dividerArch;
