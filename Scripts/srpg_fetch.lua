local RANKING_URL = "https://srpg9.groovestats.com/api/get-ranking.php?type=level&gender=all&superregion=all&country=all"
local SONGLIST_URL = "https://srpg9.groovestats.com/api/get-songlist.php"

local function FindPlayerID(playerName, rankingData, callback)
    for _, row in ipairs(rankingData) do
        local name = tostring(row[2]):match("^%s*(.-)%s*$")  -- trim whitespace
        if name:lower() == playerName:lower() then
            callback(row[2], row[9])  -- exact name, player ID (1-indexed in Lua)
            return
        end
    end
    Trace("[SRPG] Player '" .. playerName .. "' not found in ranking.")
end

function SRPG_FetchData(playerName)
    if not NETWORK:IsUrlAllowed(RANKING_URL) then
        Trace("[SRPG] URL not allowed. Check HttpAllowHosts in Preferences.ini")
        return
    end

    Trace("[SRPG] Fetching ranking to find player: " .. playerName)

    NETWORK:HttpRequest{
        url = RANKING_URL,
        method = "GET",
        connectTimeout = 5,
        transferTimeout = 15,
        onResponse = function(response)
            if response.error then
                Trace("[SRPG] Ranking request error: " .. (response.errorMessage or "unknown"))
                return
            end
            if response.statusCode ~= 200 then
                Trace("[SRPG] Ranking bad status: " .. tostring(response.statusCode))
                return
            end

            local ok, decoded = pcall(JsonDecode, response.body)
            if not ok or not decoded or not decoded.data then
                Trace("[SRPG] Failed to parse ranking JSON")
                return
            end

            FindPlayerID(playerName, decoded.data, function(exactName, playerID)
                Trace("[SRPG] Found: " .. exactName .. " ID=" .. tostring(playerID))

                local songlistURL = SONGLIST_URL ..
                    "?entrantid=" .. tostring(playerID) ..
                    "&notyou=1&_=1716766983375"

                NETWORK:HttpRequest{
                    url = songlistURL,
                    method = "GET",
                    connectTimeout = 5,
                    transferTimeout = 15,
                    onResponse = function(songResponse)
                        if songResponse.error then
                            Trace("[SRPG] Songlist error: " .. (songResponse.errorMessage or "unknown"))
                            return
                        end

                        local ok2, songData = pcall(JsonDecode, songResponse.body)
                        if not ok2 or not songData or not songData.data then
                            Trace("[SRPG] Failed to parse songlist JSON")
                            return
                        end

                        SRPG_ProcessSongs(exactName, songData.data)
                    end
                }
            end)
        end
    }
end

function SRPG_ProcessSongs(playerName, rows)
    local results = {}
    for _, row in ipairs(rows) do
        table.insert(results, {
            title       = row[5],
            bpm_base    = row[6],
            diff        = row[4],
            rate        = row[26] and (row[26] .. "x") or "1.00x",
            score       = row[27] and (row[27] .. "%") or "0.00%",
            status      = row[28],
            duration    = row[7],
            xp          = row[25],
        })
    end

    -- Store globally so any screen can access it
    SRPG_DATA = results
    SRPG_PLAYER = playerName

    Trace("[SRPG] Loaded " .. #results .. " songs for " .. playerName)

    -- Broadcast a message so any listening screen can react
    MESSAGEMAN:Broadcast("SRPGDataReady")
end