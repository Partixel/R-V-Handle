local Module, Players, Teams, MarketplaceService = {}, game:GetService("Players"), game:GetService("Teams"), game:GetService("MarketplaceService")

-- ! = invert
-- & = and
-- ? = valid object for the argument
-- all, * = wild chars, match anything

-- PLR TARGETTING
-- me
-- others
-- all
-- random
-- name
-- userid
-- partial name
-- +Friend
-- %Team
-- $UserPower
-- >OwnerType
-- ^GroupId[><=]Rank
-- ^GroupId@ -- Allies
-- ^GroupId# -- Enemies
-- @AccountAge[><=]
-- *Near[><=]Distance

-- %TEAM TARGETTING
-- me
-- biggest
-- smallest
-- random
-- name
-- partial name

-- TIME TARGETTING
-- m = minute
-- h = hour
-- d = day
-- w = week
-- mo = month
-- y = year
-- hh:mm
-- hh:mm:ss

-- KEY TARGETTING
-- key name

-- BOOL TARGETTING
-- true = true, 1, y, yes, t, on
-- false = false, 0, n, no, f, off


-- ARGUMENTS - Default, Blacklist

--String - Min, Max, Upper, Lower
--Number - Min, Max
--Key
--Bool
--Time - Min, Max
--ArgType
--Tool - Locations
--Player - NotSelf, NotHigher, NotLower, NotEqual
--Team - NotSelf
--Sound
--Place - NotSelf, SameOwner
--UserId - NotSelf, NotHigher, NotLower, NotEqual

Module.ValidChar = "?"

local WildCardChars = {"all", "*"}

local ValidToolLocations = {game:GetService("Lighting"), game:GetService("ServerStorage"), game:GetService("ReplicatedStorage"), game:GetService("StarterPack"), game:GetService("Teams")}

local BoolEquivs = {{"true", "1", "y", "yes", "t", "on"}, {"false", "0", "n", "no", "f", "off"}}

local TimeEquivs = {["s"] = 1, ["m"] = 60, ["mi"] = 60, ["h"] = 60 * 60, ["d"] = 60 * 60 * 24, ["w"] = 60 * 60 * 24 * 7, ["mo"] = 60 * 60 * 24 * 30, ["y"] = 60 * 60 * 24 * 365.25}

local Calc = require(2621701837)

Module.Events = {}

Module.ArgTypes = {}

Module.Defaults = {}

Module.ArgTypeNames = {}

-- Util functions --

function Module.AddArgAsset(Type, TypeId, ValidID)
	
	Module.ArgTypes[Type .. "Id"] = function (self, Strings, Plr)
		
		local String = table.remove(Strings, 1)
		
		local Num = tonumber(String)
		
		if String == Module.ValidChar then
			
			Num = ValidID
			
		end
		
		if Num then
			
			Num = Num
			
			local Ran, Matched = pcall(function() return MarketplaceService:GetProductInfo(Num).AssetTypeId == TypeId end)
			
			if Ran and Matched == true then return Num end
			
		end
		
		return nil, false
		
	end
	
	Module.ArgTypeNames[Type] = Type .. "Id"
	
	Module.ArgTypes[Type] = function (self, Strings, Plr)
		
		local String = table.remove(Strings, 1)
		
		local Num = tonumber(String)
		
		if String == Module.ValidChar then
			
			Num = ValidID
			
		end
		
		if Num then
			
			Num = Num
			
			local Ran, Info = pcall(function() return MarketplaceService:GetProductInfo(Num) end)
			
			if Ran and Info.AssetTypeId == TypeId then return Info end
			
		end
		
		return nil, false
		
	end
	
end

function Module.AddArgMultiple(Type)
	
	Module.ArgTypeNames[Type .. "s"] = Type .. "..."
	
	Module.ArgTypes[Type] = function (self, Strings, Plr)
		
		local String = table.remove(Strings, 1)
		
		local Objs = Module["Find" .. Type .. "s"](self, String, Plr)
		
		if Objs and #Objs == 1 then
			
			return Objs[1]
			
		end
		
		return nil, false
		
	end
	
	Module.ArgTypes[Type .. "s"] = function (self, Strings, Plr)
		
		local String = table.remove(Strings, 1)
		
		while String:sub(-1) == "," and Strings[1] do
			
			String = String .. table.remove(Strings, 1)
			
		end
		
		local Objs = Module["Find" .. Type .. "s"](self, String, Plr)
		
		if Objs and #Objs ~= 0 then
			
			return Objs
			
		end
		
		return nil, false
		
	end
	
