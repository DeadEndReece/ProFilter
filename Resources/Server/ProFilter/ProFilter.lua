-- ============================================================
--  ProFilter V1 - The Ultimate In-Game Profanity Filter for BeamMP Servers
--  Features: Welcome Messages | Configurable Censor/Replace Modes | Advanced Leet-Speak Detection | Interactive Console Menu | Persistent Data Storage | Action Logging & More!
--  Made by DeadEndReece (UkDrifter) | GitHub: https://github.com/DeadEndReece 
-- ============================================================

local baseDir = "Resources/Server/ProFilter/"
local dataPath = baseDir .. "data.txt"
local logPath = baseDir .. "logs.txt"

-- ============================================================
-- ⚙️ MESSAGE CONFIGURATION
-- Change the messages sent to players here:
-- ============================================================
local CONFIG = {
    NoPermissionMsg = "^f(^cProFilter^f) You do not have permission to use PF commands.",
    MessageBlockedMsg = "^f(^cProFilter^f) Message ^cblocked ^fdue to profanity.",
    JoinMessage = "^f(^cProFilter^f) This server runs ProFilter, Please watch your language. (^bMade By DeadEndReece^f)"
}
-- ============================================================

local PF_DATA = {
    words = {},         -- Matches only if standing alone (e.g. 'ass')
    strictWords = {},   -- Matches ANYWHERE in the text (e.g. 'fuck' inside 'fuckyou')
    admins = {},
    censorMode = false,
    replaceMode = false,
    logMode = false,
    censorChar = "*", 
    replaceWord = "Meow"
}

local interceptedCount = 0
local setupStep = 0 
local menuStep = 0 
local initTimer = 0
local isInitialized = false
local welcomeQueue = {}

-- --- DATA PERSISTENCE & SETUP ---

