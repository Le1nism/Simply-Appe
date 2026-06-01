local ws = nil
local active_thresholds = { 0, 0, 0, 0 }
local available_profiles = {}
local current_profile    = ""

-- ─────────────────────────────────────────────
-- Navigation state
-- selected_zone: "buttons" | "editing" | "profile_picker"
-- selected_bar:    1–4 (Only accessible via EDIT mode)
-- selected_button: 1=EDIT, 2=PROFILE, 3=BACK
-- selected_profile_idx: index into available_profiles
-- ─────────────────────────────────────────────
local selected_zone        = "buttons"
local selected_bar         = 1
local selected_button      = 1
local selected_profile_idx = 1
local pending_thresholds   = { 0, 0, 0, 0 }
local STEP                 = 5
local MAX_VAL              = 1023

-- ─────────────────────────────────────────────
-- WebSocket helpers
-- ─────────────────────────────────────────────
local function SendThreshold(index)
	if not ws then return end
	local values = {}
	for i = 1, 4 do values[i] = active_thresholds[i] end
	ws:Send(JsonEncode({ "update_threshold", values, index - 1 }))
end

local function SendChangeProfile(name)
	if not ws then return end
	ws:Send(JsonEncode({ "change_profile", name }))
end

-- ─────────────────────────────────────────────
-- HTTP / WebSocket setup
-- ─────────────────────────────────────────────
local function FetchFSRData()
	if not NETWORK then
		MESSAGEMAN:Broadcast("FSRDataFailed", { message = "NETWORK not available" })
		return
	end
	local url = "http://localhost:5000/defaults"
	if not NETWORK:IsUrlAllowed(url) then
		MESSAGEMAN:Broadcast("FSRDataFailed", { message = "Host not allowed. Add 'localhost' to HttpAllowHosts in Preferences.ini." })
		return
	end
	NETWORK:HttpRequest{
		url = url, method = "GET",
		connectTimeout = 2, transferTimeout = 5,
		onResponse = function(response)
			if response.error then
				MESSAGEMAN:Broadcast("FSRDataFailed", { message = response.errorMessage or "Unknown HTTP error" })
				return
			end
			if response.statusCode ~= 200 then
				MESSAGEMAN:Broadcast("FSRDataFailed", { message = "HTTP status " .. tostring(response.statusCode) })
				return
			end
			local ok, decoded = pcall(JsonDecode, response.body)
			if not ok or not decoded then
				MESSAGEMAN:Broadcast("FSRDataFailed", { message = "Failed to parse JSON response" })
				return
			end
			MESSAGEMAN:Broadcast("FSRDataReady", decoded)
		end
	}
end

local function ConnectWebSocket()
	if ws then ws:Close(); ws = nil end
	ws = NETWORK:WebSocket{
		url = "ws://localhost:5000/ws",
		pingInterval = 10, automaticReconnect = true,
		onMessage = function(msg)
			local msgType = ToEnumShortString(msg.type)
			if msgType == "Message" then
				local ok, data = pcall(JsonDecode, msg.data)
				if ok and data and type(data) == "table" then
					local action, payload = data[1], data[2]
					if action == "values" then
						MESSAGEMAN:Broadcast("FSRValuesUpdate", payload)
					elseif action == "thresholds" then
						MESSAGEMAN:Broadcast("FSRThresholdsUpdate", payload)
					elseif action == "get_cur_profile" then
						current_profile = payload.cur_profile or ""
						MESSAGEMAN:Broadcast("FSRProfileChanged", { cur_profile = current_profile })
					end
				end
			end
		end
	}
end

-- ─────────────────────────────────────────────
-- Broadcast helpers
-- ─────────────────────────────────────────────
local function BroadcastSelectUpdate() MESSAGEMAN:Broadcast("FSRSelectUpdate") end
local function BroadcastPendingUpdate() MESSAGEMAN:Broadcast("FSRPendingUpdate") end
local function BroadcastFooterUpdate() MESSAGEMAN:Broadcast("FSRFooterUpdate") end
local function BroadcastProfilePickerUpdate() MESSAGEMAN:Broadcast("FSRProfilePickerUpdate") end