end

function Module.GetArgType(ArgType)
	
	for a, b in pairs(Module.ArgTypes) do
		
		if b == ArgType then return a end
		
	end
	
end

local function TableHasValue(Table, Obj)
	
	for a = 1, #Table do
		
		if Table[a] == Obj then return a end
		
	end
	
end

local function GetValidTools()
	
	local Tools = {}
	
	for a = 1, #ValidToolLocations do
		
		local Children = ValidToolLocations[a]:GetDescendants()
		
		for b = 1, #Children do
			
			if Children[b]:IsA("Tool") then
				
				Tools[#Tools + 1] = Children[b]
				
			end
			
		end
			
	end
	
	return Tools
	
end

local function TableHasMatchingObj(Table, String, ExactOnly)
	local Regex = String:match("r(%b())")
	if not ExactOnly and Regex then
		Regex = Regex:sub(2, -2)
		
		local Found = {}
		for a = 1, #Table do
			if (type(Table[a]) == "string" and Table[a] or Table[a].Name):lower():match(Regex) then
				Found[#Found + 1] = Table[a]
			end
		end
		
		if #Found > 0 then return true, Found end
	else
		local Found, Exact = {}, nil
		for a = 1, #Table do
			local Name = (type(Table[a]) == "string" and Table[a] or Table[a].Name):lower()
			if Name == String then
				if not Exact then Found = {} end
				Found[#Found + 1] = Table[a]
				Exact = true
			elseif not ExactOnly and not Exact and Name:sub(1, #String):lower() == String then
				Found[#Found + 1] = Table[a]
			end
		end
		
		if #Found > 0 then return true, Found end
		
		if ExactOnly then return end
		
		for a = 1, #Table do
			if (type(Table[a]) == "string" and Table[a] or Table[a].Name):lower():find( String ) then
				Found[#Found + 1] = Table[a]
			end
		end
		
		if #Found > 0 then return true, Found end
	end
end

function Module.IsWildcard(String, Base)
	
	if Base then
		
		for a = 1, #Base do
			
			if (type(Base[a]) == "string" and Base[a] or Base[a].Name):lower() == String then
				
				return false
				
			end
			
		end
		
	end
	
	return TableHasValue(WildCardChars, String)
	
end

function Module.MultipleOf(self, String, Plr, Funcs, Base, BaseChar, ExactOnly)
	
	local Multiple = String:find("&")
	
	if Multiple then
		
		local Strings = string.split(String, "&")
		
		local Matches, Valid = {}, {}
		
		for a = 1, #Strings do
			
			Matches[#Matches + 1] = Module.MultipleOf(self, Strings[a], Plr, Funcs, Base, BaseChar)
			
		end
		
		if #Matches > 1 then
			
			for a = 1, #Matches[1] do
				
				local FoundAll = true
				
				for b = 2, #Matches do
					
					local Found
					
					for c = 1, #Matches[b] do
						
						if Matches[b][c] == Matches[1][a] then
							
							Found = true
							
						end
						
					end
					
					if not Found then FoundAll = false break end
					
				end
				
				if FoundAll then
					
					Valid[#Valid + 1] = Matches[1][a]
					
				end
				
			end
			
		end
		
		return Valid
		
	end
	
	BaseChar = BaseChar or ""
	
	String = String:lower()
	
	local Strings = string.split(String:lower(), ",")
	
	local TotalMatches = {}
	
	for a = 1, #Strings do
		
		local String = Strings[a]:match('^%s*(.*%S)') or ""
		
		if #String > 0 and String:sub(1, #BaseChar) == BaseChar:lower() then
			
			String = String:sub(#BaseChar + 1)
			
			local Invert = false
			
			if String:sub(1, 1) == "!" then
				
				Invert = true
				
				String = String:sub(2)
				
			end
			
			local Matches = {}
			
			local Found = false
			
			if String == Module.ValidChar then
				
				Found, Matches = true, Base[1]
				
			elseif Module.IsWildcard(String, Base) then
				
				Found, Matches = true, {unpack(Base)}
				
			elseif String == "random" then
				
				Found, Matches = true, {Base[math.random(1, #Base)]}
				
			else
				
				for a = 1, #Funcs do
					
					Found, Matches = Funcs[a](self, String, Plr, Matches, Base)
					
					if Found then break end
					
				end
				
			end
			
			if not Found then
				
				Found, Matches = TableHasMatchingObj(Base, String, ExactOnly)
				
			end
			
			if Found then
				
				if type(Matches) ~= "table" then Matches = {Matches} end
				
				if Invert then
					
					local InvertedMatches = {}
					
					for a = 1, #Base do
						
						if not TableHasValue(Matches, Base[a]) then
							
							InvertedMatches[#InvertedMatches + 1] = Base[a]
							
						end
						
					end
					
					Matches = InvertedMatches
					
				end
				
				for a = 1, #Matches do
					
					if not TableHasValue(TotalMatches, Matches[a]) then
						
						TotalMatches[#TotalMatches + 1] = Matches[a]
						
					end
					
				end
				
			end
			
		end
		
	end
	
	return TotalMatches
	
end

-- Target functions --

function Module.FindTools(self, String, Plr, Table)
	
	return Module.MultipleOf(self, String, Plr, {}, (Table or GetValidTools()))
	
end

function Module.FindTeam(self, String, Plr, Matches, Base)
	
	String = String:lower()
	
	if #Base == 0 then return end
	
	String = String:match('^%s*(.*%S)') or ""
	
	if Plr and String == "me" then
		
		if Plr.Team then return true, Plr.Team else return end
		
	elseif String == "biggest" then
		
		local TeamSizes = {}
		
		local Teams = Teams:GetTeams()
		
		for a = 1, #Teams do
			
			TeamSizes[#TeamSizes + 1] = {Teams[a], #Teams[a]:GetPlayers()}
			
		end
		
		table.sort(TeamSizes, function (a, b) return a[2] > b[2] end)
		
		if TeamSizes[1][1] then return true, TeamSizes[1][1] else return end
		
	elseif String == "smallest" then
		
		local TeamSizes = {}
		
		local Teams = Teams:GetTeams()
		
		for a = 1, #Teams do
			
			TeamSizes[#TeamSizes + 1] = {Teams[a], #Teams[a]:GetPlayers()}
			
		end
		
		table.sort(TeamSizes, function (a, b) return a[2] < b[2] end)
		
		if TeamSizes[1][1] then return true, TeamSizes[1][1] else return end
		
	end
	
end

function Module.FindTeams(self, String, Plr)
	
	return Module.MultipleOf(self, String, Plr, {Module.FindTeam}, Teams:GetTeams())
	
end

function Module.FindTeamsForPlr(self, String, Plr)
	
	return Module.MultipleOf(self, String, Plr, {Module.FindTeam}, Teams:GetTeams(), "%")
	
end

function Module.FindGroup(self, String, Plr)
	
	String = String:lower()
	
	if String:sub(1, 1) ~= "^" then return end
	
	String = String:sub(2)
	
	String = String:match('^%s*(.*%S)') or ""
	
	local GroupId, Type, Rank = String:match("^(-*%d+)([><=@#]*)(-*%d*)")
	
	GroupId, Rank = tonumber(GroupId or ""), tonumber(Rank or "1")
	
	if not GroupId then return {} end
	
	if Type == "@" or Type == "#" then
		local Groups = {GroupId}
		
		local Pages = (Type == "@" and game:GetService("GroupService").GetAlliesAsync or game:GetService("GroupService").GetEnemiesAsync)(game:GetService("GroupService"), GroupId)
		
		if not Pages then return Groups end
		
		while true do
			for a, b in ipairs(Pages:GetCurrentPage()) do
				Groups[#Groups + 1] = b.Id
			end
			
			if Pages.IsFinished then
				break
			end
			
			Pages:AdvanceToNextPageAsync()
		end
		
		return Groups
	else
		return {GroupId}, Rank or 1, Type == "=" and 1 or Type == "<" and 2 or nil
	end
end

function Module.FindFriend(self, String, Plr)
	
	String = String:lower()
	
	if String:sub(1, 1) ~= "+" then return end
	 
	String = String:sub(2)
	
	String = String:match('^%s*(.*%S)') or ""
	
	return (Module.FindPlayers(self, String, Plr) or {})[1]
	
end

function Module.FindAge(self, String, Plr)
	
	String = String:lower()
	
	if String:sub(1, 1) ~= "@" then return end
	 
	String = String:sub(2)
	
	String = String:match('^%s*(.*%S)') or ""
	
	local Age, Type = String:match("^(-*%d+)([><=]*)")
	
	Age = tonumber(Age or "")
	
	if not Age then return end
	
	Type = Type == "=" and 1 or Type == "<" and 2 or nil
	
	local Plrs = Players:GetPlayers()
	for i = #Plrs, 1, -1 do
		if (Type == 1 and Plrs[i].AccountAge ~= Age) or (Type == 2 and Plrs[i].AccountAge > Age) or (Type == nil and Plrs[i].AccountAge < Age) then
			table.remove(Plrs, i)
		end
	end
	
	return true, Plrs
end

function Module.FindPlrsNearPlr(self, String, Plr)
	
	String = String:lower()
	
	if String:sub(1, 1) ~= "*" then return end
	
	String = String:sub(2)
	
	String = String:match('^%s*(.*%S)') or ""
	
	local Target, Type, Dist = String:match("^(.+)([><=]*)(-*%d*)")
	
	Target = Module.FindPlayers(self, Target or "", Plr)[1]

	if not Target or not Target.Character or not Target.Character.PrimaryPart then return end
	
	Type = Type == "=" and 1 or Type == "<" and 2 or nil
	
	Target = Target.Character.PrimaryPart.Position
	
	Dist = tonumber(Dist or "15")
	
	local Plrs = Players:GetPlayers()
	
	local Near = {}
	
	for a = 1, #Plrs do
		
		if Plrs[a] ~= Plr and Plrs[a].Character and Plrs[a].Character.PrimaryPart then
			
			if (Type == 1 and math.floor(Plrs[a]:DistanceFromCharacter(Target) + 0.5) == math.floor(Dist + 0.5)) or (Type == 2 and Plrs[a]:DistanceFromCharacter(Target) <= Dist) or (Type == nil and Plrs[a]:DistanceFromCharacter(Target) >= Dist)  then
				
				Near[#Near + 1] = Plrs[a]
				
			end
			
		end
		
	end
	
	return true, Near
	
end

function Module.FindPlrsInGroups(self, String, Plr)
	
	String = String:lower()
	
	local Groups, Rank, Type = Module.FindGroup(self, String, Plr)
	
	if Groups then
		
		local Plrs, Matches = Players:GetPlayers(), {}
		
		for a = 1, #Plrs do
			
			if Plrs[a].Parent then
				
				for b = 1, #Groups do
					
					if not Rank then
						
						if Plrs[a]:IsInGroup(Groups[b]) then
							
							Matches[#Matches + 1] = Plrs[a]
							
							break
							
						end
						
					elseif (Type == 1 and Plrs[a]:GetRankInGroup(Groups[b]) == Rank) or (Type == 2 and Plrs[a]:GetRankInGroup(Groups[b]) <= Rank) or (Type == nil and Plrs[a]:GetRankInGroup(Groups[b]) >= Rank) then
						
						Matches[#Matches + 1] = Plrs[a]
						
						break
						
					end
					
				end
				
			end
			
		end
		
		return true, Matches
		
	end
	
end

function Module.FindPlrsInTeam(self, String, Plr)
	
	String = String:lower()
	
	local Teams, Matches = Module.FindTeamsForPlr(self, String, Plr), {}
	
	if Teams then
		
		local Found = false
		
		for a = 1, #Teams do
			
			if a == 1 then
				
				Matches = Teams[a]:GetPlayers()
				
				Found = #Matches > 0
				
			else
				
				local Plrs = Teams[a]:GetPlayers()
				
				for b = 1, #Plrs do
					
					Found = true
					
					Matches[#Matches + 1] = Plrs[b]
					
				end
				
			end
			
		end
		
		return Found, Matches
		
	end
	
end

function Module.FindFriendsOfPlr(self, String, Plr)
	
	String = String:lower()
	
	local Friend, Matches = Module.FindFriend(self, String, Plr), {}
	
	if Friend then
		
		local Plrs = Players:GetPlayers()
		
		for a = 1, #Plrs do
			
			if Friend:IsFriendsWith(Plrs[a].userId) then
				
				Matches[#Matches + 1] = Plrs[a]
				
			end
			
		end
		
		return true, Matches
		
	end
	
end

function Module.FindPlrsFromString(self, String, Plr)
	if Plr then
		if String:lower() == "me" then
			return true, Plr
		elseif String:lower() == "others" then
			local Plrs = Players:GetPlayers()
			
			table.remove(Plrs, table.find(Plrs, Plr))
			
			return true, Plrs
		end
		
	end
	
	local Plr = tonumber(String) and Players:GetPlayerByUserId(String) or nil
	if Plr then
		return true, Plr
	end
end

Module.MatchFuncs = {Module.FindPlrsInTeam, Module.FindPlrsInGroups, Module.FindFriendsOfPlr, Module.FindPlrsNearPlr, Module.FindAge, Module.FindPlrsFromString}

function Module.FindPlayers(self, String, Plr)
	
	return Module.MultipleOf(self, String, Plr, Module.MatchFuncs, Players:GetPlayers())
	
end

function Module.MatchesPlr(String, Plr)
	
	if Plr.UserId == "Console" then
		
		return not String:lower():find("!$console")
		
	end
	
	local Plrs =  Module.MultipleOf(nil, String, nil, Module.MatchFuncs, Players:GetPlayers(), nil, true)
	
	if Plrs then
		
		for a = 1, #Plrs do
			
			if Plrs[a] == Plr then
				
				return true
				
			end
			
		end
		
	end
	
end

-- ArgTypes --

Module.ArgTypes.String = function (self, Strings, Plr, LastArg, Cmd, Args, ArgSplit)
	
	local String
	
	if LastArg then
		
		String = table.concat(Strings, ArgSplit)
		
	else
		
		String = ""
		
		local a, Start
		
		while Strings[1] do
			
			if not Strings[1] then break end
			
			if not Start then
				
				if Strings[1]:sub(1, 1) == "'" then
					
					Start = "'"
					
					String = table.remove(Strings, 1)
					
					String = String:sub(2)
					
				elseif Strings[1]:sub(1, 1) == '"' then
					
					Start = '"'
					
					String = table.remove(Strings, 1)
					
					String = String:sub(2)
					
				else
					
					String = table.remove(Strings, 1)
					
					break
					
				end
				
			else
				
				String = String .. ArgSplit .. table.remove(Strings, 1)
				
			end
			
			if String:sub(-1) == Start then
				
				String = String:sub(1, -2)
				
				break
				
			end
		end
		
	end
	
	if String == Module.ValidChar then String = String end
	
	if self.Min and #String < self.Min then
		
		return nil, false
		
	end
	
	if self.Max and #String > self.Max then
		
		return nil, false
		
	end
	
	if self.Upper then
		
		String = String:upper()
		
	end
	
	if self.Lower then
		
		String = String:lower()
		
	end
	
	return String
	
end

Module.ArgTypes.Number = function (self, Strings, Plr)
	
	local String = table.remove(Strings, 1)
	
	if String == Module.ValidChar then return 1 end
	
	local Ran, Num = pcall(Calc, String)
	
	if not Ran then return nil, false, Num:sub(-Num:reverse():find(":") + 2) end
	
	if Num then
		
		if self.Min and Num < self.Min then
			
			return nil, false
			
		end
		
		if self.Max and Num > self.Max then
			
			return nil, false
			
		end
		
		return Num
		
	end
	
	return nil, false
	
end

Module.ArgTypeNames["Numbers"] = "Number..."
Module.ArgTypes.Numbers = function (self, Strings, Plr)
	
	local String = table.remove(Strings, 1)
	
	if String == Module.ValidChar then return {1, 2} end
	
	local Strings = string.split(String:lower(), ",")
	
	for a = 1, #Strings do
		
		local Num, Ran, Error = Module.ArgTypes.Number(self, Strings[a], Plr)
		
		if not Num then
			
			return Num, Ran, Error
			
		end
		
		Strings[a] = Num
		
	end
	
end

Module.ArgTypes.Key = function (self, Strings, Plr)
	
	local String = table.remove(Strings, 1)
	
	if String == Module.ValidChar then return Enum.KeyCode.A end
	
	local Keys = Enum.KeyCode:GetEnumItems()
	
	for a = 1, #Keys do
		
		if Keys[a].Name:lower() == String then return Keys[a] end
		
	end
	
	return nil, false
	
end

Module.Toggles = {}

Module.Events[#Module.Events + 1] = Players.PlayerRemoving:Connect(function (Plr)
	
	Module.Toggles[Plr] = nil
	
end)

Module.ArgTypes.Boolean = function (self, Strings, Plr)
	
	local String = table.remove(Strings, 1)
	
	if String == Module.ValidChar then 
		
		return true
		
	end
	
	String = String:lower()
	
	if TableHasValue(BoolEquivs[1], String) then return true end
	
	if TableHasValue(BoolEquivs[2], String) then return false end
	
	return nil, false
	
end

Module.ArgTypes.Time = function (self, Strings, Plr)
	
	local String = table.remove(Strings, 1)
	
	if String == Module.ValidChar then return 5 end
	
	String = String:lower():gsub(" ", "")
	
	local Nums = string.split(String, ":")
	
	if #Nums == 1 then
		
		local Time = 0
		
		for a, b in string.gmatch(Nums[1], "(%-?[%d%.]+)(%w*)") do
			
			local Ran, Num = pcall(Calc, a)
			
			if not Ran then return nil, false, Num:sub(-Num:reverse():find(":") + 2) end
			
			Time = Time + Num * (TimeEquivs[b] or 1)
			
		end
		
		return Time
		
	else
		
		for a = 1, #Nums do
			
			local Ran, Num = pcall(Calc, Nums[a])
			
			if not Ran then return nil, false, Num:sub(-Num:reverse():find(":") + 2) end
			
			Nums[a] = Num
			
		end
		
		if #Nums == 2 then
			
			return Nums[1] * 60 * 60 + Nums[2] * 60
			
		elseif #Nums == 3 then
			
			return Nums[1] * 60 * 60 + Nums[2] * 60 + Nums[3]
			
		end
		
	end
	
end

Module.ArgTypes.ArgType = function (self, Strings, Plr)
	
	local String = table.remove(Strings, 1)
	
	if String == Module.ValidChar then return Module.ArgTypes.Boolean end
	
	String = String:lower()
	
	for a, b in pairs(Module.ArgTypes) do
		
		if a:lower() == String then return b end
		
	end
	
	return nil, false
	
end

Module.ArgTypes.UserId = function (self, Strings, Plr)
	
	local String = table.remove(Strings, 1)
	
	local UserId = tonumber(String)
	
	if UserId then return UserId end
	
	local Plrs = Module.FindPlayers(self, String, Plr)
	
	if #Plrs == 1 then return Plrs[1].UserId end
	
	local Ran, UserId = pcall(Players.GetUserIdFromNameAsync, Players, String)
	
	if Ran then return UserId end
	
	return nil, false
	
end

Module.AddArgMultiple("Tool")

Module.AddArgMultiple("Player")

Module.AddArgMultiple("Team")

Module.AddArgAsset("Sound", 3, 279206904)

Module.AddArgAsset("Place", 9, 64542766)

Module.AddArgAsset("Gear", 19, 125859385)

Module.Defaults.Toggle = function (self, Strings, Plr)
	
	local CurToggle
	
	if self.ToggleValue then
		
		CurToggle = not self.ToggleValue()
		
	else
		
		if not self.ToggleKey then self.ToggleKey = {} end
		
		Module.Toggles[Plr] = Module.Toggles[Plr] or {}
		
		CurToggle = not Module.Toggles[Plr][self.ToggleKey]
		
		Module.Toggles[Plr][self.ToggleKey] = CurToggle
		
	end
	
	return CurToggle
	
end

Module.Defaults.Self = function (self, Strings, Plr) return Plr end

Module.Defaults.SelfTable = function (self, Strings, Plr) return {Plr} end

Module.Defaults.SelfId = function (self, Strings, Plr) return Plr.UserId end

return Module
