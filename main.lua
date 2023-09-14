----Welcome to the "main.lua" file! Here is where all the magic happens, everything from functions to callbacks are done here.
--Startup
local mod = RegisterMod("Commission Template - Items (Passive, Active, Trinket and Card)", 1)

local callbacks = {}    ---@type table<InventoryCallback, table<CollectibleType, function[]>>
local trackedItems = {} ---@type CollectibleType[]

local ItemGrabCallback =
{
    ---@enum InventoryCallback
    InventoryCallback =
    {
        --- Fired when an item is added to the player's inventory
        --- - `player`: EntityPlayer - the player who picked up the item
        --- - `item`: CollectibleType - id of the item that was picked up
        --- - `count`: integer - amount of item that was picked up
        --- - `touched`: boolean - whether the picked up item was picked up before (.Touched property set to true)
        --- - `queued`: boolean - whether the picked up item was picked up from the item queue
        POST_ADD_ITEM = 1,
        --- Fired when an item is removed from the player's inventory
        --- - `player`: EntityPlayer - the player who lost the item
        --- - `item`: CollectibleType - id of the item that was lost
        --- - `count`: integer - amount of item that was lost
        POST_REMOVE_ITEM = 2,
    },
    ---@param callbackId InventoryCallback
    ---@param callbackFunc function
    ---@param item CollectibleType @id of item for which the callback should be fired
    AddCallback = function (self, callbackId, callbackFunc, item)
        assert(type(callbackId) == "number", "callbackId must be a number, got "..type(callbackId).." instead")
        assert(type(callbackFunc) == "function", "callbackFunc must be a function, got "..type(callbackFunc).." instead")
        assert(type(item) == "number", "item must be a number, got "..type(item).." instead")

        if callbacks[callbackId] == nil then
            callbacks[callbackId] = {}
        end

        if callbacks[callbackId][item] == nil then
            callbacks[callbackId][item] = {}

            --- insert item id into the list of tracked items while maintaining ascending order
            if #trackedItems == 0 then
                table.insert(trackedItems, item)
            else
                local inserted = false
                for i=#trackedItems,1,-1 do
                    if trackedItems[i] == item then
                        inserted = true
                        break
                    elseif trackedItems[i] < item then
                        table.insert(trackedItems, i + 1, item)
                        inserted = true
                        break
                    end
                end

                if not inserted then
                    table.insert(trackedItems, 1, item)
                end
            end
        end

        table.insert(callbacks[callbackId][item], callbackFunc)
    end,
    ---@param callbackId InventoryCallback
    ---@param callbackFunc function
    ---@param item CollectibleType
    RemoveCallback = function (self, callbackId, callbackFunc, item)
        assert(type(callbackId) == "number", "callbackId must be a number, got "..type(callbackId).." instead")
        assert(type(callbackFunc) == "function", "callbackFunc must be a function, got "..type(callbackFunc).." instead")
        assert(type(item) == "number", "item must be a number, got "..type(item).." instead")

        if callbacks[callbackId] == nil or callbacks[callbackId][item] == nil then
            return
        end

        for i = 1, #callbacks[callbackId][item] do
            if callbacks[callbackId][item][i] == callbackFunc then
                table.remove(callbacks[callbackId][item], i)
            end
        end

        if #callbacks[callbackId][item] == 0 then
            callbacks[callbackId][item] = nil

            --- remove item id from the list of tracked items
            for i = 1, #trackedItems do
                if trackedItems[i] == item then
                    table.remove(trackedItems, i)
                    break
                end
            end
        end
    end,
    ---@param callbackId InventoryCallback
    ---@param ... any
    FireCallback = function (self, callbackId, ...)
        assert(type(callbackId) == "number", "callbackId must be a number, got "..type(callbackId).." instead")

        local _, item = ...
        if callbacks[callbackId] == nil or callbacks[callbackId][item] == nil then
            return
        end

        for i = 1, #callbacks[callbackId][item] do
            callbacks[callbackId][item][i](...)
        end
    end,
    --- Prevents ADD/REMOVE callbacks from firing for items added directly to the player's inventory next player update.
    --- Items added from queue will still trigger ADD callback.  
    ---@param player EntityPlayer
    CancelInventoryCallbacksNextFrame = function (self, player)
        assert(player:ToPlayer(), "EntityPlayer expected")
        player:GetData().PreventNextInventoryCallback = true
    end,
}

local itemGrab = ItemGrabCallback

---@param player EntityPlayer
---@return table<CollectibleType, integer>
local function getPlayerInventory(player)
    local inventory = {}

    for _, item in ipairs(trackedItems) do
        local colCount = player:GetCollectibleNum(item, true)
        inventory[item] = colCount
    end

    return inventory
end

---@param inv1 table<CollectibleType, integer>
---@param inv2 table<CollectibleType, integer>
---@return table<CollectibleType, integer>
local function getInventoryDiff(inv1, inv2)
    local out = {}

    for item, count in pairs(inv1) do
        local diff = count - (inv2[item] or 0)
        out[item] = diff
    end

    return out
