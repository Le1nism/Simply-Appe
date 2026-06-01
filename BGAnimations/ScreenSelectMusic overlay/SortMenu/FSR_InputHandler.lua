local function input(event)
	if not (event and event.PlayerNumber and event.button) then
		return false
	end
	if not GAMESTATE:IsSideJoined(event.PlayerNumber) then
		return false
	end
	if event.type == "InputEventType_Release" then
		return false
	end

	local screen  = SCREENMAN:GetTopScreen()
	local overlay = screen:GetChild("Overlay")
	local fsr     = overlay:GetChild("FSR")

	if not fsr then return false end

	local btn = event.GameButton

	if btn == "Back" then
		fsr:queuecommand("FSRBack")

	elseif btn == "Start" then
		fsr:queuecommand("FSRConfirm")

	elseif btn == "MenuLeft" or btn == "Left" then
		fsr:queuecommand("FSRNavLeft")

	elseif btn == "MenuRight" or btn == "Right" then
		fsr:queuecommand("FSRNavRight")

	elseif btn == "MenuUp" or btn == "Up" then
		fsr:queuecommand("FSRNavUp")

	elseif btn == "MenuDown" or btn == "Down" then
		fsr:queuecommand("FSRNavDown")

	elseif btn == "Select" then
		overlay:playcommand("FetchFSRData")
	end

	return false
end

return input