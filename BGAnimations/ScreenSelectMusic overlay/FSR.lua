local af = Def.ActorFrame{
	InitCommand=function(self) self:visible(false) end,

	ShowFSRCommand=function(self)
		self:visible(true)
	end,

	HideFSRCommand=function(self) self:visible(false) end,

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

		-- Dummy texts
		Def.BitmapText{
			Font="Common Normal",
			Text="FSR Settings & Options",
			InitCommand=function(self) self:y(-50):zoom(0.8):diffuse(color("#aaaaff")) end,
		},
		Def.BitmapText{
			Font="Common Normal",
			Text="This is a placeholder for the FSR Manager.",
			InitCommand=function(self) self:y(0):zoom(0.7):diffuse(Color.White) end,
		},
		Def.BitmapText{
			Font="Common Normal",
			Text="Real functions and dynamic options will be added here.",
			InitCommand=function(self) self:y(30):zoom(0.7):diffuse(0.7,0.7,0.7,1) end,
		},

		-- Go Back Prompt
		Def.BitmapText{
			Font="Common Bold",
			Text="Press ENTER to go back",
			InitCommand=function(self) self:y(180):zoom(0.7) end,
			OnCommand=function(self)
				self:diffuseshift():effectcolor1(1,1,1,1):effectcolor2(0.5,0.5,0.5,1):effectperiod(1.5)
			end
		}
	}
}

return af