-- ─────────────────────────────────────────────
-- Sensor Bar
-- ─────────────────────────────────────────────
local function CreateSensorBar(name, index, x)
	local bar_h    = 110 -- Restored scale balance
	local bar_w    = 14
	local half_h   = bar_h / 2
	local bottom_y = half_h

	local function IsEditing()
		return selected_zone == "editing" and selected_bar == index
	end

	return Def.ActorFrame{
		InitCommand=function(self) self:x(x) end,

		-- Selection outline
		Def.Quad{
			InitCommand=function(self) self:zoomto(bar_w + 6, bar_h + 6):diffusealpha(0) end,
			FSRSelectUpdateMessageCommand=function(self)
				if IsEditing() then
					self:diffuse(GetCurrentColor()):diffusealpha(0.6)
				else
					self:diffusealpha(0)
				end
			end
		},

		-- Track background
		Def.Quad{
			InitCommand=function(self) self:zoomto(bar_w, bar_h):diffuse(0.10, 0.10, 0.10, 1) end,
			FSRSelectUpdateMessageCommand=function(self)
				if IsEditing() then
					self:diffuse(0.16, 0.16, 0.16, 1)
				else
					self:diffuse(0.10, 0.10, 0.10, 1)
				end
			end
		},

		-- Fill
		Def.Quad{
			InitCommand=function(self)
				self:valign(1):zoomto(bar_w, 0):y(bottom_y):diffuse(0.3, 0.3, 0.3, 1)
			end,
			FSRValuesUpdateMessageCommand=function(self, params)
				local val = (params.values or {})[index]
				if val then
					local h = (val / MAX_VAL) * bar_h
					self:zoomto(bar_w, math.max(0, math.min(h, bar_h)))
					if val >= (active_thresholds[index] or 0) then
						self:diffuse(GetCurrentColor()):diffusealpha(0.9)
					else
						self:diffuse(0.3, 0.3, 0.3, 1)
					end
				end
			end
		},

		-- Threshold line
		Def.Quad{
			InitCommand=function(self)
				self:zoomto(bar_w + 6, 1):diffuse(color("#ff4444")):visible(false)
			end,
			FSRThresholdsUpdateMessageCommand=function(self, params)
				local t = (params.thresholds or {})[index]
				if t then
					active_thresholds[index] = t
					pending_thresholds[index] = t
					self:y(bottom_y - (t / MAX_VAL) * bar_h):visible(true)
					self:diffuse(color("#ff4444")):diffusealpha(1)
				end
			end,
			FSRDataReadyMessageCommand=function(self, params)
				local t = (params.thresholds or {})[index]
				if t then
					active_thresholds[index] = t
					pending_thresholds[index] = t
					self:y(bottom_y - (t / MAX_VAL) * bar_h):visible(true)
				end
			end,
			FSRPendingUpdateMessageCommand=function(self)
				local t = pending_thresholds[index]
				self:y(bottom_y - (t / MAX_VAL) * bar_h):visible(true)
				if IsEditing() then
					self:diffuse(GetCurrentColor()):diffusealpha(1)
				else
					self:diffuse(color("#ff4444")):diffusealpha(1)
				end
			end
		},

		-- Threshold value (above bar)
		Def.BitmapText{
			Font="Common Normal",
			Text="—",
			InitCommand=function(self)
				self:y(-half_h - 12):zoom(0.36):diffuse(0.4, 0.4, 0.4, 1)
			end,
			FSRThresholdsUpdateMessageCommand=function(self, params)
				local t = (params.thresholds or {})[index]
				if t then self:settext(tostring(t)) end
			end,
			FSRDataReadyMessageCommand=function(self, params)
				local t = (params.thresholds or {})[index]
				if t then self:settext(tostring(t)) end
			end,
			FSRPendingUpdateMessageCommand=function(self)
				self:settext(tostring(pending_thresholds[index]))
				if IsEditing() then
					self:diffuse(GetCurrentColor()):diffusealpha(1)
				else
					self:diffuse(0.4, 0.4, 0.4, 1)
				end
			end
		},

		-- Live value (below bar)
		Def.BitmapText{
			Font="Common Normal",
			Text="—",
			InitCommand=function(self)
				self:y(half_h + 10):zoom(0.40):diffuse(0.6, 0.6, 0.6, 1)
			end,
			FSRValuesUpdateMessageCommand=function(self, params)
				local val = (params.values or {})[index]
				if val then
					self:settext(tostring(val))
					if val >= (active_thresholds[index] or 0) then
						self:diffuse(GetCurrentColor()):diffusealpha(1)
					else
						self:diffuse(0.6, 0.6, 0.6, 1)
					end
				end
			end
		},

		-- Direction label
		Def.BitmapText{
			Font="Common Normal",
			Text=name,
			InitCommand=function(self)
				self:y(half_h + 24):zoom(0.36):diffuse(0.28, 0.28, 0.28, 1)
			end,
			FSRSelectUpdateMessageCommand=function(self)
				if IsEditing() then
					self:diffuse(1, 1, 1, 0.7)
				else
					self:diffuse(0.28, 0.28, 0.28, 1)
				end
			end
		},
	}