end

---@class PlayerInventoryData
---@field PrevItems table<CollectibleType, integer>?
---@field PrevQueue ItemConfig_Item?
---@field PrevTouched boolean?

---@param player EntityPlayer
---@return PlayerInventoryData
local function getPlayerInvData(player)
    local data = player:GetData()
    if data.PlayerInventoryData == nil then
        data.PlayerInventoryData = {
            PrevItems = getPlayerInventory(player),
            PrevQueue = nil,
            PrevTouched = nil,
        }
    end
    return data.PlayerInventoryData
end

---@param player EntityPlayer
local function PostPlayerUpdate(_, player)
    if player:IsCoopGhost() then
        return
    end

    local invData = getPlayerInvData(player)
    local inventory = getPlayerInventory(player)
    local diff = getInventoryDiff(inventory, invData.PrevItems)
    local queueItem = player.QueuedItem.Item
    local prevQueueItem = invData.PrevQueue

    if queueItem == nil and prevQueueItem ~= nil then
        if diff[prevQueueItem.ID] and diff[prevQueueItem.ID] > 0 then
            -- print("item got picked up from queue, id =", prevQueueItem.ID, "touched =", invData.PrevTouched)
            itemGrab:FireCallback(itemGrab.InventoryCallback.POST_ADD_ITEM, player, prevQueueItem.ID, diff[prevQueueItem.ID], invData.PrevTouched, true)
            diff[prevQueueItem.ID] = 0
        end
    end

    if not player:GetData().PreventNextInventoryCallback then
        local addedItems = {}
        local removedItems = {}

        for _, item in ipairs(trackedItems) do
            if diff[item] > 0 then
                addedItems[#addedItems+1] = {ID = item, Count = diff[item]}
            elseif diff[item] < 0 then
                removedItems[#removedItems+1] = {ID = item, Count = -diff[item]}
            end
        end

        -- Item add callbacks are fired first
        for i=1, #addedItems do
            local item = addedItems[i]
            itemGrab:FireCallback(itemGrab.InventoryCallback.POST_ADD_ITEM, player, item.ID, item.Count, false, false)
        end

        for i=1, #removedItems do
            local item = removedItems[i]
            itemGrab:FireCallback(itemGrab.InventoryCallback.POST_REMOVE_ITEM, player, item.ID, item.Count)
        end
    else
        player:GetData().PreventNextInventoryCallback = false
    end

    invData.PrevItems = inventory
    invData.PrevQueue = queueItem
    invData.PrevTouched = player.QueuedItem.Touched

end
mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, PostPlayerUpdate)

---@param cmd string
---@param prm string
local function OnCommand(_, cmd, prm)
    if cmd ~= "itemgrab" then
        return
    end

    local params = {}
    for s in prm:gmatch("%S+") do
        table.insert(params, s)
    end

    -- Spawns item pedestal with id as first parameter and .Touched set to true if second parameter is 1 or greater.
    if params[1] == "spwn" then
        local id = tonumber(params[2]) or 0
        local touched = tonumber(params[3]) or 0

        local room = Game():GetRoom()
        local pos = room:FindFreePickupSpawnPosition(room:GetCenterPos(), 0, true)
        local pickup = Isaac.Spawn(5, PickupVariant.PICKUP_COLLECTIBLE, id, pos, Vector.Zero, nil):ToPickup()

        if touched >= 1 then
            pickup.Touched = true
        end
    -- Prints currently tracked items.
    elseif params[1] == "tracked" then
        print("Currently tracked items:")
        for i, item in ipairs(trackedItems) do
            print(i, item)
        end
    end
end
mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, OnCommand)

mod:AddCallback(ModCallbacks.MC_USE_ITEM, function (_, item, rng, player)
    if item == CollectibleType.COLLECTIBLE_D4 then
        itemGrab:CancelInventoryCallbacksNextFrame(player)
        -- print("d4 used at frame", Game():GetFrameCount())
    elseif item == CollectibleType.COLLECTIBLE_D100 then
        itemGrab:CancelInventoryCallbacksNextFrame(player)
        -- print("d100 used at frame", Game():GetFrameCount())
    end
end)








local game = Game()
local room = game:GetRoom()
local level = game:GetLevel()

mod.Items = {

	Lucifer = Isaac.GetItemIdByName("Lucifer Sigil"),
	Mammon = Isaac.GetItemIdByName("Mammon Sigil"),
	Satan = Isaac.GetItemIdByName("Satan Sigil"),
	Abbadon = Isaac.GetItemIdByName("Abbadon Sigil"),
	Asmodeus = Isaac.GetItemIdByName("Asmodeus Sigil"),
	Belzebub = Isaac.GetItemIdByName("Beelzebub Sigil"),
	Agares = Isaac.GetItemIdByName("Agares Sigil"),
	Belphegor = Isaac.GetItemIdByName("Belphegor Sigil"),
}

