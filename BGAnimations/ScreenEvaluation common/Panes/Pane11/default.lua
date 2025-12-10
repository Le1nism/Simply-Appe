-- Pane11 display the GrooveStats EX leaderboard

if not IsServiceAllowed(SL.GrooveStats.AutoSubmit) then return end

local args = ...
local player, controller = unpack(args)

local pane = Def.ActorFrame {
    InitCommand = function(self)
        self:y(_screen.cy - 62):zoom(0.8)
        self:visible(false)
    end,
    FillLeaderboardCommand = function(self, params)
        local highscorelist = self:GetChild("HighScoreList")
        local leaderboardName = "exLeaderboard"

        if not params.leaderboard or not params.leaderboard[leaderboardName] then
            self:visible(false)
            return
        end

        local entryCount = 0

        for entry in ivalues(params.leaderboard[leaderboardName]) do
            entryCount = entryCount + 1

            local row = highscorelist:GetChild("HighScoreEntry" .. entryCount)
            row:stoptweening()
            row:diffuse(Color.White)

            row:GetChild("Rank"):settext(tostring(entry["rank"]) .. ".")
            row:GetChild("Name"):settext(entry["name"])
            row:GetChild("Score"):settext(string.format("%.2f%%", entry["score"] / 100))
            row:GetChild("Date"):settext(ParseGroovestatsDate(entry["date"]))

            if entry["isSelf"] then
                row:diffuse(GSLeaderboardColors.Profile)
            elseif entry["isRival"] then
                row:diffuse(GSLeaderboardColors.Rival)
            else
                row:GetChild("Score"):diffuse(GSLeaderboardColors.EX)
            end
        end

        self:visible(entryCount == 0 and false or true)
    end,
    SkipPaneCommand = function(self)
        self:visible(false)
    end,

    Def.Sprite {
        Texture = THEME:GetPathG("", "GrooveStats.png"),
        Name = "GrooveStats_Logo",
        InitCommand = function(self)
            self:zoom(1.5)
            self:addx(0):addy(100)
            self:diffusealpha(0.5)
        end,
    },

    LoadFont("Common Normal") .. {
        Name = "EX",
        Text = "EX",
        InitCommand = function(self)
            self:diffuse(color("#adadad"))
            self:zoom(1.75):diffusealpha(0.3)
            self:xy(2, 90)
        end
    },

    -- 22px RowHeight by default, which works for displaying 10 machine HighScores
    LoadActor(THEME:GetPathB("", "_modules/HighScoreList.lua"), {
        Player = player,
        RowHeight = 22,
        HideScores = true,
        NumHighScores = 10
    }),
}

return pane