function LoadPFData()
    PF_DATA.words = {}
    PF_DATA.strictWords = {}
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
                elseif currentSection == "STRICT" then table.insert(PF_DATA.strictWords, line)
                end
            end
        end
        file:close()
        print("[ProFilter] Data Sync Complete. Normal: " .. #PF_DATA.words .. " | Strict: " .. #PF_DATA.strictWords)
    else
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
        file:write("\n[STRICT]\n")
        for _, word in ipairs(PF_DATA.strictWords) do file:write(word .. "\n") end
        file:close()
    end
end

-- --- INTERACTIVE CONSOLE MENUS ---
local function PrintMenu()
    print("\n=========================================================")
    print("   [ProFilter] INTERACTIVE SETTINGS MENU")
    print("=========================================================")
    print(" Type a number to toggle/change a setting, or 'exit' to close.")
    print(" [1] Toggle Censor Mode    : " .. (PF_DATA.censorMode and "ON" or "OFF"))
    print(" [2] Toggle Replace Mode   : " .. (PF_DATA.replaceMode and "ON" or "OFF"))
    print(" [3] Toggle Action Logging : " .. (PF_DATA.logMode and "ON" or "OFF"))
    print(" [4] Set Censor Symbol     : '" .. PF_DATA.censorChar .. "'")
    print(" [5] Set Replacement Word  : '" .. PF_DATA.replaceWord .. "'")
    print(" [6] View / Add / Rem Admins")
    print(" [7] Factory Reset System")
    print(" [0] Exit Menu")
    print("=========================================================")
    menuStep = 1
end

local function PrintAdminMenu()
    print("\n=========================================================")
    print("   --- Current Admins ---")
    local count = 0
    for k,_ in pairs(PF_DATA.admins) do 
        print("   - " .. k)
        count = count + 1 
    end
    if count == 0 then print("   (None)") end
    print("---------------------------------------------------------")
    print(" [1] Add Admin")
    print(" [2] Remove Admin")
    print(" [0] Back to Main Menu")
    print("=========================================================")
    menuStep = 4
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
            MP.SendChatMessage(sender_id, "---------------- ^cProFilter^f Admin Menu ----------------")
            MP.SendChatMessage(sender_id, "^c /pf.status (pf.st)             ^f- View Config & Stats")
            MP.SendChatMessage(sender_id, "^c /pf.list (pf.l)                ^f- List all bad words")
            MP.SendChatMessage(sender_id, "--- ^bHEAVY SWEARS ^f(Blocks anywhere, e.g. fuckyou) ---")
            MP.SendChatMessage(sender_id, "^c /pf.addstrict (pf.as) ^f- Add Heavy Swear")
            MP.SendChatMessage(sender_id, "^c /pf.remstrict (pf.rs) ^f- Remove Heavy Swear")
            MP.SendChatMessage(sender_id, "^f--- ^bSHORT SWEARS ^f(Blocks whole-words only, e.g. ass) ---")
            MP.SendChatMessage(sender_id, "^c /pf.addword (pf.aw) ^f- Add Short Swear")
            MP.SendChatMessage(sender_id, "^c /pf.removeword (pf.rw) ^f- Remove Short Swear")
            MP.SendChatMessage(sender_id, "------------------------------------------------------")
        else
            print("-------------------- ProFilter Commands --------------------")
            print("pf.menu                          - OPEN INTERACTIVE SETTINGS MENU (EASY!)")
            print("pf.status (pf.st)                - View Config & Stats") 
            print("pf.list (pf.l)                   - List all bad words") 
            print("--- WORD MANAGEMENT (Batch edit using commas: pf.aw cat,dog) ---")
            print("pf.addstrict (pf.as) <w1,w2>     - Add HEAVY swear (blocks anywhere)") 
            print("pf.remstrict (pf.rs) <w1,w2>     - Rem HEAVY swear") 
            print("pf.addword (pf.aw) <w1,w2>       - Add SHORT swear (whole-word only)") 
            print("pf.removeword (pf.rw) <w1,w2>    - Rem SHORT swear") 
            print("pf.clearwords (pf.cw)            - Clear all wordlists")
            print("------------------------------------------------------------------")
        end
        return true

    elseif cmd == "pf.menu" and not sender_id then
        PrintMenu()
        return true

    elseif cmd == "pf.status" or cmd == "pf.st" then
        local adminCount = 0
        for k, v in pairs(PF_DATA.admins) do adminCount = adminCount + 1 end

        if sender_id then
            MP.SendChatMessage(sender_id, "^c[PF Stats]^f Intercepted: " .. interceptedCount .. " | Words: " .. (#PF_DATA.words + #PF_DATA.strictWords) .. " | Admins: " .. adminCount)
            MP.SendChatMessage(sender_id, "^c[PF Config]^f Censor: " .. (PF_DATA.censorMode and "ON" or "OFF") .. " | Replace: " .. (PF_DATA.replaceMode and "ON" or "OFF") .. " | Log: " .. (PF_DATA.logMode and "ON" or "OFF"))
        else
            print("--- PF LIVE STATUS ---")
            print(" > Intercepted  : " .. interceptedCount)
            print(" > Heavy Swears : " .. #PF_DATA.strictWords)
            print(" > Short Swears : " .. #PF_DATA.words)
            print(" > Admins Auth'd: " .. adminCount)
            print(" > Censor Mode  : " .. (PF_DATA.censorMode and "ON" or "OFF"))
            print(" > Replace Mode : " .. (PF_DATA.replaceMode and "ON" or "OFF"))
            print(" > Logging Mode : " .. (PF_DATA.logMode and "ON" or "OFF"))
            print("----------------------")
        end
        return true

    elseif cmd == "pf.addstrict" or cmd == "pf.as" then
        if #args > 1 then
            local added = {}; local rawWords = table.concat(args, "", 2) 
            for w in rawWords:gmatch("([^,]+)") do
                local cleanWord = w:lower(); local isDuplicate = false
                for _, ew in ipairs(PF_DATA.strictWords) do if ew == cleanWord then isDuplicate = true; break end end
                if not isDuplicate then table.insert(PF_DATA.strictWords, cleanWord); table.insert(added, cleanWord) end
            end
            if #added > 0 then SavePFData(); Reply(sender_id, "Added HEAVY Swear(s): " .. table.concat(added, ", "))
            else Reply(sender_id, "No new words were added (duplicates skipped).") end
        end
        return true

    elseif cmd == "pf.remstrict" or cmd == "pf.rs" then
        if #args > 1 then
            local removed = {}; local rawWords = table.concat(args, "", 2)
            for w in rawWords:gmatch("([^,]+)") do
                local cleanWord = w:lower()
                for i = #PF_DATA.strictWords, 1, -1 do
                    if PF_DATA.strictWords[i] == cleanWord then table.remove(PF_DATA.strictWords, i); table.insert(removed, cleanWord); break end
                end
            end
            SavePFData()
            if #removed > 0 then Reply(sender_id, "Removed HEAVY Swears: " .. table.concat(removed, ", "))
            else Reply(sender_id, "No matching words found.") end
        end
        return true

    elseif cmd == "pf.addword" or cmd == "pf.aw" then
        if #args > 1 then
            local added = {}; local rawWords = table.concat(args, "", 2) 
            for w in rawWords:gmatch("([^,]+)") do
                local cleanWord = w:lower(); local isDuplicate = false
                for _, ew in ipairs(PF_DATA.words) do if ew == cleanWord then isDuplicate = true; break end end
                if not isDuplicate then table.insert(PF_DATA.words, cleanWord); table.insert(added, cleanWord) end
            end
            if #added > 0 then SavePFData(); Reply(sender_id, "Added SHORT Swear(s): " .. table.concat(added, ", "))
            else Reply(sender_id, "No new words were added (duplicates skipped).") end
        end
        return true

    elseif cmd == "pf.removeword" or cmd == "pf.rw" then
        if #args > 1 then
            local removed = {}; local rawWords = table.concat(args, "", 2)
            for w in rawWords:gmatch("([^,]+)") do
                local cleanWord = w:lower()
                for i = #PF_DATA.words, 1, -1 do
                    if PF_DATA.words[i] == cleanWord then table.remove(PF_DATA.words, i); table.insert(removed, cleanWord); break end
                end
            end
            SavePFData()
            if #removed > 0 then Reply(sender_id, "Removed SHORT Swears: " .. table.concat(removed, ", "))
            else Reply(sender_id, "No matching words found.") end
        end
        return true

    elseif cmd == "pf.list" or cmd == "pf.l" then
        if sender_id then 
            MP.SendChatMessage(sender_id, "^c[PF Heavy Swears]^f " .. table.concat(PF_DATA.strictWords, ", "))
            MP.SendChatMessage(sender_id, "^c[PF Short Swears]^f " .. table.concat(PF_DATA.words, ", "))
        else 
            print("--- HEAVY SWEARS (" .. #PF_DATA.strictWords .. ") ---")
            for i, v in ipairs(PF_DATA.strictWords) do print(i .. ". " .. v) end 
            print("--- SHORT SWEARS (" .. #PF_DATA.words .. ") ---")
            for i, v in ipairs(PF_DATA.words) do print(i .. ". " .. v) end 
        end
        return true

    elseif cmd == "pf.clearwords" or cmd == "pf.cw" then
        if not sender_id then -- Ensure it's executed from the server console
            if args[2] and args[2]:lower() == "confirm" then
                PF_DATA.words = {}
                PF_DATA.strictWords = {}
                SavePFData()
                print("[ProFilter] All wordlists completely cleared.")
            else
                print("\n=========================================================")
                print("   [ProFilter] WARNING!")
                print("=========================================================")
                print(" > This will completely delete ALL of your Heavy and Short")
                print(" > swear words. This action CANNOT be undone.")
                print(" >")
                print(" > To confirm, type: " .. cmd .. " confirm")
                print("=========================================================\n")
            end
        else
            Reply(sender_id, "The clearwords command can only be used from the server console.")
        end
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

function ProFilter_WelcomeTimer()
    for pid, timeLeft in pairs(welcomeQueue) do
        welcomeQueue[pid] = timeLeft - 1
        if welcomeQueue[pid] <= 0 then
            if CONFIG.JoinMessage and CONFIG.JoinMessage ~= "" then
                MP.SendChatMessage(pid, CONFIG.JoinMessage)
            end
            welcomeQueue[pid] = nil 
        end
    end
end

function OnPFConsoleInput(cmd)
    local rawInput = cmd:match("^%s*(.-)%s*$")
    local ans = rawInput:lower()

    -- 1. SETUP WIZARD INTERCEPTOR
    if setupStep ~= 0 then
        local isYes = (ans == "y" or ans == "yes" or ans == "true")
        
        if setupStep == -1 then
            if isYes then
                print(" -> Reset Confirmed. Launching Setup Wizard...")
                print("")
                print("=========================================================")
                print("   [ProFilter] SETUP WIZARD")
                print("=========================================================")
                print(" > Step 1: Enable Censor Mode?")
                print(" > Type 'y' for Yes or 'n' for No:")
                setupStep = 1
            else
                print(" -> Reset Cancelled.")
                print("")
                setupStep = 0
            end
        elseif setupStep == 1 then
            PF_DATA.censorMode = isYes
            print("")
            print("=========================================================")
            print(" -> Censor Mode: " .. (isYes and "ON" or "OFF"))
            print("---------------------------------------------------------")
            print(" > Step 2: Set your Censor Symbol (e.g. *, #, ?)")
            setupStep = 2
        elseif setupStep == 2 then
            local char = string.sub(rawInput, 1, 1); if char == "" then char = "*" end
            PF_DATA.censorChar = char
            print("")
            print("=========================================================")
            print(" -> Censor Symbol: '" .. char .. "'")
            print("---------------------------------------------------------")
            print(" > Step 3: Enable Replace Mode?")
            print(" > Type 'y' for Yes or 'n' for No:")
            setupStep = 3
        elseif setupStep == 3 then
            PF_DATA.replaceMode = isYes
            print("")
            print("=========================================================")
            print(" -> Replace Mode: " .. (isYes and "ON" or "OFF"))
            print("---------------------------------------------------------")
            print(" > Step 4: Set your Replacement Word (e.g. [REDACTED], Meow)")
            setupStep = 4
        elseif setupStep == 4 then
            if rawInput == "" then rawInput = "Meow" end
            PF_DATA.replaceWord = rawInput
            print("")
            print("=========================================================")
            print(" -> Replacement Word: '" .. rawInput .. "'")
            print("---------------------------------------------------------")
            print(" > Step 5: Enable Action Logging?")
            print(" > Type 'y' for Yes or 'n' for No:")
            setupStep = 5
        elseif setupStep == 5 then
            PF_DATA.logMode = isYes
            print("")
            print("=========================================================")
            print(" -> Logging Mode: " .. (isYes and "ON" or "OFF"))
            print("---------------------------------------------------------")
            print(" > Step 6: Load the default offensive wordlist?")
            print(" > Type 'y' for Yes or 'n' for No:")
            setupStep = 6
        elseif setupStep == 6 then
            print("")
            print("=========================================================")
            if isYes then
                PF_DATA.strictWords = { "fuck", "bitch", "cunt", "pussy", "fvck", "fukk", "fuk", "biatch", "btch", "cvnt", "pssy", "slvt", "nibba", "niqqa", "negga", "nugga" }
                PF_DATA.words = { "shit", "ass", "dick", "fag", "nig", "rape", "cum", "cock", "kys", "nigger", "nigga", "fagg", "fagot", "fack", "shet", "bish", "phag", "pusi", "ritard", "azz", "arse", "hoe", "cumm", "cawck", "dik", "dicc", "dikk", "segs", "secks", "pron", "chink", "spic", "gook", "kike", "tranny", "dyke", "twat", "pedo", "nazi", "cnut", "bastard", "slut", "whore", "wanker" }
                print(" -> Default wordlists loaded.")
            else
                PF_DATA.words = {}; PF_DATA.strictWords = {}
                print(" -> Starting with an empty wordlist.")
            end
            print("---------------------------------------------------------")
            print(" > Step 7: Add an In-Game Admin?")
            print(" > Type the exact username, or 'n' to skip:")
            setupStep = 7
        elseif setupStep == 7 then
            print("")
            print("=========================================================")
            if ans ~= "n" and ans ~= "no" and ans ~= "skip" and rawInput ~= "" then
                PF_DATA.admins[rawInput] = true
                print(" -> Admin added: '" .. rawInput .. "'")
            else
                print(" -> Skipped adding Admin.")
            end
            SavePFData()
            setupStep = 0
            print("---------------------------------------------------------")
            print("   [ProFilter] SETUP COMPLETE!")
            print("   Type 'pf.help' in game or console for commands.")
            print("=========================================================")
            print("")
        end
        return "" 
    end

    -- 2. INTERACTIVE MENU INTERCEPTOR
    if menuStep ~= 0 then
        if ans == "exit" or ans == "0" and menuStep == 1 then
            print(" -> Exited Menu. Settings Saved."); menuStep = 0; SavePFData(); return ""
        end

        -- Main Menu Handling
        if menuStep == 1 then
            if ans == "1" then PF_DATA.censorMode = not PF_DATA.censorMode; PrintMenu()
            elseif ans == "2" then PF_DATA.replaceMode = not PF_DATA.replaceMode; PrintMenu()
            elseif ans == "3" then PF_DATA.logMode = not PF_DATA.logMode; PrintMenu()
            elseif ans == "4" then print(""); print(" > Type the NEW symbol (e.g. *, #, ?):"); menuStep = 2
            elseif ans == "5" then print(""); print(" > Type the NEW replacement word:"); menuStep = 3
            elseif ans == "6" then PrintAdminMenu()
            elseif ans == "7" then
                print("")
                print("=========================================================")
                print(" > WARNING: This will completely wipe your current settings,")
                print(" > wordlist, and trigger the setup wizard.")
                print(" > Are You Sure? (Type 'y' for Yes or 'n' for No):")
                setupStep = -1; menuStep = 0
            else print("Invalid choice. Type a number 0-7.") end
            return ""

        -- Set Censor Char
        elseif menuStep == 2 then
            if rawInput ~= "" then PF_DATA.censorChar = string.sub(rawInput, 1, 1) end
            PrintMenu(); return ""

        -- Set Replacement Word
        elseif menuStep == 3 then
            if rawInput ~= "" then PF_DATA.replaceWord = rawInput end
            PrintMenu(); return ""

        -- Admin Sub-Menu
        elseif menuStep == 4 then
            if ans == "1" then 
                print("")
                print(" > Type the exact name of the player to ADD as Admin (or type 'cancel' to go back):")
                menuStep = 5
            elseif ans == "2" then 
                print("")
                print(" > Type the exact name of the Admin to REMOVE (or type 'cancel' to go back):")
                menuStep = 6
            elseif ans == "0" or ans == "back" then 
                PrintMenu()
            else 
                print("Invalid choice. Type 1, 2, or 0.") 
            end
            return ""

        -- Add Admin Logic
        elseif menuStep == 5 then
            if ans == "cancel" or rawInput == "" then
                PrintAdminMenu()
            else
                PF_DATA.admins[rawInput] = true
                print(" -> Admin added: '" .. rawInput .. "'")
                SavePFData()
                PrintAdminMenu()
            end
            return ""

        -- Remove Admin Logic
        elseif menuStep == 6 then
            if ans == "cancel" or rawInput == "" then
                PrintAdminMenu()
            else
                if PF_DATA.admins[rawInput] then
                    PF_DATA.admins[rawInput] = nil
                    print(" -> Admin removed: '" .. rawInput .. "'")
                    SavePFData()
                else
                    print(" -> Error: Could not find an admin named '" .. rawInput .. "'")
                end
                PrintAdminMenu()
            end
            return ""
        end
    end

    -- Normal command processing
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

    local displayMsg = message
    local lowerMsg = string.lower(message)
    local normalized = ""
    
    for i = 1, #message do
        local char = string.sub(lowerMsg, i, i)
        if char == "@" or char == "4" then char = "a"
        elseif char == "0" then char = "o"
        elseif char == "1" or char == "!" then char = "i"
        elseif char == "3" then char = "e"
        elseif char == "5" or char == "$" then char = "s"
        elseif char == "7" then char = "t" 
        end
        normalized = normalized .. char
    end

    local foundBad = false
    local rawMatches = {}
    
    -- 1. PROCESS STRICT WORDS
    for _, word in ipairs(PF_DATA.strictWords) do
        local patternChars = {}
        for i = 1, #word do
            local c = string.sub(word, i, i)
            if c:match("[%^%$%(%)%%%.%[%]%*%+%-%?]") then c = "%" .. c end
            table.insert(patternChars, c)
        end
        local innerPattern = table.concat(patternChars, "[%W_]*")
        
        local startP, endP = string.find(normalized, innerPattern)
        while startP do 
            table.insert(rawMatches, {s = startP, e = endP})
            startP, endP = string.find(normalized, innerPattern, endP + 1) 
        end
    end

    -- 2. PROCESS NORMAL BOUNDARY WORDS
    for _, word in ipairs(PF_DATA.words) do
        local patternChars = {}
        for i = 1, #word do
            local c = string.sub(word, i, i)
            if c:match("[%^%$%(%)%%%.%[%]%*%+%-%?]") then c = "%" .. c end
            table.insert(patternChars, c)
        end
        local innerPattern = table.concat(patternChars, "[%W_]*")
        local pattern = "%f[%a]" .. innerPattern .. "%f[%A]"
        
        local startP, endP = string.find(normalized, pattern)
        while startP do 
            table.insert(rawMatches, {s = startP, e = endP})
            startP, endP = string.find(normalized, pattern, endP + 1) 
        end
    end

    -- Sort matches so we replace them from the back of the string to the front
    table.sort(rawMatches, function(a, b) 
        if a.s == b.s then return a.e > b.e end 
        return a.s > b.s 
    end)

    -- Clean up overlaps
    local matches = {}
    local lastS = math.huge
    for _, m in ipairs(rawMatches) do
        if m.e < lastS then
            table.insert(matches, m)
            lastS = m.s
        end
    end

    -- Apply the censorship
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
    welcomeQueue[player_id] = 15
end

function OnPFPlayerDisconnect(player_id)
    welcomeQueue[player_id] = nil
end

MP.RegisterEvent("ProFilter_InitTimer", "ProFilter_InitTimer")
MP.CreateEventTimer("ProFilter_InitTimer", 1000)

MP.RegisterEvent("ProFilter_WelcomeTimer", "ProFilter_WelcomeTimer")
MP.CreateEventTimer("ProFilter_WelcomeTimer", 1000)

MP.RegisterEvent("onConsoleInput", "OnPFConsoleInput")
MP.RegisterEvent("onChatMessage", "OnPFChatMessage")
MP.RegisterEvent("onPlayerJoin", "OnPFPlayerJoin")
MP.RegisterEvent("onPlayerDisconnect", "OnPFPlayerDisconnect")