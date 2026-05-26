local json_path = THEME:GetCurrentThemeDirectory() .. "srpg_data.json"

local function LoadAllRows()
    if FILEMAN:DoesFileExist(json_path) then
        local content = lua.ReadFile(json_path)
        if content and #content > 0 then
            local data = JsonDecode(content)
            if data and #data > 0 then
                return data
            end
        end
    end
    return nil
end

local af = Def.ActorFrame{
    InitCommand=function(self) self:visible(false) end,
    ShowSRPG9Command=function(self)
        self:visible(true)
        local rows = LoadAllRows()
        if rows then
            -- Send whole table to all ActorFrame children
            self:playcommand("SetData", rows)
        else
            -- Fallback for empty/nonexistent file
            self:playcommand("SetData", {{
                title = "No data found",
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

        -- Card border
        Def.Quad{
            InitCommand=function(self) self:zoomto(524, 424):diffuse(Color.White) end
        },
        -- Card background
        Def.Quad{
            InitCommand=function(self) self:zoomto(520, 420):diffuse(Color.Black) end
        },

        -- Title
        Def.BitmapText{
            Font="Common Bold",
            Text="SRPG9 Companion",
            InitCommand=function(self) self:y(-180):zoom(0.9):diffuse(Color.White) end
        },

        -- Table Headers
        Def.BitmapText{ Font="Common Normal", Text="TITLE", InitCommand=function(self) self:xy(-240, -130):zoom(0.5):horizalign(left):diffuse(color("#aaaaff")) end },
        Def.BitmapText{ Font="Common Normal", Text="BPM",   InitCommand=function(self) self:xy(-45, -130):zoom(0.5):horizalign(right):diffuse(color("#aaaaff")) end },
        Def.BitmapText{ Font="Common Normal", Text="DIFF",  InitCommand=function(self) self:xy(5, -130):zoom(0.5):horizalign(right):diffuse(color("#aaaaff")) end },
        Def.BitmapText{ Font="Common Normal", Text="RATE",  InitCommand=function(self) self:xy(55, -130):zoom(0.5):horizalign(right):diffuse(color("#aaaaff")) end },
        Def.BitmapText{ Font="Common Normal", Text="SCORE", InitCommand=function(self) self:xy(115, -130):zoom(0.5):horizalign(right):diffuse(color("#aaaaff")) end },
        Def.BitmapText{ Font="Common Normal", Text="TIME",  InitCommand=function(self) self:xy(175, -130):zoom(0.5):horizalign(right):diffuse(color("#aaaaff")) end },
        Def.BitmapText{ Font="Common Normal", Text="XP",    InitCommand=function(self) self:xy(240, -130):zoom(0.5):horizalign(right):diffuse(color("#aaaaff")) end },

        -- Separator Line
        Def.Quad{
            InitCommand=function(self) self:y(-115):zoomto(490, 1):diffuse(0.5,0.5,0.5,0.8) end
        },

        -- Go back prompt
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
local start_y = -85   -- First row Y coord
local row_spacing = 25 -- Vertical spacing between rows

for i = 1, max_rows do
    local current_y = start_y + ((i - 1) * row_spacing)

    af[#af+1] = Def.ActorFrame{
        InitCommand=function(self) self:xy(_screen.cx, _screen.cy + current_y) end,
        SetDataCommand=function(self, rows)
            -- If exists in the JSON show it, if not hide it
            if rows[i] then
                self:visible(true)
            else
                self:visible(false)
            end
        end,

        -- Song title
        Def.BitmapText{
            Font="Common Normal",
            InitCommand=function(self) self:x(-240):zoom(0.7):horizalign(left):maxwidth(185) end,
            SetDataCommand=function(self, rows) if rows[i] then self:settext(rows[i].title) end end
        },
        -- BPM
        Def.BitmapText{
            Font="Common Normal",
            InitCommand=function(self) self:x(-45):zoom(0.7):horizalign(right) end,
            SetDataCommand=function(self, rows) if rows[i] then self:settext(tostring(rows[i].bpm_base)) end end
        },
        -- Block
        Def.BitmapText{
            Font="Common Normal",
            InitCommand=function(self) self:x(5):zoom(0.7):horizalign(right) end,
            SetDataCommand=function(self, rows) if rows[i] then self:settext(tostring(rows[i].diff)) end end
        },
        -- Rate
        Def.BitmapText{
            Font="Common Normal",
            InitCommand=function(self) self:x(55):zoom(0.7):horizalign(right) end,
            SetDataCommand=function(self, rows) if rows[i] then self:settext(tostring(rows[i].rate)) end end
        },
        -- Score
        Def.BitmapText{
            Font="Common Normal",
            InitCommand=function(self) self:x(115):zoom(0.7):horizalign(right) end,
            SetDataCommand=function(self, rows) if rows[i] then self:settext(tostring(rows[i].score)) end end
        },
        -- Length
        Def.BitmapText{
            Font="Common Normal",
            InitCommand=function(self) self:x(175):zoom(0.7):horizalign(right) end,
            SetDataCommand=function(self, rows) if rows[i] then self:settext(tostring(rows[i].duration_sec)) end end
        },
        -- XP
        Def.BitmapText{
            Font="Common Normal",
            InitCommand=function(self) self:x(240):zoom(0.7):horizalign(right) end,
            SetDataCommand=function(self, rows) if rows[i] then self:settext(tostring(rows[i].xp)) end end
        }
    }
end

return af