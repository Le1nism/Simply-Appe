GetPlayerStatistics = function(pn, dir)
    local songsHighscoresPath = dir .. "songs-highscores.json";
    local starsGradesCount = dir .. "grades-counts.json";

    -- If at least one of the file doesn't exists, treat them as non-existing
    if not FILEMAN:DoesFileExist(songsHighscoresPath) then return end
    if not FILEMAN:DoesFileExist(starsGradesCount) then return end

    SL[pn].PlayerStatistics.songsHighscores = ReadJSONFile(songsHighscoresPath)
    SL[pn].PlayerStatistics.gradesCounts = ReadJSONFile(starsGradesCount)
end

SavePlayerStatistics = function(pn, dir)
    local songsHighscoresPath = dir .. "songs-highscores.json";
    local starsGradesCount = dir .. "grades-counts.json";

    WriteJSONFile(songsHighscoresPath, SL[pn].PlayerStatistics.songsHighscores);
    WriteJSONFile(starsGradesCount, SL[pn].PlayerStatistics.gradesCounts);
end

UpdatePlayerStatistics = function(player)
    local todayDate = ("%04d-%02d-%02d"):format(Year(), MonthOfYear() + 1, DayOfMonth())
    local todayDateHour = ("%04d-%02d-%02d %02d:%02d:%02d"):format(Year(), MonthOfYear() + 1, DayOfMonth(), Hour(),
        Minute(), Second())

    local pn = ToEnumShortString(player)
    local hash = SL[pn].Streams.Hash

    local currStageStats = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
    local currEarnedGrade = currStageStats:GetGrade()
    local currEarnedGradeTier = currEarnedGrade:gsub("Grade_", "")

    local currentCounts = GetExJudgmentCounts(player)
    local currExScore = CalculateExScore(player)

    -- Quint
    if currEarnedGradeTier == "Tier01" and ("%.2f"):format(currExScore) == "100.00" then
        currEarnedGradeTier = "Tier00"
    end

    local gradeNumStr = (currEarnedGradeTier == "Failed" and "Tier98" or currEarnedGradeTier):gsub("Tier", "")

    local currPlayerStats = {
        grade = currEarnedGradeTier,
        gradeNumber = tonumber(gradeNumStr),
        numTimesPlayed = 1,
        lastPlayedDate = todayDate,
        percent = ("%.2f"):format(currStageStats:GetPercentDancePoints() * 100),
        exScore = ("%.2f"):format(currExScore),
        W0 = currentCounts.W0,
        W1 = currentCounts.W1,
        W2 = currentCounts.W2,
        W3 = currentCounts.W3,
        W4 = currentCounts.W4,
        W5 = currentCounts.W5,
        Miss = currentCounts.Miss,
        Mines = currStageStats:GetRadarActual():GetValue("RadarCategory_Mines"),
        Holds = currStageStats:GetRadarActual():GetValue("RadarCategory_Holds"),
        Rolls = currStageStats:GetRadarActual():GetValue("RadarCategory_Rolls"),
        recordDate = todayDateHour
    }

    local savedStats = SL[pn].PlayerStatistics.songsHighscores[hash];

    -- If not exists create new
    if not savedStats then
        SL[pn].PlayerStatistics.songsHighscores[hash] = currPlayerStats;

        local GradeCount = SL[pn].PlayerStatistics.gradesCounts[currEarnedGrade]
        SL[pn].PlayerStatistics.gradesCounts[currEarnedGrade] = GradeCount + 1
    else
        local prevGrade = "Grade_" .. savedStats.grade
        local savedTimesPlayed = SL[pn].PlayerStatistics.songsHighscores[hash].numTimesPlayed or 0

        currPlayerStats.numTimesPlayed = savedTimesPlayed + 1

        -- if i have a best grade or, for the same grade, a better score --> save the new values
        if (currPlayerStats.gradeNumber < savedStats.gradeNumber or currPlayerStats.exScore > (savedStats.exScore or "0")) then
            SL[pn].PlayerStatistics.songsHighscores[hash] = currPlayerStats

            local prevGradeCount = SL[pn].PlayerStatistics.gradesCounts[prevGrade]
            SL[pn].PlayerStatistics.gradesCounts[prevGrade] = prevGradeCount - 1

            local actualGradeCount = SL[pn].PlayerStatistics.gradesCounts[currEarnedGrade]
            SL[pn].PlayerStatistics.gradesCounts[currEarnedGrade] = actualGradeCount + 1
        else
            -- if is not a best score just update the last time played and the number of times
            SL[pn].PlayerStatistics.songsHighscores[hash].lastPlayedDate = currPlayerStats
                .lastPlayedDate
            SL[pn].PlayerStatistics.songsHighscores[hash].numTimesPlayed = currPlayerStats
                .numTimesPlayed
        end
    end

    SL[pn].PlayerStatistics.songHighscore = savedStats or {
        grade = "Tier99",
        gradeNumber = tonumber("99"),
        numTimesPlayed = 1,
        lastPlayedDate = nil,
        percent = tostring(0),
        exScore = tostring(0),
        W0 = 0,
        W1 = 0,
        W2 = 0,
        W3 = 0,
        W4 = 0,
        W5 = 0,
        Miss = 0,
        Mines = 0,
        Holds = 0,
        Rolls = 0,
        recordDate = todayDateHour
    }
end
