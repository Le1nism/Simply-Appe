local player = ...
local PlayerState = GAMESTATE:GetPlayerState(player)

local NoteFieldIsCentered = (GetNotefieldX(player) == _screen.cx)
local IsUltraWide = (GetScreenAspectRatio() > 21 / 9)

local af = Def.ActorFrame {}

af.InitCommand = function(self)
    self:x(SL_WideScale(150, 202) * (player == PLAYER_1 and -1 or 1))
    self:y(25)

    if NoteFieldIsCentered and IsUsingWideScreen() then
        self:x(154 * (player == PLAYER_1 and -1 or 1))
    end

    -- flip alignment when ultrawide and both players joined
    if IsUltraWide and #GAMESTATE:GetHumanPlayers() > 1 then
        self:x(self:GetX() * -1)
    end
end

local FormatGroup = function(song)
    if song then
        local fmt = "%s: %s"
        return fmt:format("Pack", song:GetGroupName())
    end
    return ""
end

local FormatSongArtist = function(song)
    if song then
        local fmt = "%s: %s"
        return fmt:format("Artist", song:GetDisplayArtist())
    end
    return ""
end

local GetSongAndSteps = function(player)
    local song = GAMESTATE:GetCurrentSong()
    local steps = GAMESTATE:GetCurrentSteps(player)

    return song, steps
end

local getAuthorTable = function(steps)
    -- Returns a table of max 3 rows of step data
    -- like step author, chart artist, tech notation, stream breakdown,  meme quotes
    local desc = steps:GetDescription()
    local author_table = {}

    if desc ~= "" then
        author_table[#author_table + 1] = desc
    end

    local cred = steps:GetAuthorCredit()
    if cred ~= "" and (not FindInTable(cred, author_table)) then
        author_table[#author_table + 1] = cred
    end

    local name = steps:GetChartName()
    if name ~= "" and (not FindInTable(name, author_table)) then
        author_table[#author_table + 1] = name
    end

    return author_table
end

af[#af + 1] = LoadFont("Common Normal") .. {
    Name = "StepsInfo_SongArtist",
    InitCommand = function(self)
        self:xy(0, -20)
        self:zoom(0.75)
        self:maxwidth(250)
        self:halign(PlayerNumber:Reverse()[player]):vertalign(bottom)

        if IsUltraWide and #GAMESTATE:GetHumanPlayers() > 1 then
            self:halign(PlayerNumber:Reverse()[OtherPlayer[player]])
            self:x(50 * (player == PLAYER_1 and -1 or 1))
        end

        self:queuecommand("CurrentSongChangedMessage")
    end,
    CurrentSongChangedMessageCommand = function(self, params)
        self:settext(FormatSongArtist(GAMESTATE:GetCurrentSong()))
    end
}

af[#af + 1] = LoadFont("Common Normal") .. {
    Name = "StepsInfo_StepArtist",
    InitCommand = function(self)
        self:xy(0, 0)
        self:zoom(0.75)
        self:maxwidth(250)
        self:halign(PlayerNumber:Reverse()[player]):vertalign(bottom)

        if IsUltraWide and #GAMESTATE:GetHumanPlayers() > 1 then
            self:halign(PlayerNumber:Reverse()[OtherPlayer[player]])
            self:x(50 * (player == PLAYER_1 and -1 or 1))
        end

        self:queuecommand("CurrentSongChangedMessage")
    end,
    OnCommand = function(self)
        -- Reset the text (mainly for course mode)
        self:settext("")
        author_table = {}

        -- it returns an error if I take this part out idk why
        local song, steps = GetSongAndSteps(player)

        author_table = getAuthorTable(steps)

        marquee_index = 0
        -- Loop the author field
        if #author_table > 0 then
            self:queuecommand("Marquee")
        else
            self:settext("")
        end
        if #author_table > 1 then
            self:queuecommand("Marquee")
        end
    end,
    CurrentSongChangedMessageCommand = function(self)
        -- Reset the text (mainly for course mode)	
        self:settext("")
        author_table = {}

        local song, steps = GetSongAndSteps(player)

        author_table = getAuthorTable(steps)

        marquee_index = 0
        -- Loop the author field
        if #author_table > 0 then
            self:queuecommand("Marquee")
        else
            self:settext("")
        end
        if #author_table > 1 then
            self:queuecommand("Marquee")
        end
    end,
    MarqueeCommand = function(self)
        local fmt = "%s: %s"
        marquee_index = (marquee_index % #author_table) + 1
        local text = author_table[marquee_index]
        self:settext(fmt:format("Chart", text))
        DiffuseEmojis(self, text)
        if marquee_index == #author_table then
            marquee_index = 0
        end
        self:sleep(3):queuecommand("Marquee")
    end
}

af[#af + 1] = LoadFont("Common Normal") .. {
    Name = "StepsInfo_Group",
    InitCommand = function(self)
        self:xy(0, 20)
        self:zoom(0.75)
        self:maxwidth(250)
        self:halign(PlayerNumber:Reverse()[player]):vertalign(bottom)

        if IsUltraWide and #GAMESTATE:GetHumanPlayers() > 1 then
            self:halign(PlayerNumber:Reverse()[OtherPlayer[player]])
            self:x(50 * (player == PLAYER_1 and -1 or 1))
        end

        self:queuecommand("CurrentSongChangedMessage")
    end,
    CurrentSongChangedMessageCommand = function(self, params)
        self:settext(FormatGroup(GAMESTATE:GetCurrentSong()))
    end
}

return af
