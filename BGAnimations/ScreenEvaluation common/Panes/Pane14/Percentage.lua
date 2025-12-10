local args = ...
local player, controller = unpack(args)
local pn = ToEnumShortString(player)
if not SL[pn] or not SL[pn].PlayerStatistics then return Def.ActorFrame{} end

local playerPrevHighscore = SL[pn].PlayerStatistics.songHighscore;
local curPlayerStats = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)

-- ITG percent
local prevPercent = playerPrevHighscore.percent
local curPercent = FormatPercentScore(curPlayerStats:GetPercentDancePoints()):gsub("%%", "")
local percentDiff = curPercent - prevPercent

-- EX percent
local prevExScore = playerPrevHighscore.exScore or 0
local curExScore = CalculateExScore(player)
local exScoreDiff = curExScore - prevExScore

local showExScore = false

return Def.ActorFrame {
    Name = "PercentageContainer" .. pn,
    OnCommand = function(self)
        self:y(_screen.cy - 26)
        self:queuecommand("ShowITGExScore")
    end,
    ShowITGExScoreCommand = function(self)
        local ITGPercent = self:GetChild("ITGPercentAF")
        local ExScore = self:GetChild("ExScoreAF")

        ITGPercent:diffusealpha(showExScore and 0 or 1)
        ExScore:diffusealpha(showExScore and 1 or 0)

        if showExScore then showExScore = false else showExScore = true end

        self:sleep(2):queuecommand("ShowITGExScore")
    end,

    -- dark background quad behind player percent score
    Def.Quad {
        InitCommand = function(self)
            self:diffuse(color("#101519")):zoomto(158.5, 88)
            self:horizalign(controller == PLAYER_1 and left or right)
            self:x(150 * (controller == PLAYER_1 and -1 or 1))
            self:y(14)
        end
    },

    Def.ActorFrame {
        Name = "ITGPercentAF",
        InitCommand = function(self)
            self:diffusealpha(0)
        end,
        LoadFont("Wendy/_wendy white") .. {
            Name = "Percent",
            Text = ("%.2f"):format(playerPrevHighscore.percent),
            InitCommand = function(self)
                self:horizalign(right):zoom(0.585)
                self:x((controller == PLAYER_1 and 1.5 or 141))
                self:diffuse(Color.White)
            end
        },

        LoadFont("Wendy/_wendy white") .. {
            Name = "PercentDifference",
            Text = (percentDiff >= 0 and '+' or '') .. ("%.2f"):format(percentDiff),
            InitCommand = function(self)
                self:zoom(0.4):horizalign(right)
                self:x(controller == PLAYER_1 and 1.5 or 141)
                self:y(38)

                if percentDiff < 0 then
                    -- Red if not better
                    self:diffuse(SL.JudgmentColors["ITG"][6])
                else
                    -- Green if you have done better
                    self:diffuse(SL.JudgmentColors["ITG"][3])
                end
            end
        }
    },
    Def.ActorFrame {
        Name = "ExScoreAF",
        InitCommand = function(self)
            self:diffusealpha(0)
        end,
        LoadFont("Wendy/_wendy white") .. {
            Name = "ExScore",
            Text = ("%.2f"):format(prevExScore),
            InitCommand = function(self)
                self:horizalign(right):zoom(0.585)
                self:x((controller == PLAYER_1 and 1.5 or 141))
                self:diffuse(SL.JudgmentColors["FA+"][1])
            end
        },

        LoadFont("Wendy/_wendy white") .. {
            Name = "ExScoreDifference",
            Text = (exScoreDiff >= 0 and '+' or '') .. ("%.2f"):format(exScoreDiff),
            InitCommand = function(self)
                self:zoom(0.4):horizalign(right)
                self:x(controller == PLAYER_1 and 1.5 or 141)
                self:y(38)

                if exScoreDiff < 0 then
                    -- Red if not better
                    self:diffuse(SL.JudgmentColors["ITG"][6])
                else
                    -- Green if you have done better
                    self:diffuse(SL.JudgmentColors["ITG"][3])
                end
            end
        }
    }
}
