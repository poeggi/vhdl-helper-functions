--
-- Project wide helper function definitions
--
---------------------------------------------------------------------
--
-- Author   : Kai Poggensee
-- Copyright: (C) 2024
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package helper-functions is
	function in_simulation return boolean;
	function sim_syn_var(SIM_VAR: natural; SYN_VAR: natural)
			return natural;

	function resize_msb(V: std_logic_vector; LEN: natural)
			return std_logic_vector;
	function resize_msb(V: unsigned; LEN: natural) return unsigned;

	function To_StdLogicVector(NUMBER: natural; LENGTH: natural)
			return std_logic_vector;

	function or_reduce(V: std_logic_vector)  return std_ulogic;
	function and_reduce(V: std_logic_vector) return std_ulogic;
	function xor_reduce(V: std_logic_vector) return std_ulogic;

	function slv(Len: natural; LEVEL: std_ulogic :='0')
			return std_logic_vector;
	function trim_right(UNTRIMMED: std_logic_vector; N: natural)
			return std_logic_vector;

	function log2_ceil(N: natural) return natural;

	function is_multiple(V:std_logic_vector; N:natural) return boolean;
	function is_multiple(V:unsigned; N:natural) return boolean;

	-- unconstrained array (unsigned) is "not allowed in this context",
	-- hence this solution instead
	type array_of_integer is array ( natural range <> ) of integer;
	function bubble_sort(UNSORTED: array_of_integer; ORDER: bit)
			return array_of_integer;
	function bubble_sort(UNSORTED: array_of_integer)
			return array_of_integer;
	
	function max3(A:integer; B:integer; C:integer) return integer;

end package;


package body helper-functions is

	-- helper to be able to tell if we are doing simulation or synthesis
	function in_simulation return boolean is
		variable SIM_TEST : bit := '0';
	begin
		-- synthesis translate_off
		SIM_TEST := '1'; -- only set during simulation
		-- synthesis translate_on
		return ('1' = SIM_TEST);
	end function;


	-- returns value SIM_VAR when in simulation, SYN_VAR during synthesis
	function sim_syn_var(SIM_VAR: natural; SYN_VAR: natural)
			return natural is
	begin
		if ( in_simulation ) then
			return SIM_VAR;
		else
			return SYN_VAR;
		end if;
	end function;


	-- 
	-- MSB aligned resizing (get part of a vector or extend)
	--
	function resize_msb(V: std_logic_vector; LEN: natural)
				return std_logic_vector is
	begin
		return std_logic_vector(resize_msb(unsigned(v), LEN));
	end function;

	function resize_msb(V: unsigned; LEN: natural)
				return unsigned is
		variable RET : unsigned(LEN-1 downto 0)
				:= (others => '0');
	begin
		if ( V'length >= LEN ) then
			RET := V((V'length-1) downto (V'length-LEN));
		else
			RET((LEN-1) downto (LEN-V'length)) := V;
		end if;

		return RET;
	end function;


	-- conversion function addition
	function To_StdLogicVector(NUMBER: natural; LENGTH: natural)
				return std_logic_vector is
	begin
		return std_logic_vector(to_unsigned(NUMBER, LENGTH));
	end function;


	-- 'or' all bits of an input vector into a single bit output
	-- i.e. if _any_ bit is set, the output is set
	function or_reduce(V: std_logic_vector) return std_ulogic is
		variable temp : std_ulogic := '0';
	begin
		for I in V'range loop
		   temp := temp or V(I);
		end loop;
		
		return temp;
	end function;


	-- 'and' all bits of an input vector into a single bit output
	-- i.e. only if _all_ bits are set, the output is set
	function and_reduce(V: std_logic_vector) return std_ulogic is
		variable temp : std_ulogic := '1';
	begin
		for I in V'range loop
		   temp := temp and V(I);
		end loop;
		
		return temp;
	end function;

 
	-- 'xor' all bits of an input vector into a single bit output
	function xor_reduce(V: std_logic_vector) return std_ulogic is
		variable temp : std_ulogic := '0';
	begin
		for I in V'range loop
		   temp := temp xor V(I);
		end loop;
		
		return temp;
	end function;


	function slv(Len: natural; LEVEL: std_ulogic :='0')
				return std_logic_vector is
		variable temp : std_logic_vector(Len-1 downto 0) := (others => LEVEL);
	begin
		return temp;
	end function;


	-- crop off unused address bits, replace them with 0
	function trim_right(UNTRIMMED: std_logic_vector; N: natural)
				return std_logic_vector is
	begin
		return (UNTRIMMED(UNTRIMMED'left downto N) &
			   ((UNTRIMMED'right+N)-1 downto UNTRIMMED'right => '0'));
	end;


	-- helper function to determine bit count (needed by e.g. vector)
	-- NOTE: N_max is natural'high which usually is 2**31-1
	function log2_ceil(N : natural) return natural is
		variable TEMP: natural;
		variable I: natural := 0;
	begin
		if (N = 0) then
			return 0;
		else
			TEMP := N;
			while (TEMP > 1) loop
				if (TEMP mod 2 /= 0) then
					TEMP := TEMP / 2;
					TEMP := TEMP + 1;
				else
					TEMP := TEMP / 2;
				end if;
				I := I + 1;
			end loop;
			return I;
		end if;
	end function;


	-- this function returns 'true' if a vector is a multiple
	-- of the natural number parameter (in power of 2)
	function is_multiple(V:std_logic_vector; N:natural)
				return boolean is
	begin
		if ( or_reduce(V(V'left downto log2_ceil(N)))='1' ) then
			return true;
		else
			return false;
		end if;
	end function;

	function is_multiple(V:unsigned; N:natural) return boolean is
	begin
		return is_multiple(std_logic_vector(V),N);
	end function;


	-- bubble-sort an array of integers
	-- Note: This should not be synthesized - only use w/ constants !!!
	--
	-- Parameter: a: a array of integers
	--			order: 0 = descending, 1 = ascending
	-- Return Value: the sorted array  
	--
	function bubble_sort(UNSORTED: array_of_integer; ORDER: bit)
				return array_of_integer is
		variable TEMP: integer;
		variable SORTED: array_of_integer(UNSORTED'range);
	begin
		-- fill the result array
		for I in 0 to UNSORTED'right-1 loop
			SORTED(I) := UNSORTED(I);
		end loop;
		 
		for I in SORTED'left to SORTED'right-1 loop
			for N in I to SORTED'right-1 loop
				if ( ORDER = '1' ) then -- ascending order
					if ( SORTED(N) < SORTED(N+1) ) then
						TEMP := SORTED(n);
						SORTED(N) := SORTED(N+1);
						SORTED(N+1) := TEMP;
					end if;
				 else -- descending order
					if ( SORTED(N) > SORTED(N+1) ) then
						TEMP := SORTED(n);
						SORTED(N) := SORTED(N+1);
						SORTED(N+1) := TEMP;
					end if;
				 end if;
			end loop;
		end loop;

		return SORTED;

	end function;


	-- wrapper - default to ascending order
	function bubble_sort(UNSORTED: array_of_integer)
				return array_of_integer is
	begin
		return bubble_sort(UNSORTED, '1');
	end function;

	-- maximum of three integer values
	function max3(A:integer; B:integer; C:integer) return integer is
		variable TEMP: integer;
	begin
		if (A >= B) then
			TEMP := A;
		else
			TEMP := B;
		end if;
		if (C > TEMP) then
			TEMP := C;
		end if;  
		return TEMP;
	end function;
	
end helper-functions;
