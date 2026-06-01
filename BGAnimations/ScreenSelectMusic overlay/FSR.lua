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

-- ─────────────────────────────────────────────
-- Sensor Bar
-- ─────────────────────────────────────────────

local function CreateSensorBar(name, index, x)
	local bar_h      = 120
	local bar_w      = 14
	local max_val    = 1023
	local half_h     = bar_h / 2
	local bottom_y   = half_h

	return Def.ActorFrame{
		InitCommand=function(self) self:x(x) end,

		-- Track background
		Def.Quad{
			InitCommand=function(self)
				self:zoomto(bar_w, bar_h):diffuse(0.10, 0.10, 0.10, 1)
			end
		},

		-- Fill (grows upward from bottom)
		Def.Quad{
			Name="Fill",
			InitCommand=function(self)
				self:valign(1):zoomto(bar_w, 0):y(bottom_y):diffuse(0.3, 0.3, 0.3, 1)
			end,
			FSRValuesUpdateMessageCommand=function(self, params)
				local val = (params.values or {})[index]
				if val then
					local h = (val / max_val) * bar_h
					self:zoomto(bar_w, math.max(0, math.min(h, bar_h)))
					local thresh = active_thresholds[index] or 0
					if val >= thresh then
						self:diffuse(GetCurrentColor()):diffusealpha(0.9)
					else
						self:diffuse(0.3, 0.3, 0.3, 1)
					end
				end
			end
		},

		-- Threshold line
		Def.Quad{
			Name="ThresholdMark",
			InitCommand=function(self)
				self:zoomto(bar_w + 6, 1):diffuse(color("#ff4444")):visible(false)
			end,
			FSRThresholdsUpdateMessageCommand=function(self, params)
				local t = (params.thresholds or {})[index]
				if t then
					active_thresholds[index] = t
					self:y(bottom_y - (t / max_val) * bar_h):visible(true)
				end
			end,
			FSRDataReadyMessageCommand=function(self, params)
				local t = (params.thresholds or {})[index]
				if t then
					active_thresholds[index] = t
					self:y(bottom_y - (t / max_val) * bar_h):visible(true)
				end
			end
		},

		-- Threshold value (above bar)
		Def.BitmapText{
			Font="Common Normal",
			Name="ThresholdValue",
			Text="—",
			InitCommand=function(self)
				self:y(-half_h - 14):zoom(0.38):diffuse(0.4, 0.4, 0.4, 1)
			end,
			FSRThresholdsUpdateMessageCommand=function(self, params)
				local t = (params.thresholds or {})[index]
				if t then self:settext(tostring(t)) end
			end,
			FSRDataReadyMessageCommand=function(self, params)
				local t = (params.thresholds or {})[index]
				if t then self:settext(tostring(t)) end
			end
		},

		-- Live value (below bar)
		Def.BitmapText{
			Font="Common Normal",
			Name="ActualValue",
			Text="—",
			InitCommand=function(self)
				self:y(half_h + 12):zoom(0.42):diffuse(0.6, 0.6, 0.6, 1)
			end,
			FSRValuesUpdateMessageCommand=function(self, params)
				local val = (params.values or {})[index]
				if val then
					self:settext(tostring(val))
					local thresh = active_thresholds[index] or 0
					if val >= thresh then
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
				self:y(half_h + 26):zoom(0.34):diffuse(0.28, 0.28, 0.28, 1)
			end
		}
	}
end

-- ─────────────────────────────────────────────
-- Root
-- ─────────────────────────────────────────────

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
		self:playcommand("SetStatus", { status = "loading", message = "Connecting to FSR server..." })
		FetchFSRData()
	end,

	FSRDataReadyMessageCommand=function(self)
		ConnectWebSocket()
	end,

	-- ── Backdrop ──────────────────────────────
	Def.Quad{
		InitCommand=function(self)
			self:FullScreen():diffuse(0, 0, 0, 0.78)
		end
	},

	-- ── Card ──────────────────────────────────
	Def.ActorFrame{
		InitCommand=function(self) self:xy(_screen.cx, _screen.cy) end,

		-- Card background
		Def.Quad{
			InitCommand=function(self)
				self:zoomto(480, 380):diffuse(0.06, 0.06, 0.06, 0.98)
			end
		},

		-- Top accent bar
		Def.Quad{
			InitCommand=function(self)
				self:y(-190):zoomto(480, 2):diffuse(GetCurrentColor()):diffusealpha(1)
			end
		},

		-- Title
		Def.BitmapText{
			Font="Common Normal",
			Text="FSR MANAGER",
			InitCommand=function(self)
				self:y(-165):zoom(0.62):diffuse(1, 1, 1, 0.92):horizalign(center)
			end
		},

		-- ── Profile info (top right, aligned with title) ──
		Def.ActorFrame{
			InitCommand=function(self) self:xy(200, -165) end,

			Def.BitmapText{
				Font="Common Normal",
				Text="PROFILE",
				InitCommand=function(self)
					self:y(0):zoom(0.30):horizalign(right):diffuse(0.35, 0.35, 0.35, 1)
				end
			},

			Def.BitmapText{
				Font="Common Normal",
				InitCommand=function(self)
					self:y(8):zoom(0.52):horizalign(right):diffuse(1, 1, 1, 0.9)
				end,
				FSRDataReadyMessageCommand=function(self, params)
					local active = params.cur_profile or ""
					self:settext(active ~= "" and active or "None")
				end
			},
		},

		-- ── Status text (loading / error) ─────
		Def.BitmapText{
			Font="Common Normal",
			Name="StatusText",
			Text="Connecting to FSR server...",
			InitCommand=function(self)
				self:y(10):zoom(0.55):diffuse(0.45, 0.45, 0.45, 1):maxwidth(380):horizalign(center)
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

		-- ── Dashboard ─────────────────────────
		Def.ActorFrame{
			Name="Dashboard",
			InitCommand=function(self) self:visible(false) end,
			FSRDataReadyMessageCommand=function(self) self:visible(true) end,
			FSRDataFailedMessageCommand=function(self) self:visible(false) end,
			ShowFSRCommand=function(self) self:visible(false) end,

			-- ── Center: Sensor bars ───────────
			Def.ActorFrame{
				InitCommand=function(self) self:xy(0, -20) end,

				-- Section label
				Def.BitmapText{
					Font="Common Normal",
					Text="LIVE  ·  THRESHOLDS",
					InitCommand=function(self)
						self:y(-88):zoom(0.34):horizalign(center):diffuse(0.35, 0.35, 0.35, 1)
					end
				},

				CreateSensorBar("L", 1, -90),
				CreateSensorBar("D", 2, -30),
				CreateSensorBar("U", 3,  30),
				CreateSensorBar("R", 4,  90),
			},

		},

		-- ── Footer ────────────────────────────
		-- Top rule
		Def.Quad{
			InitCommand=function(self)
				self:y(155):zoomto(440, 1):diffuse(1, 1, 1, 0.06)
			end
		},

		Def.BitmapText{
			Font="Common Normal",
			Text="START  ·  return",
			InitCommand=function(self)
				self:y(168):zoom(0.38):diffuse(0.28, 0.28, 0.28, 1):horizalign(center)
			end
		}
	}
}

return af