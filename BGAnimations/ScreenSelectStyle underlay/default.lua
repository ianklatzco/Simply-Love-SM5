local StyleSelected = false
local af

local current_game = GAMESTATE:GetCurrentGame():GetName()
------------------------------------------------------------------------------------

-- KNOWN BUG: enabling solo will make routine/couples inaccessible.

-- WideScale is a builtin in _fallback/Scripts/02 Utilities.lua
-- I believe it scales your coordinates to WideScreen.

local xshift = WideScale(42,52)
local choices = {
	{ 
		name="single",
			-- used to pick game mode via engine functions
		pads={{3, -xshift-14}},
			-- passed to drawNinePanelPad(color, xoffset)
			-- xoffset is the offset of the pad relative to text
		x=_screen.w/4-_screen.w/8
			-- moves to be 1/4 of the screen left of the center
	},

	{ 
		name="versus",
		pads={{2, -xshift-WideScale(60,70)}, {5, xshift-WideScale(60,70)}},
		x=(_screen.w/4)*2-_screen.w/8
	},

	{ 
		name="double",
		pads={{4,-xshift-WideScale(60,70)}, {4, xshift-WideScale(60,70)}},
		x=(_screen.w/4)*3-_screen.w/8 },

	{ 
		name="routine",
		pads= {{2,-xshift-WideScale(60,70) }, {5, xshift-WideScale(60,70) } },
		x=_screen.w-_screen.w/8
	},
}

