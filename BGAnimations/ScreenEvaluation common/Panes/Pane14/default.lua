-- This pane show the comparing score between the Previous Highscore
-- and the actual score

local args = ...
local player, controller = unpack(args)
local pn = ToEnumShortString(player)
if not SL[pn] or not SL[pn].PlayerStatistics then return Def.ActorFrame{} end
local playerPrevSavedHighscore = SL[pn].PlayerStatistics.songHighscore;

return Def.ActorFrame {

    -- score displayed as a percentage
    LoadActor("./Percentage.lua", ...),

    -- labels like "FANTASTIC", "MISS", "holds", "rolls", etc.
    LoadActor("./JudgmentLabels.lua", ...),

    -- numbers (How many Fantastics? How many Misses? etc.)
    LoadActor("./JudgmentNumbers.lua", ...),

    LoadFont("Common Normal") .. {
        Text = playerPrevSavedHighscore.recordDate,
        InitCommand = function(self)
            self:zoom(0.6)
            self:xy(-65 * (controller == PLAYER_1 and 1 or -1), _screen.cy + 118)
        end
    }
}
