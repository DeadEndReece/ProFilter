-- ============================================================
--  ProFilter V1 - Made by DeadEndReece (UkDrifter)
--  A powerful and customizable profanity filter for your server.
--  Features: Welcome Warning, Config Messages, Setup Wizard
-- ============================================================

local baseDir = "Resources/Server/ProFilter/"
local dataPath = baseDir .. "data.txt"
local logPath = baseDir .. "logs.txt"

-- ============================================================
-- ⚙️ QUICK CONFIGURATION
-- Change the messages sent to players here:
-- ============================================================
local CONFIG = {
    -- Sent when a player tries to use a ProFilter admin command without permission
    NoPermissionMsg = "^f(^cProFilter^f) You do not have permission to use PF commands.",
    
    -- Sent to the player when their message is completely blocked (if Censor Mode is OFF)
    MessageBlockedMsg = "^f(^cProFilter^f) Message ^cblocked ^fdue to profanity.",

    -- Sent privately to every player the moment they join the server
    JoinMessage = "^f(^cProFilter^f) This server runs ProFilter, Please watch your language. (^bMade By DeadEndReece^f)"
}
-- ============================================================

local PF_DATA = {
    words = {},
    admins = {},
    censorMode = false,
    replaceMode = false,
    logMode = false,
    censorChar = "*", 
    replaceWord = "Meow"
}

local interceptedCount = 0
local setupStep = 0 
local initTimer = 0
local isInitialized = false

-- --- DATA PERSISTENCE & SETUP ---