-- If solo is enabled in Options > Simply Love settings,
-- replace the couples option with the solo option.
-- This isn't really the best solution, but I'm pretty doubtful
-- that people would want to use both solo and couples
-- (They'd probably need 18 panel pads.) -ian
if current_game=="dance" and ThemePrefs.Get("AllowDanceSolo") then
	choices[1].x = _screen.w/4-_screen.w/8
	choices[2].x = (_screen.w/4)*2-_screen.w/8
	choices[3].x = (_screen.w/4)*3-_screen.w/8
	choices[4] = { name="solo", pads={ {3, -xshift-14}}, x=_screen.w-_screen.w/8 }

-- double/routine is not a valid style in kb7 and para
elseif current_game=="kb7" or current_game=="para" then
	choices[1].x = _screen.cx-_screen.w/6
	choices[2].x = _screen.cx+_screen.w/6
	table.remove(choices, 3)
	table.remove(choices, 4)
end



-- either 1 (single) or 2 (versus)
local current_index = #GAMESTATE:GetHumanPlayers()

------------------------------------------------------------------------------------

local EnableChoices = function()

	-- everything is enabled
	if PREFSMAN:GetPreference("EventMode")
	or GAMESTATE:GetCoinMode() ~= "CoinMode_Pay"
	or GAMESTATE:GetCoinMode() == "CoinMode_Pay" and GAMESTATE:GetPremium() == "Premium_2PlayersFor1Credit" then
		for i, child in ipairs( af:GetChild("") ) do
			child.Enabled = true
		end
	end

	-- double for 1 credit
	if GAMESTATE:GetCoinMode() == "CoinMode_Pay" and GAMESTATE:GetPremium() == "Premium_DoubleFor1Credit" then
		-- if both players are already joined, disable 1 Player as a choice
		af:GetChild("")[1].Enabled = (#GAMESTATE:GetHumanPlayers() == 1)

		af:GetChild("")[3].Enabled = true

		if GAMESTATE:EnoughCreditsToJoin()
		or #GAMESTATE:GetHumanPlayers() == 2 then
			af:GetChild("")[2].Enabled = true
			af:GetChild("")[4].Enabled = true
		end
	end

	-- premium off
	if GAMESTATE:GetCoinMode() == "CoinMode_Pay" and GAMESTATE:GetPremium() == "Premium_Off" then
		-- if both players are already joined, disable 1 Player as a choice
		af:GetChild("")[1].Enabled = (#GAMESTATE:GetHumanPlayers() == 1)

		if GAMESTATE:EnoughCreditsToJoin()
		or #GAMESTATE:GetHumanPlayers() == 2 then
			af:GetChild("")[2].Enabled = true
			af:GetChild("")[3].Enabled = true
			af:GetChild("")[4].Enabled = true
		end
	end

	-- dance solo
	if current_game=="dance" and ThemePrefs.Get("AllowDanceSolo") then
		af:GetChild("")[4].Enabled = true
	end
end

-- pass in a postive integer to get the next enabled choice to the right
-- pass in a negative integer to get the next enabled choice to the left
local GetNextEnabledChoice = function(dir)
	local start = dir > 0 and current_index+1 or #choices+current_index-1
	local stop = dir > 0 and #choices+current_index-1 or current_index+1

	for i=start, stop, dir do
		local index = ((i-1) % #choices) + 1

		if af:GetChild("")[index].Enabled then
			current_index = index
			return
		end
	end
end

-- Calls engine function to "join player."
-- Verifies that the number of players is correct.
-- For example, if both start buttons were pressed, 
-- and doubles selected; unjoin one of the players.
local JoinOrUnjoinPlayersMaybe = function(style, player)
	-- if going into versus/routine, ensure that both players are joined
	if (style=="versus" or style=="routine") then
		for player in ivalues({PLAYER_1, PLAYER_2}) do
			if not GAMESTATE:IsHumanPlayer(player) then GAMESTATE:JoinPlayer(player) end
		end
		return
	end

	-- if either player pressed START to choose a style, that player will have
	-- been passed into this function, and we want to unjoin the other player
	-- now for the sake of single or double
	-- if time ran out, no one will have pressed START, so unjoin whichever player
	-- isn't the MasterPlayerNumber
	player = player or GAMESTATE:GetMasterPlayerNumber()

	-- it's possible that PLAYER_1 was the MPN, but then PLAYER_2 selected single on this screen
	-- ensure that player is actually joined now to avoid having no one joined in ScreenSelectPlayMode
	if not GAMESTATE:IsHumanPlayer(player) then GAMESTATE:JoinPlayer(player) end

	if player == PLAYER_1 then
		GAMESTATE:UnjoinPlayer(PLAYER_2)
	else
		GAMESTATE:UnjoinPlayer(PLAYER_1)
	end
end

-- Calls engine function to insert coin.
local ManageCredits = function(style)

	-- no need to deduct additional credits; just move on
	if PREFSMAN:GetPreference("EventMode")
	or PREFSMAN:GetPreference("CoinMode") ~= "CoinMode_Pay"
	or (GAMESTATE:GetCoinMode() == "CoinMode_Pay" and GAMESTATE:GetPremium() == "Premium_2PlayersFor1Credit") then
		return
	end

	-- double for 1 credit; deduct 1 credit if entering versus and only 1 player has been joined so far
	if GAMESTATE:GetCoinMode() == "CoinMode_Pay"
	and GAMESTATE:GetPremium() == "Premium_DoubleFor1Credit"
	and #GAMESTATE:GetHumanPlayers() == 1
	and style == "versus" then
		GAMESTATE:InsertCoin( -GAMESTATE:GetCoinsNeededToJoin() )
		return
	end

	-- double for 1 credit; insert 1 credit if entering double/routine and 2 players were joined from the title screen
	if GAMESTATE:GetCoinMode() == "CoinMode_Pay"
	and GAMESTATE:GetPremium() == "Premium_DoubleFor1Credit"
	and #GAMESTATE:GetHumanPlayers() == 2
	and (style == "double" or style=="routine") then
		GAMESTATE:InsertCredit()
		return
	end

	-- premium off; deduct 1 credit if entering versus or double or routine
	if GAMESTATE:GetCoinMode() == "CoinMode_Pay"
	and GAMESTATE:GetPremium() == "Premium_Off"
	and #GAMESTATE:GetHumanPlayers() == 1
	and (style=="versus" or style=="double" or style=="routine") then
		GAMESTATE:InsertCoin( -GAMESTATE:GetCoinsNeededToJoin() )
		return
	end
end

------------------------------------------------------------------------------------

local function input(event)
	if not event or not event.PlayerNumber or not event.button then
		return false
	end

	-- handle the case of joining an unjoined player in CoinMode_Pay
	if GAMESTATE:GetCoinMode() == "CoinMode_Pay"
	and GAMESTATE:GetPremium() ~= "Premium_2PlayersFor1Credit"
	and GAMESTATE:EnoughCreditsToJoin()
	and not GAMESTATE:IsHumanPlayer(event.PlayerNumber) then
		if event.type == "InputEventType_FirstPress" and event.GameButton == "Start" then
			-- join the player
			GAMESTATE:JoinPlayer(event.PlayerNumber)
			-- deduct a credit (it might be added back later if choosing double and DoubleFor1Credit is on)
			GAMESTATE:InsertCoin( -GAMESTATE:GetCoinsNeededToJoin() )
			-- play a sound
			af:GetChild("Start"):play()
		end
		return false
	end

	-- normal input handling
	if event.type == "InputEventType_FirstPress" then
		local topscreen = SCREENMAN:GetTopScreen()

		if event.GameButton == "MenuRight" or event.GameButton == "MenuLeft" then
			local prev_index = current_index
			GetNextEnabledChoice(event.GameButton=="MenuRight" and 1 or -1)

			for i, child in ipairs( af:GetChild("") ) do
				if i == current_index then
					child:queuecommand("GainFocus")
				else
					child:queuecommand("LoseFocus")
				end
			end
			if prev_index ~= current_index then af:GetChild("Change"):play() end

		elseif event.GameButton == "Start" then
			StyleSelected = true
			af:GetChild("Start"):play()
			af:playcommand("Finish", {PlayerNumber=event.PlayerNumber})

		elseif event.GameButton == "Back" then
			topscreen:RemoveInputCallback(input)
			topscreen:Cancel()
		end
	end

	return false
end

------------------------------------------------------------------------------------

local t = Def.ActorFrame{
	InitCommand=function(self)
		af = self
		self:queuecommand("Capture")
		EnableChoices()
		self:playcommand("Enable")

		for i, child in ipairs( self:GetChild("") ) do
			if i == current_index then
				child:queuecommand("GainFocus")
			end
		end
	end,
	OnCommand=function(self)
		if PREFSMAN:GetPreference("MenuTimer") then
			self:queuecommand("Listen")
		end
	end,
	CoinsChangedMessageCommand=function(self)
		EnableChoices()
		-- if the current choice is no longer valid after the coin change
		if not self:GetChild("")[current_index].Enabled then
			-- get the next valid choice to the right
			GetNextEnabledChoice(1)
			-- force all choices to LoseFocus
			self:playcommand("LoseFocus")
			-- and queue the new current choice to GainFocus
			self:GetChild("")[current_index]:queuecommand("GainFocus")
		end
		self:playcommand("Enable")
	end,
	ListenCommand=function(self)
		local topscreen = SCREENMAN:GetTopScreen()
		local seconds = topscreen:GetChild("Timer"):GetSeconds()
		if seconds <= 0 and not StyleSelected then
			StyleSelected = true
			self:playcommand("Finish")
		else
			self:sleep(0.25)
			self:queuecommand("Listen")
		end
	end,
	CaptureCommand=function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(input)
	end,
	FinishCommand=function(self, params)
		local style = choices[current_index].name

		ManageCredits(style)
		JoinOrUnjoinPlayersMaybe(style, (params and params.PlayerNumber or nil))

		-- ah, yes, techno mode
		-- techo doesn't have styles like "single" and "double", it has "single8", "versus8", and "double8"
		if current_game=="techno" then style = style.."8" end

		-- set this now, but keep in mind that the style can change during a game session in a number
		-- of ways, like latejoin (when available) and using SSM's SortMenu to change styles mid-game
		GAMESTATE:SetCurrentStyle(style)

		SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
	end,
}

for i,choice in ipairs(choices) do
	t[#t+1] = LoadActor("./DrawPads.lua", {choice, i} )
end

t[#t+1] = LoadActor( THEME:GetPathS("ScreenSelectMaster", "change") )..{ Name="Change", SupportPan=false }
t[#t+1] = LoadActor( THEME:GetPathS("common", "start") )..{ Name="Start", SupportPan=false }

return t