end

-- ─────────────────────────────────────────────
-- Button row helper
-- btn_index: 1=EDIT, 2=PROFILE, 3=BACK
-- ─────────────────────────────────────────────
local btn_labels = { "EDIT", "PROFILE", "BACK" }
local btn_w, btn_h = 110, 30
local btn_spacing  = 130

local function CreateButton(btn_index)
	local x = (btn_index - 2) * btn_spacing

	local function IsSelected()
		return selected_zone == "buttons" and selected_button == btn_index
	end

	return Def.ActorFrame{
		InitCommand=function(self) self:x(x) end,

		-- Button background
		Def.Quad{
			InitCommand=function(self)
				self:zoomto(btn_w, btn_h):diffuse(0.10, 0.10, 0.10, 1)
			end,
			FSRSelectUpdateMessageCommand=function(self)
				if IsSelected() then
					self:diffuse(GetCurrentColor()):diffusealpha(0.15)
				else
					self:diffuse(0.10, 0.10, 0.10, 1)
				end
			end
		},

		-- Button border
		Def.Quad{
			InitCommand=function(self)
				self:zoomto(btn_w + 2, btn_h + 2):diffuse(1, 1, 1, 0.06)
			end,
			FSRSelectUpdateMessageCommand=function(self)
				if IsSelected() then
					self:diffuse(GetCurrentColor()):diffusealpha(0.7)
				else
					self:diffuse(1, 1, 1, 0.06)
				end
			end
		},

		-- Button label
		Def.BitmapText{
			Font="Common Normal",
			Text=btn_labels[btn_index],
			InitCommand=function(self)
				self:zoom(0.42):horizalign(center):diffuse(0.4, 0.4, 0.4, 1)
			end,
			FSRSelectUpdateMessageCommand=function(self)
				if IsSelected() then
					self:diffuse(1, 1, 1, 0.95)
				else
					self:diffuse(0.4, 0.4, 0.4, 1)
				end
			end
		},
	}
end

