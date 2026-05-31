local ws = nil
local active_thresholds = { 0, 0, 0, 0 }

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
		url = url,
		method = "GET",
		connectTimeout = 2,
		transferTimeout = 5,
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
	if ws then
		ws:Close()
		ws = nil
	end

	ws = NETWORK:WebSocket{
		url = "ws://localhost:5000/ws",
		pingInterval = 10,
		automaticReconnect = true,
		onMessage = function(msg)
			local msgType = ToEnumShortString(msg.type)
			if msgType == "Message" then
				local ok, data = pcall(JsonDecode, msg.data)
				if ok and data and type(data) == "table" then
					local action = data[1]
					local payload = data[2]
					if action == "values" then
						MESSAGEMAN:Broadcast("FSRValuesUpdate", payload)
					elseif action == "thresholds" then
						MESSAGEMAN:Broadcast("FSRThresholdsUpdate", payload)
					end
				end
			end
		end
	}
end

local function CreateSensorBar(name, index, x)
	local bar_height = 140
	local bar_width = 18
	local max_val = 1023
	local half_height = bar_height / 2
	local bottom_y = half_height

	return Def.ActorFrame{
		InitCommand=function(self) self:x(x) end,

		-- 1px Border Outline for the Bar Track
		Def.Quad{
			InitCommand=function(self) self:zoomto(bar_width + 2, bar_height + 2):diffuse(1, 1, 1, 0.08) end
		},
		-- Bar Track Background (dark slot)
		Def.Quad{
			InitCommand=function(self) self:zoomto(bar_width, bar_height):diffuse(0.06, 0.06, 0.06, 0.95) end
		},

		-- Bar Fill Quad (valign bottom so it grows upwards)
		Def.Quad{
			Name="Fill",
			InitCommand=function(self) self:valign(bottom):zoomto(bar_width - 4, 0):y(bottom_y):diffuse(1, 1, 1, 0.3) end,
			FSRValuesUpdateMessageCommand=function(self, params)
				local values = params.values or {}
				local val = values[index]
				if val then
					local h = (val / max_val) * bar_height
					self:zoomto(bar_width - 4, math.max(0, math.min(h, bar_height)))

					-- Highlight fill if FSR value exceeds active threshold
					local thresh = active_thresholds[index] or 0
					if val >= thresh then
						self:diffuse(color("#88ff88")):diffusealpha(0.85)
					else
						self:diffuse(1, 1, 1, 0.3)
					end
				end
			end
		},

		-- Threshold Mark (red horizontal indicator line)
		Def.Quad{
			Name="ThresholdMark",
			InitCommand=function(self) self:zoomto(bar_width + 4, 2):diffuse(color("#ff4444")):visible(false) end,
			FSRThresholdsUpdateMessageCommand=function(self, params)
				local thresholds = params.thresholds or {}
				local t = thresholds[index]
				if t then
					active_thresholds[index] = t
					local py = bottom_y - (t / max_val) * bar_height
					self:y(py):visible(true)
				end
			end,
			FSRDataReadyMessageCommand=function(self, params)
				local thresholds = params.thresholds or {}
				local t = thresholds[index]
				if t then
					active_thresholds[index] = t
					local py = bottom_y - (t / max_val) * bar_height
					self:y(py):visible(true)
				end
			end
		},

		-- Threshold Value (Above the bar)
		Def.BitmapText{
			Font="Common Normal",
			Name="ThresholdValue",
			Text="-",
			InitCommand=function(self) self:y(-half_height - 12):zoom(0.48):diffuse(0.5, 0.5, 0.5, 1) end,
			FSRThresholdsUpdateMessageCommand=function(self, params)
				local thresholds = params.thresholds or {}
				local t = thresholds[index]
				if t then self:settext(tostring(t)) end
			end,
			FSRDataReadyMessageCommand=function(self, params)
				local thresholds = params.thresholds or {}
				local t = thresholds[index]
				if t then self:settext(tostring(t)) end
			end
		},

		-- Current Actual Value (Below the bar)
		Def.BitmapText{
			Font="Common Normal",
			Name="ActualValue",
			Text="-",
			InitCommand=function(self) self:y(half_height + 12):zoom(0.48):diffuse(1, 1, 1, 0.7) end,
			FSRValuesUpdateMessageCommand=function(self, params)
				local values = params.values or {}
				local val = values[index]
				if val then
					self:settext(tostring(val))

					-- Highlight actual value text if pressed
					local thresh = active_thresholds[index] or 0
					if val >= thresh then
						self:diffuse(color("#88ff88"))
					else
						self:diffuse(1, 1, 1, 0.7)
					end
				end
			end
		},

		-- Direction Label
		Def.BitmapText{
			Font="Common Normal",
			Text=name,
			InitCommand=function(self) self:y(half_height + 27):zoom(0.4):diffuse(0.5, 0.5, 0.5, 1) end
		}
	}
end