local function toTears(fireDelay) --thanks oat for the cool functions for calculating firerate
	return 30 / (fireDelay + 1)
end
local function fromTears(tears)
	return math.max((30 / tears) - 1, -0.99)
end

--Lucifer, Mammon, Satan
function mod:CacheEvaluation(player, cacheFlag)
	if player:HasCollectible(mod.Items.Lucifer) == true then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage * 1.5 * player:GetCollectibleNum(mod.Items.Lucifer, true)
		end
		if cacheFlag == CacheFlag.CACHE_FLYING then
			player.CanFly = true
		end
	end
	if player:HasCollectible(mod.Items.Mammon) == true then
		if cacheFlag == CacheFlag.CACHE_TEARCOLOR then
			player.TearColor = Color(200/255, 200/255, 200/255, 1.0, 185/255, 120/255, 115/255)
		end
		if cacheFlag == CacheFlag.CACHE_TEARFLAG then
			player.TearFlags = player.TearFlags | TearFlags.TEAR_SLOW
		end
	end
	if player:HasCollectible(mod.Items.Satan) == true then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 5 * player:GetCollectibleNum(mod.Items.Satan, true)
		end
	end
end
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,mod.CacheEvaluation)

function mod:Death(entity)
	for playerNum = 1, game:GetNumPlayers() do
        local player = game:GetPlayer(playerNum)
		if player:HasCollectible(mod.Items.Mammon) == true then
			if entity:IsVulnerableEnemy() == true then
				Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, 0, entity.Position, Vector(0,0), nil)
			end
		end
	end
end
mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH,mod.Death)


--Satan
function mod:NewLevel()
	for playerNum = 1, game:GetNumPlayers() do
        local player = game:GetPlayer(playerNum)

		if player:HasCollectible(mod.Items.Satan) == true then
			room:TrySpawnDevilRoomDoor(true, true)
		end
	end
end
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,mod.NewLevel)

--Abbadon
itemGrab:AddCallback(itemGrab.InventoryCallback.POST_ADD_ITEM, function (player, item, count, touched, fromQueue)
    if not touched or not fromQueue then
        for i=1,count do
            local pos = Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 0, true)
            Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_CRACKED_KEY, pos, Vector(2,0), player)
			Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_CRACKED_KEY, pos, Vector(-2,0), player)
        end
    end
end, mod.Items.Abbadon)

--Abbadon
function mod:Damage(victim)
	for playerNum = 1, game:GetNumPlayers() do
        local player = game:GetPlayer(playerNum)

		if player:HasCollectible(mod.Items.Abbadon) == true then
			if victim:IsVulnerableEnemy() == true then
				if victim:IsBoss() == false then
					if math.random(1,20) == 1 then
					local abbadon_gaper = Isaac.Spawn(EntityType.ENTITY_GAPER, 0, 0, player.Position, Vector(0,0), nil)
					abbadon_gaper:AddCharmed(EntityRef(player), -1)
					end
				end
			end
		end
	end
end
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,mod.Damage)

----Welcome to the Item Descriptions. This section holds everything to do with the mod's compatibility with External Item Descriptions and Encyclopedia.
--Startup

mod.description = {
	Lucifer  = "Flight#{{ArrowUp}} 1.5x Damage multiplier",
	Mammon   = "Cobweb tears that slow enemies#Enemies drop one coin upon death",
	Satan    = "{{ArrowUp}} +5 Damage#Spawns the {{DevilRoom}} Devil Room door in the first room of every floor",
	Abbadon  = "Drops two {{Card78}} Cracked Keys#5% chance to  spawn a friendly Gaper when hitting an enemy",
	Asmodeus = "{{ArrowUp}} MAX Speed#The first time you get hit on a floor, teleports you to the previous room.",
	Belzebub = "Gain the Beelzebub transformation#Poison tears",
	Agares   = "Upon taking contact damage, there is a 10% chance to freeze the enemy",
	Belphegor = "Upon entering a new floor, gain either {{ArrowUp}} +10 Damage or {{ArrowUp}} +3 Tears",
}

--External Item Descriptions documentation found here: https://github.com/wofsauge/External-Item-Descriptions/wiki.
if EID then
	EID:addCollectible(mod.Items.Lucifer, mod.description.Lucifer)
	EID:addCollectible(mod.Items.Mammon, mod.description.Mammon)
	EID:addCollectible(mod.Items.Satan, mod.description.Satan)
	EID:addCollectible(mod.Items.Abbadon, mod.description.Abbadon)
	EID:addCollectible(mod.Items.Asmodeus, mod.description.Asmodeus)
	EID:addCollectible(mod.Items.Belzebub, mod.description.Belzebub)
	EID:addCollectible(mod.Items.Agares, mod.description.Agares)
	EID:addCollectible(mod.Items.Belphegor, mod.description.Belphegor)
end

--Encyclopedia documentation found here: https://github.com/AgentCucco/encyclopedia-docs/wiki.
if Encyclopedia then
	local Wiki = {
	}
end