-- ─────────────────────────────────────────────
-- Root
-- ─────────────────────────────────────────────
local af = Def.ActorFrame{
	Name="FSR",
	InitCommand=function(self) self:visible(false) end,

	ShowFSRCommand=function(self)
		selected_zone   = "buttons"
		selected_bar    = 1
		selected_button = 1
		self:visible(true)
		self:playcommand("FetchFSRData")
		BroadcastSelectUpdate()
		BroadcastFooterUpdate()
	end,

	HideFSRCommand=function(self)
		selected_zone = "buttons"
		self:visible(false)
		if ws then ws:Close(); ws = nil end
	end,

	FetchFSRDataCommand=function(self)
		self:playcommand("SetStatus", { status = "loading", message = "Connecting to FSR server..." })
		FetchFSRData()
	end,

	FSRDataReadyMessageCommand=function(self, params)
		available_profiles = params.profiles or {}
		current_profile    = params.cur_profile or ""
		for i, name in ipairs(available_profiles) do
			if name == current_profile then
				selected_profile_idx = i
				break
			end
		end
		ConnectWebSocket()
	end,

	-- ── Input commands (called by FSR_InputHandler) ──

	FSRNavUpCommand=function(self)
		if selected_zone == "editing" then
			pending_thresholds[selected_bar] = math.min(MAX_VAL, pending_thresholds[selected_bar] + STEP)
			BroadcastPendingUpdate()
		elseif selected_zone == "profile_picker" then
			if #available_profiles > 0 then
				selected_profile_idx = ((selected_profile_idx - 2) % #available_profiles) + 1
				BroadcastProfilePickerUpdate()
			end
		end
	end,

	FSRNavDownCommand=function(self)
		if selected_zone == "editing" then
			pending_thresholds[selected_bar] = math.max(0, pending_thresholds[selected_bar] - STEP)
			BroadcastPendingUpdate()
		elseif selected_zone == "profile_picker" then
			if #available_profiles > 0 then
				selected_profile_idx = (selected_profile_idx % #available_profiles) + 1
				BroadcastProfilePickerUpdate()
			end
		end
	end,

	FSRNavLeftCommand=function(self)
		if selected_zone == "buttons" then
			if selected_button > 1 then
				selected_button = selected_button - 1
				BroadcastSelectUpdate()
				BroadcastFooterUpdate()
			end
		elseif selected_zone == "editing" then
			if selected_bar > 1 then
				selected_bar = selected_bar - 1
				pending_thresholds[selected_bar] = active_thresholds[selected_bar]
				BroadcastSelectUpdate()
				BroadcastPendingUpdate()
			end
		end
	end,

	FSRNavRightCommand=function(self)
		if selected_zone == "buttons" then
			if selected_button < 3 then
				selected_button = selected_button + 1
				BroadcastSelectUpdate()
				BroadcastFooterUpdate()
			end
		elseif selected_zone == "editing" then
			if selected_bar < 4 then
				selected_bar = selected_bar + 1
				pending_thresholds[selected_bar] = active_thresholds[selected_bar]
				BroadcastSelectUpdate()
				BroadcastPendingUpdate()
			end
		end
	end,

	FSRConfirmCommand=function(self)
		if selected_zone == "editing" then
			active_thresholds[selected_bar] = pending_thresholds[selected_bar]
			SendThreshold(selected_bar)
			selected_zone = "buttons"
			BroadcastSelectUpdate()
			BroadcastPendingUpdate()
			BroadcastFooterUpdate()

		elseif selected_zone == "profile_picker" then
			local name = available_profiles[selected_profile_idx]
			if name then
				current_profile = name
				SendChangeProfile(name)
			end
			selected_zone = "buttons"
			MESSAGEMAN:Broadcast("FSRProfilePickerClose")
			BroadcastSelectUpdate()
			BroadcastFooterUpdate()

		elseif selected_zone == "buttons" then
			if selected_button == 1 then
				selected_zone = "editing"
				selected_bar = 1
				pending_thresholds[selected_bar] = active_thresholds[selected_bar]
				BroadcastSelectUpdate()
				BroadcastPendingUpdate()
				BroadcastFooterUpdate()

			elseif selected_button == 2 then
				if #available_profiles > 0 then
					selected_zone = "profile_picker"
					MESSAGEMAN:Broadcast("FSRProfilePickerOpen")
					BroadcastProfilePickerUpdate()
					BroadcastFooterUpdate()
				end

			elseif selected_button == 3 then
				local screen  = SCREENMAN:GetTopScreen()
				local overlay = screen:GetChild("Overlay")
				overlay:playcommand("DirectInputToSortMenu")
			end
		end
	end,

	FSRBackCommand=function(self)
		if selected_zone == "editing" then
			pending_thresholds[selected_bar] = active_thresholds[selected_bar]
			selected_zone = "buttons"
			BroadcastSelectUpdate()
			BroadcastPendingUpdate()
			BroadcastFooterUpdate()
		elseif selected_zone == "profile_picker" then
			selected_zone = "buttons"
			MESSAGEMAN:Broadcast("FSRProfilePickerClose")
			BroadcastSelectUpdate()
			BroadcastFooterUpdate()
		else
			local screen  = SCREENMAN:GetTopScreen()
			local overlay = screen:GetChild("Overlay")
			overlay:playcommand("DirectInputToSortMenu")
		end
	end,

	-- ── Backdrop ──────────────────────────────
	Def.Quad{
		InitCommand=function(self) self:FullScreen():diffuse(0, 0, 0, 0.70) end
	},

	-- ── Card Frame ────────────────────────────
	Def.ActorFrame{
		InitCommand=function(self) self:xy(_screen.cx, _screen.cy) end,

		-- Card background (Height updated to balanced 380 footprint)
		Def.Quad{
			InitCommand=function(self)
				self:zoomto(450, 380):diffuse(0.06, 0.06, 0.06, 0.98)
			end
		},

		-- Top accent bar
		Def.Quad{
			InitCommand=function(self)
				self:y(-190):zoomto(450, 2):diffuse(GetCurrentColor()):diffusealpha(1)
			end
		},

		-- Title
		Def.BitmapText{
			Font="Common Normal",
			Text="FSR MANAGER",
			InitCommand=function(self)
				self:y(-160):zoom(0.55):diffuse(1, 1, 1, 0.92):horizalign(center)
			end
		},

		-- Stacked profile layout (PROFILE on right edge, value directly below it)
		Def.ActorFrame{
			InitCommand=function(self) self:xy(200, -160) end,

			Def.BitmapText{
				Font="Common Normal",
				Text="PROFILE:",
				InitCommand=function(self)
					self:zoom(0.34):horizalign(right):diffuse(0.35, 0.35, 0.35, 1)
				end
			},

			Def.BitmapText{
				Font="Common Normal",
				Name="ActiveProfileName",
				InitCommand=function(self)
					self:y(14):zoom(0.42):horizalign(right):maxwidth(130):diffuse(1, 1, 1, 0.9)
				end,
				FSRDataReadyMessageCommand=function(self, params)
					local active = params.cur_profile or ""
					self:settext(active ~= "" and active or "None")
				end,
				FSRProfileChangedMessageCommand=function(self, params)
					self:settext(params.cur_profile ~= "" and params.cur_profile or "None")
				end,
			},
		},

		-- Status text
		Def.BitmapText{
			Font="Common Normal",
			Name="StatusText",
			Text="Connecting to FSR server...",
			InitCommand=function(self)
				self:y(0):zoom(0.50):diffuse(0.45, 0.45, 0.45, 1):maxwidth(350):horizalign(center)
			end,
			SetStatusCommand=function(self, params)
				if params.status == "loading" then
					self:visible(true):settext(params.message):diffuse(0.45, 0.45, 0.45, 1)
				elseif params.status == "error" then
					self:visible(true)
					self:settext("Error  ·  " .. params.message .. "\n\nMake sure the FSR server is running on localhost:5000")
					self:diffuse(color("#ff4444"))
				else
					self:visible(false)
				end
			end,
			FSRDataFailedMessageCommand=function(self, params)
				self:playcommand("SetStatus", { status = "error", message = params.message })
			end,
			FSRDataReadyMessageCommand=function(self)
				self:playcommand("SetStatus", { status = "success" })
			end,
			ShowFSRCommand=function(self)
				self:playcommand("SetStatus", { status = "loading", message = "Connecting to FSR server..." })
			end
		},

		-- ── Dashboard Area ────────────────────
		Def.ActorFrame{
			Name="Dashboard",
			InitCommand=function(self) self:visible(false) end,
			FSRDataReadyMessageCommand=function(self) self:visible(true) end,
			FSRDataFailedMessageCommand=function(self) self:visible(false) end,
			ShowFSRCommand=function(self) self:visible(false) end,

			-- Sensor bars
			Def.ActorFrame{
				InitCommand=function(self) self:xy(0, -15) end,

				Def.BitmapText{
					Font="Common Normal",
					Text="LIVE  ·  THRESHOLDS",
					InitCommand=function(self)
						self:y(-78):zoom(0.34):horizalign(center):diffuse(0.35, 0.35, 0.35, 1)
					end
				},

				CreateSensorBar("L", 1, -95),
				CreateSensorBar("D", 2, -32),
				CreateSensorBar("U", 3,  32),
				CreateSensorBar("R", 4,  95),
			},

			-- Divider rule
			Def.Quad{
				InitCommand=function(self)
					self:y(90):zoomto(390, 1):diffuse(1, 1, 1, 0.06)
				end
			},

			-- Button row
			Def.ActorFrame{
				InitCommand=function(self) self:xy(0, 118) end,

				CreateButton(1),  -- EDIT
				CreateButton(2),  -- PROFILE
				CreateButton(3),  -- BACK
			},

			-- ── Profile Picker Box Overlay ──────
			Def.ActorFrame{
				Name="ProfilePicker",
				InitCommand=function(self) self:visible(false) end,
				FSRProfilePickerOpenMessageCommand=function(self) self:visible(true) end,
				FSRProfilePickerCloseMessageCommand=function(self) self:visible(false) end,

				Def.Quad{
					InitCommand=function(self)
						self:zoomto(450, 240):y(-10):diffuse(0, 0, 0, 0.75)
					end
				},

				Def.ActorFrame{
					InitCommand=function(self) self:xy(0, -10) end,

					Def.Quad{
						InitCommand=function(self)
							self:zoomto(250, 170):diffuse(0.08, 0.08, 0.08, 1)
						end
					},
					Def.Quad{
						InitCommand=function(self)
							self:zoomto(252, 172):diffuse(1, 1, 1, 0.08)
						end
					},

					Def.BitmapText{
						Font="Common Normal",
						Text="SELECT PROFILE",
						InitCommand=function(self)
							self:y(-68):zoom(0.34):horizalign(center):diffuse(GetCurrentColor()):diffusealpha(0.8)
						end
					},

					-- Render Dynamic Profiles
					(function()
						local t = Def.ActorFrame{}
						local max_show = 5
						for i = 1, max_show do
							local row_y = -42 + (i - 1) * 22
							t[#t+1] = Def.ActorFrame{
								InitCommand=function(self) self:y(row_y) end,

								Def.Quad{
									Name="RowHighlight",
									InitCommand=function(self)
										self:zoomto(230, 20):diffusealpha(0)
									end,
									FSRProfilePickerUpdateMessageCommand=function(self)
										if selected_profile_idx == i then
											self:diffuse(GetCurrentColor()):diffusealpha(0.15)
										else
											self:diffusealpha(0)
										end
									end
								},

								Def.BitmapText{
									Font="Common Normal",
									InitCommand=function(self)
										self:zoom(0.46):horizalign(center):maxwidth(210):visible(false)
									end,
									FSRDataReadyMessageCommand=function(self, params)
										local name = (params.profiles or {})[i]
										if name then
											self:visible(true):settext(name)
										else
											self:visible(false)
										end
									end,
									FSRProfilePickerUpdateMessageCommand=function(self)
										if selected_profile_idx == i then
											self:diffuse(1, 1, 1, 0.95)
										else
											self:diffuse(1, 1, 1, 0.3)
										end
									end
								},
							}
						end
						return t
					end)(),
				},
			},
		},

		-- Footer edge rule
		Def.Quad{
			InitCommand=function(self)
				self:y(152):zoomto(410, 1):diffuse(1, 1, 1, 0.06)
			end
		},

		-- Navigational context notes
		Def.BitmapText{
			Font="Common Normal",
			Name="FooterHint",
			Text="&LEFT; &RIGHT; navigate  ·  &START; confirm  ·  &BACK; exit",
			InitCommand=function(self)
				self:y(166):zoom(0.40):diffuse(1, 1, 1, 0.8):horizalign(center)
			end,
			FSRFooterUpdateMessageCommand=function(self)
				if selected_zone == "editing" then
					self:settext("&LEFT; &RIGHT; select bar  ·  &UP; &DOWN; adjust  ·  &START; save  ·  &BACK; cancel")
					self:diffuse(1, 1, 1, 0.9)
				elseif selected_zone == "profile_picker" then
					self:settext("&UP; &DOWN; select profile  ·  &START; confirm  ·  &BACK; cancel")
					self:diffuse(1, 1, 1, 0.9)
				else
					self:settext("&LEFT; &RIGHT; navigate  ·  &START; confirm  ·  &BACK; exit")
					self:diffuse(1, 1, 1, 0.8)
				end
			end,
			ShowFSRCommand=function(self)
				self:settext("&LEFT; &RIGHT; navigate  ·  &START; confirm  ·  &BACK; exit")
				self:diffuse(1, 1, 1, 0.8)
			end
		},
	}
}

return af