local af = Def.ActorFrame{
	InitCommand=function(self) self:visible(false) end,

	ShowFSRCommand=function(self)
		self:visible(true)
		self:playcommand("FetchFSRData")
	end,

	HideFSRCommand=function(self)
		self:visible(false)
		if ws then
			ws:Close()
			ws = nil
		end
	end,

	FetchFSRDataCommand=function(self)
		self:playcommand("SetStatus", { status = "loading", message = "Fetching FSR settings..." })
		FetchFSRData()
	end,

	FSRDataReadyMessageCommand=function(self)
		ConnectWebSocket()
	end,

	-- Background dim
	Def.Quad{
		InitCommand=function(self) self:FullScreen():diffuse(0,0,0,0.85) end
	},

	-- Card Frame
	Def.ActorFrame{
		InitCommand=function(self) self:xy(_screen.cx, _screen.cy) end,

		-- Subtle 1px card border
		Def.Quad{
			InitCommand=function(self) self:zoomto(522, 422):diffuse(1, 1, 1, 0.12) end
		},
		-- Card Background
		Def.Quad{
			InitCommand=function(self) self:zoomto(520, 420):diffuse(0.03, 0.03, 0.03, 0.96) end
		},

		-- Title
		Def.BitmapText{
			Font="Common Normal",
			Text="FSR MANAGER",
			InitCommand=function(self) self:y(-175):zoom(0.75):diffuse(0.9, 0.9, 0.9, 1) end,
		},
		-- Title Accent Underline
		Def.Quad{
			InitCommand=function(self) self:y(-155):zoomto(60, 2):diffuse(color("#88ff88")) end
		},

		-- Status Text
		Def.BitmapText{
			Font="Common Normal",
			Name="StatusText",
			Text="Fetching FSR settings...",
			InitCommand=function(self) self:y(0):zoom(0.75):diffuse(0.6, 0.6, 0.6, 1):maxwidth(400) end,
			SetStatusCommand=function(self, params)
				if params.status == "loading" then
					self:visible(true):settext(params.message):diffuse(0.6, 0.6, 0.6, 1)
				elseif params.status == "error" then
					self:visible(true):settext("Error: " .. params.message .. "\n\nEnsure FSR server is running on localhost:5000"):diffuse(Color.Red)
				else
					self:visible(false)
				end
			end,
			FSRDataFailedMessageCommand=function(self, params)
				self:playcommand("SetStatus", { status = "error", message = params.message })
			end,
			FSRDataReadyMessageCommand=function(self, params)
				self:playcommand("SetStatus", { status = "success" })
			end,
			ShowFSRCommand=function(self)
				self:playcommand("SetStatus", { status = "loading", message = "Fetching FSR settings..." })
			end
		},

		-- Dashboard Container
		Def.ActorFrame{
			Name="Dashboard",
			InitCommand=function(self) self:visible(false) end,
			FSRDataReadyMessageCommand=function(self, params)
				self:visible(true)
			end,
			FSRDataFailedMessageCommand=function(self)
				self:visible(false)
			end,
			ShowFSRCommand=function(self)
				self:visible(false)
			end,

			-- Vertical Divider
			Def.Quad{
				InitCommand=function(self) self:x(-15):y(-15):zoomto(1, 200):diffuse(1, 1, 1, 0.08) end
			},

			-- Left Side: Profiles
			Def.ActorFrame{
				InitCommand=function(self) self:x(-130) end,

				-- Active Profile Label
				Def.BitmapText{
					Font="Common Normal",
					Text="ACTIVE PROFILE",
					InitCommand=function(self) self:y(-110):zoom(0.4):horizalign(left):diffuse(color("#88ff88")) end
				},

				-- Active Profile Value
				Def.BitmapText{
					Font="Common Normal",
					InitCommand=function(self) self:y(-92):zoom(0.75):horizalign(left):diffuse(1, 1, 1, 0.9) end,
					FSRDataReadyMessageCommand=function(self, params)
						local active = params.cur_profile or ""
						if active == "" then active = "None" end
						self:settext(active)
					end
				},

				-- Available Profiles Header
				Def.BitmapText{
					Font="Common Normal",
					Text="AVAILABLE PROFILES",
					InitCommand=function(self) self:y(-35):zoom(0.4):horizalign(left):diffuse(0.5, 0.5, 0.5, 1) end
				},

				-- List of all profiles (supports up to 6 profiles)
				(function()
					local t = Def.ActorFrame{}
					local max_profiles_display = 6
					for idx = 1, max_profiles_display do
						t[#t+1] = Def.BitmapText{
							Font="Common Normal",
							InitCommand=function(self) self:y(-15 + (idx-1)*22):zoom(0.65):horizalign(left) end,
							FSRDataReadyMessageCommand=function(self, params)
								local profiles = params.profiles or {}
								local name = profiles[idx]
								if name then
									self:visible(true):settext(name)
									if name == params.cur_profile then
										self:diffuse(color("#88ff88")):diffusealpha(1)
									else
										self:diffuse(1, 1, 1, 0.4)
									end
								else
									self:visible(false)
								end
							end
						}
					end
					return t
				end)(),
			},

			-- Right Side: Sensor Thresholds Vertical Bars
			Def.ActorFrame{
				InitCommand=function(self) self:x(120):y(-15) end,

				Def.BitmapText{
					Font="Common Normal",
					Text="LIVE VALUES & THRESHOLDS",
					InitCommand=function(self) self:y(-95):zoom(0.4):horizalign(center):diffuse(0.5, 0.5, 0.5, 1) end
				},

				CreateSensorBar("LEFT",  1, -75),
				CreateSensorBar("DOWN",  2, -25),
				CreateSensorBar("UP",    3, 25),
				CreateSensorBar("RIGHT", 4, 75),
			}
		},

		-- Footer Action Prompt
		Def.BitmapText{
			Font="Common Normal",
			Text="Press START to return",
			InitCommand=function(self) self:y(180):zoom(0.55):diffuse(0.5, 0.5, 0.5, 1) end
		}
	}
}

return af
