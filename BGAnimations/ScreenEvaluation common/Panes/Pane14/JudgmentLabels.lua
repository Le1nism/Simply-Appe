local args = ...
local player, controller = unpack(args)

local pn = ToEnumShortString(player)

-- iterating through the TapNoteScore enum directly isn't helpful because the
-- sequencing is strange, so make our own data structures for this purpose
local TapNoteScores = {
    Types = { 'W0', 'W1', 'W2', 'W3', 'W4', 'W5', 'Miss' },
    Names = {
        THEME:GetString("TapNoteScoreFA+", "W1"),
        THEME:GetString("TapNoteScoreFA+", "W2"),
        THEME:GetString("TapNoteScoreFA+", "W3"),
        THEME:GetString("TapNoteScoreFA+", "W4"),
        THEME:GetString("TapNoteScoreFA+", "W5"),
        THEME:GetString("TapNoteScore", "W5"), -- FA+ mode doesn't have a Way Off window. Extract name from the ITG mode.
        THEME:GetString("TapNoteScoreFA+", "Miss"),
    },
    Colors = {
        SL.JudgmentColors["FA+"][1],
        SL.JudgmentColors["FA+"][2],
        SL.JudgmentColors["FA+"][3],
        SL.JudgmentColors["FA+"][4],
        SL.JudgmentColors["FA+"][5],
        SL.JudgmentColors["ITG"][5], -- FA+ mode doesn't have a Way Off window. Extract color from the ITG mode.
        SL.JudgmentColors["FA+"][6],
    },
}

local RadarCategories = {
    THEME:GetString("ScreenEvaluation", 'Holds'),
    THEME:GetString("ScreenEvaluation", 'Mines'),
    THEME:GetString("ScreenEvaluation", 'Rolls')
}

local t = Def.ActorFrame {
    InitCommand = function(self)
        self:xy(50 * (controller == PLAYER_1 and 1 or -1), _screen.cy - 24)
    end,
}

--  labels: W1, W2, W3, W4, W5, Miss
for i = 1, #TapNoteScores.Types do
    -- no need to add BitmapText actors for TimingWindows that were turned off
    t[#t + 1] = LoadFont("Common Normal") .. {
        Text = TapNoteScores.Names[i]:upper(),
        InitCommand = function(self) self:zoom(0.7):horizalign(right):maxwidth(76) end,
        BeginCommand = function(self)
            self:x(controller == PLAYER_1 and 15 or -45)
            self:y((i - 1) * 25.5 - 17.5)
            -- diffuse the JudgmentLabels the appropriate colors for the current GameMode
            self:diffuse(TapNoteScores.Colors[i])
        end
    }
end

-- labels: hands/ex, holds, mines, rolls
for index, label in ipairs(RadarCategories) do
    t[#t + 1] = LoadFont("Common Normal") .. {
        Text = label,
        InitCommand = function(self) self:zoom(0.833):horizalign(right) end,
        BeginCommand = function(self)
            self:x(controller == PLAYER_1 and -163 or 78)
            self:y(index * 28 + 41)
        end
    }
end

return t
