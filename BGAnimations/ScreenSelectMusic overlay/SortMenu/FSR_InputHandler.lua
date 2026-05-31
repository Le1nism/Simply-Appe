-- this handles user input while in SelectMusic's FSR Manager overlay
local function input(event)
	if not (event and event.PlayerNumber and event.button) then
		return false
	end
	-- don't handle input for a non-joined player
	if not GAMESTATE:IsSideJoined(event.PlayerNumber) then
		return false
	end

	SOUND:StopMusic()

	local screen   = SCREENMAN:GetTopScreen()
	local overlay  = screen:GetChild("Overlay")
	local sortmenu = overlay:GetChild("SortMenu")

	-- pressing Start or Back will queue DirectInputToEngine
	-- but only if the event.type is not a Release
	if (event.GameButton == "Start" or event.GameButton == "Back") and event.type ~= "InputEventType_Release" then
		overlay:queuecommand("DirectInputToEngine")
	elseif event.GameButton == "Select" and event.type ~= "InputEventType_Release" then
		overlay:playcommand("FetchFSRData")
	end

	return false
end

return input
