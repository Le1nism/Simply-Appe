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

local function CreateSensorPanel(name, index, x, y)
	return Def.ActorFrame{
		InitCommand=function(self) self:xy(x, y) end,

		-- Outer Border
		Def.Quad{
			InitCommand=function(self) self:zoomto(74, 54):diffuse(0.4, 0.4, 0.4, 1) end
		},
		-- Inner Background
		Def.Quad{
			InitCommand=function(self) self:zoomto(70, 50):diffuse(0.08, 0.08, 0.08, 1) end
		},

		-- Direction Name
		Def.BitmapText{
			Font="Common Normal",
			Text=name,
			InitCommand=function(self) self:y(-14):zoom(0.45):diffuse(color("#aaaaff")) end
		},

		-- Threshold Value
		Def.BitmapText{
			Font="Common Bold",
			Text="-",
			InitCommand=function(self) self:y(8):zoom(0.65):diffuse(Color.White) end,
			FSRDataReadyMessageCommand=function(self, params)
				local thresholds = params.thresholds or {}
				local val = thresholds[index]
				if val then
					self:settext(tostring(val))
				else
					self:settext("-")
				end
			end
		}
	}
end

local af = Def.ActorFrame{
	InitCommand=function(self) self:visible(false) end,

	ShowFSRCommand=function(self)
		self:visible(true)
		self:playcommand("FetchFSRData")
	end,

	HideFSRCommand=function(self) self:visible(false) end,

	FetchFSRDataCommand=function(self)
		self:playcommand("SetStatus", { status = "loading", message = "Fetching FSR settings..." })
		FetchFSRData()
	end,

	-- Background dim
	Def.Quad{
		InitCommand=function(self) self:FullScreen():diffuse(0,0,0,0.85) end
	},

	-- Card Frame
	Def.ActorFrame{
		InitCommand=function(self) self:xy(_screen.cx, _screen.cy) end,

		Def.Quad{
			InitCommand=function(self) self:zoomto(524, 424):diffuse(Color.White) end
		},
		Def.Quad{
			InitCommand=function(self) self:zoomto(520, 420):diffuse(Color.Black) end
		},

		-- Title
		Def.BitmapText{
			Font="Common Bold",
			Text="FSR Manager",
			InitCommand=function(self) self:y(-180):zoom(0.9):diffuse(Color.White) end,
		},

		-- Status Text
		Def.BitmapText{
			Font="Common Normal",
			Name="StatusText",
			Text="Fetching FSR settings...",
			InitCommand=function(self) self:y(0):zoom(0.8):diffuse(Color.White):maxwidth(400) end,
			SetStatusCommand=function(self, params)
				if params.status == "loading" then
					self:visible(true):settext(params.message):diffuse(Color.White)
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

			-- Left Side: Profiles
			Def.ActorFrame{
				InitCommand=function(self) self:x(-130) end,

				Def.BitmapText{
					Font="Common Normal",
					Text="PROFILES",
					InitCommand=function(self) self:y(-110):zoom(0.6):horizalign(left):diffuse(color("#aaaaff")) end
				},

				-- Active Profile Text
				Def.BitmapText{
					Font="Common Normal",
					InitCommand=function(self) self:y(-75):zoom(0.7):horizalign(left) end,
					FSRDataReadyMessageCommand=function(self, params)
						local active = params.cur_profile or ""
						if active == "" then active = "[None]" end
						self:settext("Active: " .. active):diffuse(color("#88ff88"))
					end
				},

				-- List of all profiles (supports up to 6 profiles)
				(function()
					local t = Def.ActorFrame{}
					local max_profiles_display = 6
					for idx = 1, max_profiles_display do
						t[#t+1] = Def.BitmapText{
							Font="Common Normal",
							InitCommand=function(self) self:y(-40 + (idx-1)*25):zoom(0.65):horizalign(left) end,
							FSRDataReadyMessageCommand=function(self, params)
								local profiles = params.profiles or {}
								local name = profiles[idx]
								if name then
									self:visible(true):settext("- " .. name)
									if name == params.cur_profile then
										self:diffuse(color("#ffff88"))
									else
										self:diffuse(Color.White)
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

			-- Right Side: Sensor Thresholds Cross
			Def.ActorFrame{
				InitCommand=function(self) self:x(120) end,

				Def.BitmapText{
					Font="Common Normal",
					Text="THRESHOLDS",
					InitCommand=function(self) self:y(-110):zoom(0.6):horizalign(center):diffuse(color("#aaaaff")) end
				},

				CreateSensorPanel("UP",    3, 0,   -45),
				CreateSensorPanel("LEFT",  1, -85, 5),
				CreateSensorPanel("RIGHT", 4, 85,  5),
				CreateSensorPanel("DOWN",  2, 0,   55),
			}
		},

		-- Go Back & Reload Prompts
		Def.BitmapText{
			Font="Common Bold",
			Text="SELECT to reload • START to go back",
			InitCommand=function(self) self:y(180):zoom(0.65) end,
			OnCommand=function(self)
				self:diffuseshift():effectcolor1(1,1,1,1):effectcolor2(0.5,0.5,0.5,1):effectperiod(1.5)
			end
		}
	}
}

return af
