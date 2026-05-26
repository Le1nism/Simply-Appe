local af = Def.ActorFrame{
    InitCommand=function(self) self:visible(false) end,

    -- React to data being fetched (from ScreenSelectProfile or SSM fallback)
    SRPGDataReadyMessageCommand=function(self)
        Trace("[SRPG] SRPGDataReady received in SRPG9.lua")
        -- If the overlay is currently visible, refresh it immediately
        if self:GetVisible() then
            local rows = SRPG_DATA or {}
            self:playcommand("SetData", rows)
        end
    end,

    ShowSRPG9Command=function(self)
        self:visible(true)
        -- Use in-memory data if available, otherwise show loading state
        local rows = SRPG_DATA
        if rows and #rows > 0 then
            self:playcommand("SetData", rows)
        else
            self:playcommand("SetData", {{
                title = "Fetching data...",
                bpm_base = "-",
                diff = "-",
                rate = "-",
                score = "-",
                duration_sec = "-",
                xp = "-"
            }})
        end
    end,

    HideSRPG9Command=function(self) self:visible(false) end,

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

        -- Title shows player name once loaded
        Def.BitmapText{
            Font="Common Bold",
            Text="SRPG9 Companion",
            InitCommand=function(self) self:y(-180):zoom(0.9):diffuse(Color.White) end,
            SRPGDataReadyMessageCommand=function(self)
                if SRPG_PLAYER then
                    self:settext("SRPG9 — " .. SRPG_PLAYER)
                end
            end,
            ShowSRPG9Command=function(self)
                self:settext(SRPG_PLAYER and ("SRPG9 — " .. SRPG_PLAYER) or "SRPG9 Companion")
            end,
        },

        Def.BitmapText{ Font="Common Normal", Text="TITLE", InitCommand=function(self) self:xy(-240,-130):zoom(0.5):horizalign(left):diffuse(color("#aaaaff")) end },
        Def.BitmapText{ Font="Common Normal", Text="BPM",   InitCommand=function(self) self:xy(-45, -130):zoom(0.5):horizalign(right):diffuse(color("#aaaaff")) end },
        Def.BitmapText{ Font="Common Normal", Text="DIFF",  InitCommand=function(self) self:xy(5,   -130):zoom(0.5):horizalign(right):diffuse(color("#aaaaff")) end },
        Def.BitmapText{ Font="Common Normal", Text="RATE",  InitCommand=function(self) self:xy(55,  -130):zoom(0.5):horizalign(right):diffuse(color("#aaaaff")) end },
        Def.BitmapText{ Font="Common Normal", Text="SCORE", InitCommand=function(self) self:xy(115, -130):zoom(0.5):horizalign(right):diffuse(color("#aaaaff")) end },
        Def.BitmapText{ Font="Common Normal", Text="TIME",  InitCommand=function(self) self:xy(175, -130):zoom(0.5):horizalign(right):diffuse(color("#aaaaff")) end },
        Def.BitmapText{ Font="Common Normal", Text="XP",    InitCommand=function(self) self:xy(240, -130):zoom(0.5):horizalign(right):diffuse(color("#aaaaff")) end },

        Def.Quad{
            InitCommand=function(self) self:y(-115):zoomto(490,1):diffuse(0.5,0.5,0.5,0.8) end
        },

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

-- Dynamic row generation
local max_rows = 10
local start_y = -85
local row_spacing = 25

for i = 1, max_rows do
    local current_y = start_y + ((i - 1) * row_spacing)

    af[#af+1] = Def.ActorFrame{
        InitCommand=function(self) self:xy(_screen.cx, _screen.cy + current_y) end,
        SetDataCommand=function(self, rows)
            self:visible(rows[i] ~= nil)
        end,

        Def.BitmapText{
            Font="Common Normal",
            InitCommand=function(self) self:x(-240):zoom(0.7):horizalign(left):maxwidth(185) end,
            SetDataCommand=function(self, rows) if rows[i] then self:settext(rows[i].title) end end
        },
        Def.BitmapText{
            Font="Common Normal",
            InitCommand=function(self) self:x(-45):zoom(0.7):horizalign(right) end,
            SetDataCommand=function(self, rows) if rows[i] then self:settext(tostring(rows[i].bpm_base)) end end
        },
        Def.BitmapText{
            Font="Common Normal",
            InitCommand=function(self) self:x(5):zoom(0.7):horizalign(right) end,
            SetDataCommand=function(self, rows) if rows[i] then self:settext(tostring(rows[i].diff)) end end
        },
        Def.BitmapText{
            Font="Common Normal",
            InitCommand=function(self) self:x(55):zoom(0.7):horizalign(right) end,
            SetDataCommand=function(self, rows) if rows[i] then self:settext(tostring(rows[i].rate)) end end
        },
        Def.BitmapText{
            Font="Common Normal",
            InitCommand=function(self) self:x(115):zoom(0.7):horizalign(right) end,
            SetDataCommand=function(self, rows) if rows[i] then self:settext(tostring(rows[i].score)) end end
        },
        Def.BitmapText{
            Font="Common Normal",
            InitCommand=function(self) self:x(175):zoom(0.7):horizalign(right) end,
            SetDataCommand=function(self, rows) if rows[i] then self:settext(tostring(rows[i].duration_sec)) end end
        },
        Def.BitmapText{
            Font="Common Normal",
            InitCommand=function(self) self:x(240):zoom(0.7):horizalign(right) end,
            SetDataCommand=function(self, rows) if rows[i] then self:settext(tostring(rows[i].xp)) end end
        },
    }
end

return af