------------------------------------------------
-- Project:	Sudoku - Game
------------------------------------------------
-- Entity:	game_controller
-- Date:		14.05.2016
-- Description:
-- 	Handles the incoming instructions
------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.const_package.all;

entity game_controller is
	port(
		clk	      : in  std_logic;
		rst			: in  std_logic;
		instr_i		: in  CCU_CMD_TYPE;
		ram_dat_i	: in  std_logic_vector(5 downto 0);
		ram_adr_r	: out	std_logic_vector(7 downto 0);
		ram_adr_w	: out	std_logic_vector(7 downto 0);
		ram_dat_o	: out	std_logic_vector(5 downto 0);
		ram_we		: out	std_logic;
		load_game	: out std_logic;
		game_loaded	: in 	std_logic;
		game_solved	: out std_logic
	);	
end game_controller;

architecture rtl of game_controller is

	type ccu_state is (IDLE, LOADING, MOVING, SETTING, CHECKING);
	signal state_cur	: ccu_state := IDLE;
	signal state_nxt	: ccu_state;
	
	signal instr_reg	: CCU_CMD_TYPE := CMD_NOP;
	signal instr_nxt	: CCU_CMD_TYPE;
	
	signal game_solved_reg : std_logic := '0';
	signal game_solved_nxt : std_logic;
	
	-- current position
	signal cnt_x			: unsigned(3 downto 0) := "0101";
	signal cnt_y			: unsigned(3 downto 0) := "0101";
	
	signal tsk_cnt			: unsigned(1 downto 0) := (others => '0');
	signal tsk_sta			: std_logic_vector(1 downto 0) := (others => '0');
	signal tsk_stp			: std_logic := '0';
	
	-- RAM Access
	signal ram_adr_o		: std_logic_vector(7 downto 0);
	
	-- For Solution Checker
	signal check_game 	: std_logic;
	signal checked			: std_logic;
	signal correct			: std_logic;
	signal sc_ram_adr_o	: std_logic_vector(7 downto 0);
	signal sc_ram_dat_i	: std_logic_vector(5 downto 0);
	
