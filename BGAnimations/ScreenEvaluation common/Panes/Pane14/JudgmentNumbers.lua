local args = ...
local player, controller = unpack(args)

local pn = ToEnumShortString(player)
if not SL[pn] or not SL[pn].PlayerStatistics then return Def.ActorFrame{} end
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
local playerPrevHighScore = SL[pn].PlayerStatistics.songHighscore;
local currentCounts = GetExJudgmentCounts(player)

local TapNoteScores = {
    Types = { 'W0', 'W1', 'W2', 'W3', 'W4', 'W5', 'Miss' },
    Colors = {
        SL.JudgmentColors["FA+"][1],
        SL.JudgmentColors["FA+"][2],
        SL.JudgmentColors["FA+"][3],
        SL.JudgmentColors["FA+"][4],
        SL.JudgmentColors["FA+"][5],
        SL.JudgmentColors["ITG"][5], -- FA+ mode doesn't have a Way Off window. Extract color from the ITG mode.
        SL.JudgmentColors["FA+"][6],
    },
    -- x values for P1 and P2
    x = { P1 = 25, P2 = 51 }
}

local RadarCategories = {
    Types = { 'Holds', 'Mines', 'Rolls' },
    -- x values for P1 and P2
    -- x = { P1 = -180, P2 = 218 }
    x = { P1 = -200, P2 = 198 }
}


local t = Def.ActorFrame {
    InitCommand = function(self) self:zoom(0.8):xy(90, _screen.cy - 24) end,
    OnCommand = function(self)
        -- shift the x position of this ActorFrame to -90 for PLAYER_2
        if controller == PLAYER_2 then
            self:x(self:GetX() * -1)
        end
    end
}

-- do "regular" TapNotes first
for i = 1, #TapNoteScores.Types do
    local window = TapNoteScores.Types[i]
    local prevJudgementCount = playerPrevHighScore[window] or 0
    local curJudgmentCount = currentCounts[window] or 0
    local judgmentCountDiff = curJudgmentCount - prevJudgementCount

    -- judgment numbers previous highscore
    t[#t + 1] = Def.RollingNumbers {
        Font = "Wendy/_ScreenEvaluation numbers",
        InitCommand = function(self)
            self:zoom(0.35):horizalign(right)

            self:diffuse(TapNoteScores.Colors[i])

            self:Load("RollingNumbersEvaluationA")
        end,
        BeginCommand = function(self)
            self:x(TapNoteScores.x[ToEnumShortString(controller)])
            self:y((i - 1) * 32 - 22)
            self:targetnumber(prevJudgementCount)
        end
    }

    -- difference
    t[#t + 1] = LoadFont("Wendy/_wendy white") .. {
        Text = (judgmentCountDiff >= 0 and '+' or '') .. judgmentCountDiff,
        InitCommand = function(self)
            self:zoom(0.22):horizalign(right)
            self:x(TapNoteScores.x[ToEnumShortString(controller)] + 45)
            self:y((i - 1) * 32 - 22)

            if judgmentCountDiff <= 0 then
                -- if not fantastic the minus count is good
                self:diffuse(SL.JudgmentColors["ITG"][i == 1 and 6 or 3])
            else
                self:diffuse(SL.JudgmentColors["ITG"][i == 1 and 3 or 6])
            end
        end
    }
end

-- then handle hands/ex, holds, mines, rolls
for index, RCType in ipairs(RadarCategories.Types) do
    local curPerformance = pss:GetRadarActual():GetValue("RadarCategory_" .. RCType)
    local prevPerformance = playerPrevHighScore[RCType]
    local performanceDiff = curPerformance - prevPerformance
    local possible = pss:GetRadarPossible():GetValue("RadarCategory_" .. RCType)
    possible = clamp(possible, 0, 999)

    -- player performance value
    -- use a RollingNumber to animate the count tallying up for visual effect
    t[#t + 1] = Def.RollingNumbers {
        Font = "Wendy/_ScreenEvaluation numbers",
        InitCommand = function(self) self:zoom(0.4):horizalign(right):Load("RollingNumbersEvaluationB") end,
        BeginCommand = function(self)
            self:x(RadarCategories.x[ToEnumShortString(controller)])
            self:y(index * 35 + 53)
            self:targetnumber(prevPerformance)
        end
    }

    -- difference
    t[#t + 1] = LoadFont("Wendy/_wendy white") .. {
        Text = (performanceDiff >= 0 and '+' or '') .. performanceDiff,
        InitCommand = function(self)
            self:zoom(0.25):horizalign(right)
            self:x(RadarCategories.x[ToEnumShortString(controller)] + 42)
            self:y(index * 35 + 53)

            if performanceDiff < 0 then
                self:diffuse(SL.JudgmentColors["ITG"][6])
            else
                self:diffuse(SL.JudgmentColors["ITG"][3])
            end
        end
    }

    -- slash and possible value
    t[#t + 1] = LoadFont("Wendy/_ScreenEvaluation numbers") .. {
        InitCommand = function(self) self:zoom(0.4):horizalign(right) end,
        BeginCommand = function(self)
            --self:x(controller == PLAYER_1 and -114 or 286)
            self:x(controller == PLAYER_1 and -102 or 295)
            self:y(index * 35 + 53)
            self:settext(("/%03d"):format(possible))
            local leadingZeroAttr = { Length = 4 - tonumber(tostring(possible):len()), Diffuse = color("#5A6166") }
            self:AddAttribute(0, leadingZeroAttr)
        end
    }
end

return t
