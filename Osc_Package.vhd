library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package oscPackage is
	type oscSPIStatus is (COMPLETE, LOADED, OUTPUTTING);
	type bit_vector_2D is array (integer range <>, integer range <>) of std_logic; 
end package; 