begin

	-- Solution Checker
	checker : entity work.solution_checker
	port map (
		clk 			=> clk,
		rst 			=> rst,
		start 		=> check_game,
		done 			=> checked,
		correct 		=> correct,
		ram_adr_o	=> sc_ram_adr_o,
		ram_dat_i	=> ram_dat_i
	);
	

	process(clk)
	begin
		if rising_edge(clk) then
			if(rst = '1') then
				state_cur 			<= IDLE;
				instr_reg			<= CMD_NOP;
				game_solved_reg	<= '0';
			else
				state_cur 			<= state_nxt;
				instr_reg			<= instr_nxt;
				game_solved_reg	<= game_solved_nxt;
			end if;
		end if;
	end process;
	
	process(state_cur, instr_i, tsk_stp, instr_reg, game_loaded, checked, correct, game_solved_reg)
	begin
		state_nxt			<= state_cur;
		instr_nxt			<= instr_reg;
		game_solved_nxt	<= game_solved_reg;
		tsk_sta				<= "00";
		load_game			<= '0';
		check_game			<=	'0';
		
		case state_cur is
			when IDLE =>
				instr_nxt <= instr_i;
				
				case instr_i is
					when CMD_DEL	=> state_nxt <= SETTING;
					when CMD_1		=> state_nxt <= SETTING;
					when CMD_2		=> state_nxt <= SETTING;
					when CMD_3		=> state_nxt <= SETTING;
					when CMD_4		=> state_nxt <= SETTING;
					when CMD_5		=> state_nxt <= SETTING;
					when CMD_6		=> state_nxt <= SETTING;
					when CMD_7		=> state_nxt <= SETTING;
					when CMD_8		=> state_nxt <= SETTING;
					when CMD_9		=> state_nxt <= SETTING;
					when CMD_UP		=> state_nxt <= MOVING;
					when CMD_RGT	=> state_nxt <= MOVING;
					when CMD_DWN	=> state_nxt <= MOVING;
					when CMD_LFT	=> state_nxt <= MOVING;
					when CMD_DIV 	=> state_nxt <= LOADING;
					when others		=>	state_nxt <= IDLE;
				end case;
				
			when LOADING =>
			
				load_game	<= '1';
			
				if game_loaded = '1' then
					state_nxt <= IDLE;
				end if;
				
			when SETTING =>	-- todo: changes to setting mode when div key is pressed oO
				tsk_sta <= "01";
				if(tsk_stp = '1') then
					state_nxt <= CHECKING;
				end if;
				
			when CHECKING =>
				check_game <= '1';
				
				if checked = '1' then
					state_nxt <= IDLE;
					
					-- TODO: Display (in)correct solution
					if correct = '1' then
						-- Solution is correct
						game_solved_nxt <= '1';
						
					else
						-- Solution is not correct
						game_solved_nxt <= '0';
					end if;
				end if;
				
			when MOVING =>
				tsk_sta <= "10";
				if(tsk_stp = '1') then
					state_nxt <= IDLE;
				end if;
				
			when others =>
				null;
			
		end case;
	end process;
	
	process(clk)
		variable tmp_ram : std_logic_vector(5 downto 0);
		variable tmp_dat : std_logic_vector(5 downto 0);
	begin
		if rising_edge(clk) then
			if(tsk_sta = "01")then
				if(tsk_cnt = "00") then
					ram_adr_o	<= std_logic_vector(cnt_y - 1) & std_logic_vector(cnt_x - 1);
					tsk_stp		<= '0';
					
				elsif(tsk_cnt = "01") then
					tmp_ram		:= ram_dat_i;
					
					if(tmp_ram(4) = '0' and tmp_ram(3 downto 0) /= instr_reg(3 downto 0)) then
						tmp_dat	:= tmp_ram(5 downto 4) & instr_reg(3 downto 0);
					else
						tmp_dat	:= tmp_ram;
					end if;
					
					ram_dat_o	<= tmp_dat;
					ram_adr_w	<= std_logic_vector(cnt_y - 1) & std_logic_vector(cnt_x - 1);
					ram_we		<= '1';
					
				else
					ram_adr_o <= (others => '0');
					ram_adr_w <= (others => '0');
					ram_dat_o <= (others => '0');
					ram_we 	 <= '0';
				end if;
			
				if(tsk_cnt = "10") then
					tsk_cnt	<= "00";
					tsk_stp	<= '1';
				elsif(tsk_stp = '0') then
					tsk_cnt	<= tsk_cnt + 1;
				end if;
			
			elsif(tsk_sta = "10") then -- moving
				if(tsk_cnt = "00") then
					ram_adr_o	<= std_logic_vector(cnt_y - 1) & std_logic_vector(cnt_x - 1); -- lese das aktuelle feld
					tsk_stp		<= '0';
					
				elsif(tsk_cnt = "01") then
					tmp_ram		:= ram_dat_i;
					ram_adr_w	<= std_logic_vector(cnt_y - 1) & std_logic_vector(cnt_x - 1); -- schreibe das aktuelle feld
					
					if(instr_reg = CMD_UP) then
						if(cnt_y > 1) then
							tmp_dat		:= '0' & tmp_ram(4 downto 0); -- mark as not set
							ram_adr_o	<= std_logic_vector(cnt_y - 2) & std_logic_vector(cnt_x - 1); -- read value from new upper addr
							cnt_y			<= cnt_y - 1; -- veringere den aktuellen feld zähler nach oben
						else
							tmp_dat	:= tmp_ram;
						end if;
					
					elsif(instr_reg = CMD_RGT) then
						if(cnt_x < 9) then
							tmp_dat		:= '0' & tmp_ram(4 downto 0);
							ram_adr_o	<= std_logic_vector(cnt_y - 1) & std_logic_vector(cnt_x);
							cnt_x			<= cnt_x + 1;
						else
							tmp_dat	:= tmp_ram;
						end if;
						
					elsif(instr_reg = CMD_DWN) then
						if(cnt_y < 9) then
							tmp_dat		:= '0' & tmp_ram(4 downto 0);
							ram_adr_o	<= std_logic_vector(cnt_y) & std_logic_vector(cnt_x - 1);
							cnt_y			<= cnt_y + 1;
						else
							tmp_dat	:= tmp_ram;
						end if;
						
					elsif(instr_reg = CMD_LFT) then
						if(cnt_x > 1) then
							tmp_dat		:= '0' & tmp_ram(4 downto 0);
							ram_adr_o	<= std_logic_vector(cnt_y - 1) & std_logic_vector(cnt_x - 2);
							cnt_x			<= cnt_x - 1;
						else
							tmp_dat	:= tmp_ram;
						end if;
					end if;
					
					ram_dat_o	<= tmp_dat;
					ram_we		<= '1';
						
				elsif(tsk_cnt = "10") then
					tmp_ram		:= ram_dat_i;
					ram_dat_o	<= '1' & tmp_ram(4 downto 0); -- markiere das obere feld als gesetzt
					ram_adr_w	<= std_logic_vector(cnt_y - 1) & std_logic_vector(cnt_x - 1);
					ram_we		<= '1';
				else
					ram_adr_o <= (others => '0');
					ram_adr_w <= (others => '0');
					ram_dat_o <= (others => '0');
					ram_we 	 <= '0';
				end if;
			
				if(tsk_cnt = "11") then
					tsk_cnt	<= "00";
					tsk_stp	<= '1';
				elsif(tsk_stp = '0') then
					tsk_cnt	<= tsk_cnt + 1;
				end if;
			
			else
				ram_adr_o <= (others => '0');
				ram_adr_w <= (others => '0');
				ram_dat_o <= (others => '0');
				ram_we 	 <= '0';
			end if;
		end if;
	end process;
	
	game_solved <= game_solved_reg;
		
	-- MUX for address wire to RAM
	ram_adr_r 	<= sc_ram_adr_o when check_game = '1' else ram_adr_o;
	
end rtl;