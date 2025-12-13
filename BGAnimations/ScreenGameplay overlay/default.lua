-- There's a lot of Lua in ./BGAnimations/ScreenGameplay overlay
--    and a LOT of Lua in ./BGAnimations/ScreenGameplay underlay
--
-- I'm using files in overlay for logic that *does* stuff without
-- directly drawing any new actors to the screen.
--
-- I've tried to title each file helpfully and partition the logic
-- found in each accordingly. Inline comments in each should provide
-- insight into the objective of each file.
--
-- Def.Actor will be used for each underlay file because I still
-- need some way to listen for events broadcast by the engine.
--
-- I'm using files in Gameplay's underlay for actors that get drawn
-- to the screen and visible to the player.  You can poke around in
-- those files to learn more.
------------------------------------------------------------

------------------------------------------------------------
-- Discord Rich Presence (local)
------------------------------------------------------------

local last_presence = nil
local in_gameplay = false
local sep = string.char(31)
local idleString = "Idle".. sep .. "Menu" .. sep .. sep .. sep .. sep .. sep .. sep .. sep


local function UpdateDiscordPresence()
-- SM("Discord update tick")

local song = GAMESTATE:GetCurrentSong()
local steps = GAMESTATE:GetCurrentSteps(PLAYER_1)

-- SM("Song: "..tostring(song))
-- SM("Steps: "..tostring(steps))

if not song or not steps then return end

	local pack_name = song and song:GetGroupName() or "Unknown Pack"
	local step_artist = steps and steps:GetAuthorCredit() or "Unknown"

	local title = song:GetDisplayMainTitle()
	local diff  = tostring(steps:GetDifficulty())
	local meter = steps:GetMeter()
	local artist = song:GetDisplayArtist()

	-- Banner (usually 200x80)
	local banner_path = song:GetBannerPath() -- returns string path or nil

	-- CD title (usually 64x64)
	local cd_path = song:GetCDTitlePath() -- returns string path or nil
	-- SM("banner: " .. cd_path)


	-- local presence = "Playing|" .. title .. "|" .. diff .. "|" .. meter .. "|" .. artist .. "|" .. banner_path .. "|" .. cd_path
	local presence = table.concat({ "Playing", title, diff, meter, artist, pack_name, step_artist, banner_path, cd_path }, sep)

	------------------------------------------------------------------------------

	-- SM(presence)
	if presence ~= last_presence then
		-- SM("Updating file")
		WriteDiscordPresence(presence)
		last_presence = presence
	end
end

local af = Def.ActorFrame{

	OnCommand=function(self)
		-- SM("Discord AF OnCommand") -- DEBUG
		in_gameplay = true         -- <<< mark gameplay started
		last_presence = nil
		self:SetUpdateFunction(UpdateDiscordPresence)
	end,

	OffCommand=function()
		if in_gameplay then
			WriteDiscordPresence(idleString)
			in_gameplay = false
		end
	end,

	CancelMessageCommand=function()
		if in_gameplay then
			WriteDiscordPresence(idleString)
			in_gameplay = false
		end
	end,

	GameplayEndedMessageCommand=function()
		if in_gameplay then
			WriteDiscordPresence(idleString)
			in_gameplay = false
		end
	end
}

------------------------------------------------------------
-- end of discord stuff
------------------------------------------------------------

af[#af+1] = LoadActor("./WhoIsCurrentlyWinning.lua")
af[#af+1] = LoadActor("./FailOnHoldStart.lua")

for player in ivalues( GAMESTATE:GetHumanPlayers() ) do

	local pn = ToEnumShortString(player)

	-- Use this opportunity to create an empty table for this player's
	-- gameplay stats for this stage. We'll store all kinds of data in
	-- this table that would normally only exist in ScreenGameplay so
	-- that it can persist into ScreenEvaluation to eventually be processed,
	-- visualized, and complained about. For example, per-column judgments,
	-- judgment offset data, highscore data, and so on.
	--
	-- Sadly, the full details of this Stages.Stats[stage_index] data structure
	-- is not documented anywhere. :(
	SL[pn].Stages.Stats[SL.Global.Stages.PlayedThisGame+1] = {}

	af[#af+1] = LoadActor("./TrackTimeSpentInGameplay.lua", player)
	af[#af+1] = LoadActor("./JudgmentOffsetTracking.lua", player)
	af[#af+1] = LoadActor("./TrackExScoreJudgments.lua", player)
	af[#af+1] = LoadActor("./TrackFailTime.lua", player)
	af[#af+1] = LoadActor("./NotefieldMods.lua", player)
	
	af[#af+1] = LoadActor("./PerColumnJudgmentGraphics.lua", player)
	af[#af+1] = LoadActor("./TrackGhostData.lua", player)
	

	-- FIXME: refactor PerColumnJudgmentTracking to not be inside this loop
	--        the Lua input callback logic shouldn't be duplicated for each player
	af[#af+1] = LoadActor("./PerColumnJudgmentTracking.lua", player)
end

return af