function LoadPFData()
    PF_DATA.words = {}
    PF_DATA.admins = {}
    local file = io.open(dataPath, "r")
    
    if file then
        local currentSection = ""
        for line in file:lines() do
            if line:match("%[.+%]") then currentSection = line:match("%[(.+)%]")
            elseif line:match("=") then
                local key, val = line:match("([^=]+)=(.+)")
                if key == "censor" then PF_DATA.censorMode = (val == "on")
                elseif key == "replace" then PF_DATA.replaceMode = (val == "on")
                elseif key == "log" then PF_DATA.logMode = (val == "on")
                elseif key == "char" then PF_DATA.censorChar = val
                elseif key == "rword" then PF_DATA.replaceWord = val
                end
            elseif line ~= "" then
                if currentSection == "ADMINS" then PF_DATA.admins[line] = true
                elseif currentSection == "WORDS" then table.insert(PF_DATA.words, line)
                end
            end
        end
        file:close()
        print("[ProFilter] Data Sync Complete. Words: " .. #PF_DATA.words)
    else
        -- FIRST LAUNCH WIZARD
        print("\n=========================================================")
        print("   [ProFilter] FIRST LAUNCH SETUP WIZARD")
        print("=========================================================")
        print(" > Step 1: Enable Censor Mode?")
        print("   (Replaces profanity with a symbol instead of blocking the whole message)")
        print(" > Type 'y' for Yes or 'n' for No:")
        setupStep = 1
    end
end

function SavePFData()
    local file = io.open(dataPath, "w")
    if file then
        file:write("[SETTINGS]\ncensor=" .. (PF_DATA.censorMode and "on" or "off") .. "\nreplace=" .. (PF_DATA.replaceMode and "on" or "off") .. "\nlog=" .. (PF_DATA.logMode and "on" or "off") .. "\nchar=" .. PF_DATA.censorChar .. "\nrword=" .. PF_DATA.replaceWord .. "\n\n")
        file:write("[ADMINS]\n")
        for admin, _ in pairs(PF_DATA.admins) do file:write(admin .. "\n") end
        file:write("\n[WORDS]\n")
        for _, word in ipairs(PF_DATA.words) do file:write(word .. "\n") end
        file:close()
    end
end

-- --- COMMAND PROCESSING ---

local function Reply(id, msg)
    print("[ProFilter] " .. msg)
    if id then MP.SendChatMessage(id, "^c[PF]^f " .. msg) end
end

local function ProcessPFCommand(args, sender_id)
    local cmd = args[1]:lower()

    if cmd == "pf.help" or cmd == "pf.h" then
        if sender_id then
            MP.SendChatMessage(sender_id, "---------------- ProFilter (In-Game) ----------------")
            MP.SendChatMessage(sender_id, "pf.status (pf.st)             - View Live Stats & Config")
            MP.SendChatMessage(sender_id, "pf.addword (pf.aw) <word>     - Add words (comma separated)")
            MP.SendChatMessage(sender_id, "pf.removeword (pf.rw) <word>  - Rem words (comma separated)")
            MP.SendChatMessage(sender_id, "pf.listwords (pf.wl)          - List all forbidden words")
            MP.SendChatMessage(sender_id, "pf.clearwords (pf.cw)         - Clear the entire wordlist")
            MP.SendChatMessage(sender_id, "-----------------------------------------------------------")
        else
            print("-------------------- ProFilter Commands --------------------")
            print("pf.status (pf.st)                - View Live Stats & Config")
            print("pf.addword (pf.aw) <w1,w2>       - Add words (comma separated)")
            print("pf.removeword (pf.rw) <w1,w2>    - Rem words (comma separated)")
            print("pf.listwords (pf.wl)             - List all forbidden words")
            print("pf.clearwords (pf.cw)            - Clear the entire wordlist (Console Only)")
            print("pf.censor (pf.ce) <on/off>       - Toggle Censor Mode (Console Only)")
            print("pf.replace (pf.re) <on/off>      - Toggle Replace Mode (Console Only)")
            print("pf.logging (pf.lo) <on/off>      - Toggle Action Logging (Console Only)")
            print("pf.setchar (pf.sc) <char>        - Set Censor Char (Console Only)")
            print("pf.setword (pf.sw) <word>        - Set Replace Word (Console Only)")
            print("pf.adduser (pf.au) <name>        - Add auth player (Console Only)")
            print("pf.removeuser (pf.ru) <name>     - Remove auth player (Console Only)")
            print("pf.users (pf.lu)                 - List auth players (Console Only)")
            print("pf.reset                         - Run Setup Wizard again (Console Only)")
            print("------------------------------------------------------------------")
        end
        return true

    elseif cmd == "pf.status" or cmd == "pf.st" then
        local adminCount = 0
        for k, v in pairs(PF_DATA.admins) do adminCount = adminCount + 1 end

        if sender_id then
            MP.SendChatMessage(sender_id, "^c[PF Stats]^f Intercepted: " .. interceptedCount .. " | Words: " .. #PF_DATA.words .. " | Admins: " .. adminCount)
            MP.SendChatMessage(sender_id, "^c[PF Config]^f Censor: " .. (PF_DATA.censorMode and "ON" or "OFF") .. " | Replace: " .. (PF_DATA.replaceMode and "ON" or "OFF") .. " | Log: " .. (PF_DATA.logMode and "ON" or "OFF"))
        else
            print("--- PF LIVE STATUS ---")
            print(" > Intercepted  : " .. interceptedCount)
            print(" > Word(s) Loaded : " .. #PF_DATA.words)
            print(" > Admins Auth'd: " .. adminCount)
            print(" > Censor Mode  : " .. (PF_DATA.censorMode and "ON" or "OFF"))
            print(" > Replace Mode : " .. (PF_DATA.replaceMode and "ON" or "OFF"))
            print(" > Logging Mode : " .. (PF_DATA.logMode and "ON" or "OFF"))
            print("----------------------")
        end
        return true

    -- BATCH ADD WORDS WITH DUPLICATE CHECK
    elseif cmd == "pf.addword" or cmd == "pf.aw" then
        if #args > 1 then
            local added = {}
            local rawWords = table.concat(args, "", 2) 
            for w in rawWords:gmatch("([^,]+)") do
                local cleanWord = w:lower()
                
                local isDuplicate = false
                for _, existingWord in ipairs(PF_DATA.words) do
                    if existingWord == cleanWord then
                        isDuplicate = true
                        break
                    end
                end
                
                if not isDuplicate then
                    table.insert(PF_DATA.words, cleanWord)
                    table.insert(added, cleanWord)
                end
            end
            
            if #added > 0 then
                SavePFData()
                Reply(sender_id, "Added word(s): " .. table.concat(added, ", "))
            else
                Reply(sender_id, "No new words were added (duplicates skipped).")
            end
        end
        return true

    -- BATCH REMOVE WORDS
    elseif cmd == "pf.removeword" or cmd == "pf.rw" then
        if #args > 1 then
            local removed = {}
            local rawWords = table.concat(args, "", 2)
            for w in rawWords:gmatch("([^,]+)") do
                local cleanWord = w:lower()
                for i = #PF_DATA.words, 1, -1 do
                    if PF_DATA.words[i] == cleanWord then
                        table.remove(PF_DATA.words, i)
                        table.insert(removed, cleanWord)
                        break
                    end
                end
            end
            SavePFData()
            if #removed > 0 then Reply(sender_id, "Removed words: " .. table.concat(removed, ", "))
            else Reply(sender_id, "No matching words found to remove.") end
        end
        return true

    elseif cmd == "pf.listwords" or cmd == "pf.wl" then
        if sender_id then MP.SendChatMessage(sender_id, "^c[PF Words]^f " .. table.concat(PF_DATA.words, ", "))
        else print("--- Blocked Words (" .. #PF_DATA.words .. ") ---"); for i, v in ipairs(PF_DATA.words) do print(i .. ". " .. v) end end
        return true


    -- CONSOLE ONLY COMMANDS
    elseif (cmd == "pf.clearwords" or cmd == "pf.cw") and not sender_id then
        PF_DATA.words = {}; SavePFData(); print("[ProFilter] Wordlist completely cleared."); return true

    elseif (cmd == "pf.censor" or cmd == "pf.ce") and not sender_id then
        PF_DATA.censorMode = (args[2] == "on"); SavePFData(); print("PF: Censor mode " .. (PF_DATA.censorMode and "ON" or "OFF")); return true

    elseif (cmd == "pf.replace" or cmd == "pf.re") and not sender_id then
        PF_DATA.replaceMode = (args[2] == "on"); SavePFData(); print("PF: Replace mode " .. (PF_DATA.replaceMode and "ON" or "OFF")); return true
        
    elseif (cmd == "pf.logging" or cmd == "pf.lo") and not sender_id then
        PF_DATA.logMode = (args[2] == "on"); SavePFData(); print("PF: Logging mode " .. (PF_DATA.logMode and "ON" or "OFF")); return true

    elseif (cmd == "pf.setchar" or cmd == "pf.sc") and not sender_id then
        if args[2] then PF_DATA.censorChar = string.sub(args[2], 1, 1); SavePFData(); print("PF: Censor char set to '" .. PF_DATA.censorChar .. "'") end
        return true

    elseif (cmd == "pf.setword" or cmd == "pf.sw") and not sender_id then
        if args[2] then PF_DATA.replaceWord = args[2]; SavePFData(); print("PF: Replace word set to '" .. PF_DATA.replaceWord .. "'") end
        return true

    elseif (cmd == "pf.adduser" or cmd == "pf.au") and not sender_id then
        if args[2] then PF_DATA.admins[args[2]] = true; SavePFData(); print("PF: Admin Added: " .. args[2]) end
        return true

    elseif (cmd == "pf.removeuser" or cmd == "pf.ru") and not sender_id then
        if args[2] then PF_DATA.admins[args[2]] = nil; SavePFData(); print("PF: Admin Removed: " .. args[2]) end
        return true

    elseif (cmd == "pf.users" or cmd == "pf.lu") and not sender_id then
        print("--- ProFilter Admins ---")
        for name, _ in pairs(PF_DATA.admins) do print("- " .. name) end
        return true

    -- FACTORY RESET COMMAND
    elseif cmd == "pf.reset" and not sender_id then
        print("\n=========================================================")
        print("   [ProFilter] FACTORY RESET INITIATED")
        print("=========================================================")
        print(" > WARNING: This will completely wipe your current settings,")
        print(" > wordlist, and trigger the setup wizard.")
        print(" > Admins and Logs will NOT be deleted.")
        print(" > Are You Sure? (Type 'y' for Yes or 'n' for No):")
        setupStep = -1 
        return true
    end
end

-- --- EVENT HANDLERS ---

function ProFilter_InitTimer()
    if not isInitialized then
        initTimer = initTimer + 1
        if initTimer >= 7 then
            isInitialized = true
            LoadPFData()
        end
    end
end

function OnPFConsoleInput(cmd)
    -- SETUP WIZARD & CONFIRMATION INTERCEPTOR
    if setupStep ~= 0 then
        local rawInput = cmd:match("^%s*(.-)%s*$")
        local ans = rawInput:lower()
        local isYes = (ans == "y" or ans == "yes" or ans == "true")
        
        if setupStep == -1 then
            if isYes then
                print(" -> Reset Confirmed. Launching Setup Wizard...\n")
                print("=========================================================")
                print("   [ProFilter] SETUP WIZARD")
                print("=========================================================")
                print(" > Step 1: Enable Censor Mode?")
                print("   (Replaces profanity with a symbol instead of blocking the whole message)")
                print(" > Type 'y' for Yes or 'n' for No:")
                setupStep = 1
            else
                print(" -> Reset Cancelled. Returning to normal operation.\n")
                setupStep = 0
            end

        elseif setupStep == 1 then
            PF_DATA.censorMode = isYes
            print(" -> Censor Mode set to: " .. (isYes and "ON" or "OFF"))
            print("\n > Step 2: Set your Censor Symbol")
            print("   (What character should replace bad words? e.g. *, #, ?)")
            print(" > Type a single character:")
            setupStep = 2

        elseif setupStep == 2 then
            local char = string.sub(rawInput, 1, 1)
            if char == "" then char = "*" end
            PF_DATA.censorChar = char
            print(" -> Censor Symbol set to: '" .. char .. "'")
            print("\n > Step 3: Enable Action Logging?")
            print("   (Saves blocked messages, IDs, and timestamps to logs.txt)")
            print(" > Type 'y' for Yes or 'n' for No:")
            setupStep = 3

        elseif setupStep == 3 then
            PF_DATA.logMode = isYes
            print(" -> Logging Mode set to: " .. (isYes and "ON" or "OFF"))
            print("\n > Step 4: Set your Replacement Word")
            print("   (Used if you enable Replace Mode later. e.g. [REDACTED], Meow)")
            print(" > Type a word:")
            setupStep = 4

        elseif setupStep == 4 then
            if rawInput == "" then rawInput = "Meow" end
            PF_DATA.replaceWord = rawInput
            print(" -> Replacement Word set to: '" .. rawInput .. "'")
            print("\n > Step 5: Load the default offensive wordlist?")
            print("   (Automatically adds ~30 common swear words to get you started)")
            print(" > Type 'y' for Yes or 'n' for No:")
            setupStep = 5

        elseif setupStep == 5 then
            if isYes then
                PF_DATA.words = {
                    "fuck", "shit", "bitch", "ass", "dick", "cunt", "pussy", 
                    "whore", "slut", "faggot", "fag", "nigger", "nigga", "nig",
                    "bastard", "twat", "wanker", "prick", "retard", "rape",
                    "cock", "cum", "pedo", "pedophile", "nazi", "kys",
                    "tranny", "dyke", "chink", "spic", "gook", "kike"
                }
                print(" -> Expanded default wordlist loaded.")
            else
                PF_DATA.words = {}
                print(" -> Starting with an empty wordlist.")
            end
            SavePFData()
            setupStep = 0
            print("\n=========================================================")
            print("   [ProFilter] Setup Complete! Type 'pf.help'")
            print("=========================================================\n")
        end
        return "" 
    end

    -- Normal Console Processing
    local args = {}
    for word in cmd:gmatch("%S+") do table.insert(args, word) end
    if #args > 0 then ProcessPFCommand(args, nil) return "" end
end

function OnPFChatMessage(sender_id, sender_name, message)
    if message:sub(1, 1) == "/" then
        local cmdStr = message:sub(2)
        local args = {}
        for word in cmdStr:gmatch("%S+") do table.insert(args, word) end
        
        if #args > 0 and args[1]:lower():match("^pf%.") then
            if PF_DATA.admins[sender_name] then
                ProcessPFCommand(args, sender_id)
            else
                MP.SendChatMessage(sender_id, CONFIG.NoPermissionMsg)
            end
            return 1
        end
    end

    local displayMsg, lowerMsg, normalized, indexMap = message, string.lower(message), "", {}
    for i = 1, #message do
        local char = string.sub(lowerMsg, i, i)
        if char == "@" or char == "4" then char = "a"
        elseif char == "0" then char = "o"
        elseif char == "1" or char == "!" then char = "i"
        elseif char == "3" then char = "e"
        elseif char == "5" or char == "$" or char == "%" then char = "s"
        elseif char == "7" then char = "t" end
        if char ~= "." and char ~= "_" and char ~= "-" then normalized = normalized .. char; table.insert(indexMap, i) end
    end

    local foundBad, matches = false, {}
    for _, word in ipairs(PF_DATA.words) do
        local startP, endP = string.find(normalized, word, 1, true)
        while startP do table.insert(matches, {s = indexMap[startP], e = indexMap[endP]}); startP, endP = string.find(normalized, word, endP + 1, true) end
    end

    table.sort(matches, function(a, b) return a.s > b.s end)
    for _, m in ipairs(matches) do
        foundBad = true
        local rep = PF_DATA.replaceMode and PF_DATA.replaceWord or string.rep(PF_DATA.censorChar, m.e - m.s + 1)
        displayMsg = string.sub(displayMsg, 1, m.s - 1) .. rep .. string.sub(displayMsg, m.e + 1)
    end

    if foundBad then
        interceptedCount = interceptedCount + 1

        if PF_DATA.logMode then
            local logFile = io.open(logPath, "a")
            if logFile then
                local timeStamp = os.date("%Y-%m-%d %H:%M:%S")
                logFile:write(string.format("[%s] ID:%s | %s | Original Message: %s\n", timeStamp, tostring(sender_id), sender_name, message))
                logFile:close()
            end
        end

        if PF_DATA.censorMode then MP.SendChatMessage(-1, sender_name .. ": " .. displayMsg); return 1
        else MP.SendChatMessage(sender_id, CONFIG.MessageBlockedMsg); return 1 end
    end
    return 0
end

function OnPFPlayerJoin(player_id)
    if CONFIG.JoinMessage and CONFIG.JoinMessage ~= "" then
        MP.SendChatMessage(player_id, CONFIG.JoinMessage)
    end
end

-- Delayed Initialization
MP.RegisterEvent("ProFilter_InitTimer", "ProFilter_InitTimer")
MP.CreateEventTimer("ProFilter_InitTimer", 1000)

MP.RegisterEvent("onConsoleInput", "OnPFConsoleInput")
MP.RegisterEvent("onChatMessage", "OnPFChatMessage")
MP.RegisterEvent("onPlayerJoin", "OnPFPlayerJoin")