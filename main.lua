----Welcome to the "main.lua" file! Here is where all the magic happens, everything from functions to callbacks are done here.
--Startup
local mod = RegisterMod("Ars Goetla", 1)

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







local asmodeus_teleport = 0
local belphelgor_stats = {
    damage = 0,
    damage_stack = 0,
    tears = 0,
    tears_stack = 0,
    add = 0,
}

local game = Game()
local room = game:GetRoom()
local level = game:GetLevel()
local itempool = game:GetItemPool()
local tear_count_room = 0
local beleth_brimstone = 0
local eligos_tear_ring = 0

mod.Items = {
	Lucifer = Isaac.GetItemIdByName("Lucifer Sigil"),
	Mammon = Isaac.GetItemIdByName("Mammon Sigil"),
	Satan = Isaac.GetItemIdByName("Satan Sigil"),
	Abbadon = Isaac.GetItemIdByName("Abbadon Sigil"),
	Asmodeus = Isaac.GetItemIdByName("Asmodeus Sigil"),
	Belzebub = Isaac.GetItemIdByName("Beelzebub Sigil"),
	Agares = Isaac.GetItemIdByName("Agares Sigil"),
	Belphegor = Isaac.GetItemIdByName("Belphegor Sigil"),

    Bael = Isaac.GetItemIdByName("Bael Sigil"),
    Vassago = Isaac.GetItemIdByName("Vassago Sigil"),
    Samigina = Isaac.GetItemIdByName("Samigina Sigil"),
    Marbas  = Isaac.GetItemIdByName("Marbas Sigil"),
    Valefor = Isaac.GetItemIdByName("Valefor Sigil"),
    Amon = Isaac.GetItemIdByName("Amon Sigil"),
    Barbatos = Isaac.GetItemIdByName("Barbatos Sigil"),
    Paimon  = Isaac.GetItemIdByName("Paimon Sigil"),
    Buer = Isaac.GetItemIdByName("Buer Sigil"),
    Gusion  = Isaac.GetItemIdByName("Gusion Sigil"),
    Sitri = Isaac.GetItemIdByName("Sitri Sigil"),
    Beleth  = Isaac.GetItemIdByName("Beleth Sigil"),
    Leraje  = Isaac.GetItemIdByName("Leraje Sigil"),
    Eligos  = Isaac.GetItemIdByName("Eligos Sigil"),
    Zepar = Isaac.GetItemIdByName("Zepar Sigil"),
    Botis = Isaac.GetItemIdByName("Botis Sigil"),
}

local function toTears(fireDelay) --thanks oat for the cool functions for calculating firerate
	return 30 / (fireDelay + 1)
end
local function fromTears(tears)
	return math.max((30 / tears) - 1, -0.99)
end

local DirectionToVector = {
    [Direction.DOWN] = Vector(0, 1),
    [Direction.LEFT] = Vector(-1, 0),
    [Direction.RIGHT] = Vector(1, 0),
    [Direction.UP] = Vector(0, -1),
    [Direction.NO_DIRECTION] = Vector(0, 0)
}
function mod:DirectionToVector(dir, length)
    return DirectionToVector[dir]:Resized(length)
end

--Lucifer, Mammon, Satan, Belzebub, Belphelgor, Vassago, Samigina, Valefor, Barbatos, Buer
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
	if player:HasCollectible(mod.Items.Asmodeus) == true then
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = 2
		end
	end
	if player:HasCollectible(mod.Items.Belzebub) == true then
		if cacheFlag == CacheFlag.CACHE_COLOR then
			player.Color = Color(73/255, 133/255, 41/255, 1.0, 0/255, 0/255, 0/255)
		end
		if cacheFlag == CacheFlag.CACHE_TEARFLAG then
			player.TearFlags = player.TearFlags | TearFlags.TEAR_POISON | TearFlags.TEAR_ACID
		end
	end
	if player:HasCollectible(mod.Items.Belphegor) == true then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 10 * belphelgor_stats.damage_stack
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = math.max(1.0, fromTears(toTears(player.MaxFireDelay) + 3 * belphelgor_stats.tears_stack))
		end
	end
    if player:HasCollectible(mod.Items.Vassago) == true then
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.5 * player:GetCollectibleNum(mod.Items.Vassago, true)
		end
	end
    if player:HasCollectible(mod.Items.Samigina) == true then
		if cacheFlag == CacheFlag.CACHE_FLYING then
			player.CanFly = true
		end
	end
	if player:HasCollectible(mod.Items.Valefor) == true then
		if cacheFlag == CacheFlag.CACHE_TEARFLAG then
			player.TearFlags = player.TearFlags | TearFlags.TEAR_MAGNETIZE | TearFlags.TEAR_ATTRACTOR
		end
	end
	if player:HasCollectible(mod.Items.Barbatos) == true then
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = math.max(1.0, fromTears(toTears(player.MaxFireDelay) / 2))
		end
		if cacheFlag == CacheFlag.CACHE_TEARFLAG then
			player.TearFlags = player.TearFlags | TearFlags.TEAR_PIERCING
		end
	end
	if player:HasCollectible(mod.Items.Buer) == true then
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.4 * player:GetCollectibleNum(mod.Items.Buer, true)
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = math.max(1.0, fromTears(toTears(player.MaxFireDelay) + 0.4 * player:GetCollectibleNum(mod.Items.Buer, true)))
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange - 3 * 40
		end
	end
	if player:HasCollectible(mod.Items.Gusion) == true then
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = math.max(1.0, fromTears(toTears(player.MaxFireDelay) + 0.2 * player:GetCollectibleNum(mod.Items.Gusion, true)))
		end
		if cacheFlag == CacheFlag.CACHE_TEARFLAG then
			player.TearFlags = player.TearFlags | TearFlags.TEAR_PIERCING | TearFlags.TEAR_SLOW
		end
        if cacheFlag == CacheFlag.CACHE_TEARCOLOR then
			player.TearColor = Color(86/255, 113/255, 128/255, 1.0, 169/255, 142/255, 127/255)
		end
	end
    if player:HasCollectible(mod.Items.Sitri) == true then
		if cacheFlag == CacheFlag.CACHE_FLYING then
			player.CanFly = true
		end
	end
	if player:HasCollectible(mod.Items.Leraje) == true then
		if cacheFlag == CacheFlag.CACHE_TEARFLAG then
            player.TearFlags = player.TearFlags | TearFlags.TEAR_PIERCING | TearFlags.TEAR_MYSTERIOUS_LIQUID_CREEP
		end
	end
	if player:HasCollectible(mod.Items.Botis) == true then
		if cacheFlag == CacheFlag.CACHE_SIZE then
            player.SpriteScale = player.SpriteScale + Vector(0.25,0.25)
		end
	end
end
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,mod.CacheEvaluation)

function mod:Death(victim)
	for playerNum = 1, game:GetNumPlayers() do
        local player = game:GetPlayer(playerNum)
		if player:HasCollectible(mod.Items.Mammon) == true then
			if victim:IsEnemy() == true then
				Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY, victim.Position, Vector(0,0), nil)
                print("3")
			end
            print("2")
		end
        print("1")
	end
end
mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH,mod.Death)

--Asmodeus, Belphelgor
function mod:NewRun(IsContinued)
    if IsContinued == false then
        asmodeus_teleport = 0
        belphelgor_stats.damage = 0
        belphelgor_stats.damage_stack = 0
        belphelgor_stats.tears = 0
        belphelgor_stats.tears_stack = 0
        belphelgor_stats.add = 0
    end
end
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.NewRun)

--Satan, Asmodeus, Belphelgor
function mod:NewLevel()
	for playerNum = 1, game:GetNumPlayers() do
        local player = game:GetPlayer(playerNum)

        asmodeus_teleport = 0

		if player:HasCollectible(mod.Items.Satan) == true then
			room:TrySpawnDevilRoomDoor(true, true)
		end
		if player:HasCollectible(mod.Items.Belphegor) == true then
			belphelgor_stats.add = math.random(1,2)
            if belphelgor_stats.add == 1 then
                belphelgor_stats.damage_stack = belphelgor_stats.damage_stack + 1
                player:AddCacheFlags(CacheFlag.CACHE_ALL)
                player:EvaluateItems()
            end
            if belphelgor_stats.add == 2 then
                belphelgor_stats.tears_stack = belphelgor_stats.tears_stack + 1
                player:AddCacheFlags(CacheFlag.CACHE_ALL)
                player:EvaluateItems()
            end
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

--Abbadon, Asmodeus, Barbatos
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
        if victim.Type == player.Type then
            asmodeus_teleport = asmodeus_teleport + 1
		    if player:HasCollectible(mod.Items.Asmodeus) == true then
                if asmodeus_teleport == 1 then
                    player:UseActiveItem(CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS, UseFlag.USE_NOANIM)
                end
            end
		    if player:HasCollectible(mod.Items.Barbatos) == true then
                local tempEffects = player:GetEffects()
                local barbatos_bird = tempEffects:AddCollectibleEffect(CollectibleType.COLLECTIBLE_DEAD_BIRD, false, 1)
            end
		end
	end
end
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,mod.Damage)

--Agares, Vassago, Zepar
function mod:Collison(player, offender)
    if player:HasCollectible(mod.Items.Agares) == true then
        if offender:IsVulnerableEnemy() == true then
            if offender:IsBoss() == false then
                if math.random(1,10) == 1 then
                    offender:AddEntityFlags(EntityFlag.FLAG_ICE_FROZEN)
                end
            end
        end
    end
    if player:HasCollectible(mod.Items.Vassago) == true then
        if offender:IsVulnerableEnemy() == true then
            offender:AddBurn(EntityRef(player), 33, 1)
        end
    end
    if player:HasCollectible(mod.Items.Zepar) == true then
        if offender:IsVulnerableEnemy() == true then
            if math.random(1,10) == 1 then
                local zepar_tear = player:FireTear(offender.Position, Vector.Zero, true, true, false, nil, 0):ToTear()
                zepar_tear:AddTearFlags(TearFlags.TEAR_PUNCH)
                
                local tempEffects = player:GetEffects()
                tempEffects:AddCollectibleEffect(CollectibleType.COLLECTIBLE_SPEED_BALL, false, 1)
            end
        end
    end
    if player:HasCollectible(mod.Items.Paimon) == true then
        if offender:IsVulnerableEnemy() == true then
            Isaac.Explode(player.Position, player, 50)
            Isaac.Explode(player.Position+Vector(30,0), player, 50)
            Isaac.Explode(player.Position-Vector(30,0), player, 50)

            local paimonshock_inline = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BOMB_EXPLOSION, 0, player.Position, Vector(0,0), nil):ToEffect()
            paimonshock_inline.Color = Color(0/255, 0/255, 0/255, 0.5, 255/255, 0/255, 0/255)
            paimonshock_inline.SpriteScale = paimonshock_inline.SpriteScale + Vector(1.1,1.1)
            paimonshock_inline:Update()

            local pimon = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BOMB_EXPLOSION, 0, player.Position, Vector(0,0), nil):ToEffect()
            pimon.Color = Color(0/255, 0/255, 0/255, 1.0, 0/255, 0/255, 0/255)
            paimonshock_inline.SpriteScale = paimonshock_inline.SpriteScale + Vector(1,1)
            pimon.DepthOffset = pimon.DepthOffset +100000
            pimon:Update()
        end
    end
end
mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_COLLISION, mod.Collison)

--Belzebub
itemGrab:AddCallback(itemGrab.InventoryCallback.POST_ADD_ITEM, function (player, item, count, touched, fromQueue)
    if not touched or not fromQueue then
        for i=1,count do
            local pos = Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 0, true)
            player:AddCollectible(CollectibleType.COLLECTIBLE_HALO_OF_FLIES, 0, true)
            player:AddCollectible(CollectibleType.COLLECTIBLE_HALO_OF_FLIES, 0, true)
            player:AddCollectible(CollectibleType.COLLECTIBLE_HALO_OF_FLIES, 0, true)
            player:RemoveCollectible(CollectibleType.COLLECTIBLE_HALO_OF_FLIES, false, 0, false)
            player:RemoveCollectible(CollectibleType.COLLECTIBLE_HALO_OF_FLIES, false, 0, false)
            player:RemoveCollectible(CollectibleType.COLLECTIBLE_HALO_OF_FLIES, false, 0, false)
        end
    end
end, mod.Items.Belzebub)

--Bael
function mod:NewRoom()
	for playerNum = 1, game:GetNumPlayers() do
        local player = game:GetPlayer(playerNum)
        local tempEffects = player:GetEffects()

        tear_count_room = 0
        beleth_brimstone = 0
        eligos_tear_ring = 6

        if player:HasCollectible(mod.Items.Bael) == true then

            local tempEffects = player:GetEffects()
            tempEffects:AddCollectibleEffect(CollectibleType.COLLECTIBLE_CAMO_UNDIES, false, 1)
        end
    end
end
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,mod.NewRoom)

--Bael, Barbatos, Beleth
function mod:Tear(tear)
	for playerNum = 1, game:GetNumPlayers() do
        local player = game:GetPlayer(playerNum)
        tear:ToTear()

        if player:HasCollectible(mod.Items.Bael) == true and tear_count_room == 0 then
            tear:AddTearFlags(TearFlags.TEAR_LIGHT_FROM_HEAVEN)
            tear.Color = Color(255/255, 255/255, 255/255, 1.0, 255/255, 0/255, 0/255)

            tear_count_room = 1
        end
        if player:HasCollectible(mod.Items.Barbatos) == true then
            tear.Scale = tear.Scale + 0.15
        end
        if player:HasCollectible(mod.Items.Beleth) == true then
            beleth_brimstone = beleth_brimstone + 1
            if beleth_brimstone == 10 then
                local beleth_brimstone_fire = player:FireBrimstone(mod:DirectionToVector(player:GetHeadDirection(), 1), nil, 0.5)
                beleth_brimstone_fire.Color = Color(255/255, 255/255, 255/255, 1.0, 100/255, 255/255, 255/255)
                beleth_brimstone = 0
            end
        end
        if player:HasCollectible(mod.Items.Eligos) == true then
            if eligos_tear_ring > 0 then
                for i=10,1,-1 do
                    local eligos_tear = Isaac.Spawn(EntityType.ENTITY_TEAR, 0, 0, player.Position, RandomVector()*player.ShotSpeed*10, nil):ToTear()
                    eligos_tear:ChangeVariant(TearVariant.NAIL)
                    eligos_tear.Color = Color(177/255, 177/255, 177/255, 1.0, 255/255, 255/255, 0/255)

                    eligos_tear_ring = eligos_tear_ring - 1
                end
            end
        end
        if player:HasCollectible(mod.Items.Botis) == true then
            tear:ChangeVariant(TearVariant.SWORD_BEAM)
            tear.Color = Color(255/255, 0/255, 255/255, 1.0, 0/255, 255/255, 0/255)
        end
    end
end
mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, mod.Tear)

--Samigina, Amon, Barbatos, Paimon
function mod:PercUpdate(player)
    if player:HasCollectible(mod.Items.Samigina) == true and math.random(1,15) == 1 then
        if player:IsFrame(10, 0) then
            player:FireTechLaser(player.Position, 1, mod:DirectionToVector(player:GetHeadDirection(), 1), false, false, nil, 0.75)
            local samigina_tear = player:FireTear(player.Position, mod:DirectionToVector(player:GetHeadDirection(), player.ShotSpeed*10), true, true, false, nil, 1.25):ToTear()
            samigina_tear:AddTearFlags(TearFlags.TEAR_SHIELDED | TearFlags.TEAR_LASER | TearFlags.TEAR_ATTRACTOR)
            samigina_tear.Color = Color(0/255, 50/255, 50/255, 1.0, 155/255, 0/255, 0/255)
            samigina_tear:Update()
        end
    end
    if player:HasCollectible(mod.Items.Amon) == true and math.random(1,15) == 1 then
            if player:IsFrame(10, 0) then
            local amon_flame = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.RED_CANDLE_FLAME, 0, player.Position, mod:DirectionToVector(player:GetHeadDirection(), player.ShotSpeed*10), nil)
            amon_flame.Color = Color(0/255, 0/255, 0/255, 1.0, 132/255, 33/255, 189/255)
            amon_flame.CollisionDamage = player.Damage
            amon_flame:Update()
        end
    end
    if player:HasCollectible(mod.Items.Barbatos) == true and math.random(1,30) == 1 then
        if player:IsFrame(10, 0) then
            local barbatos_tear = player:FireTear(player.Position, mod:DirectionToVector(player:GetHeadDirection(), player.ShotSpeed*15), true, true, false, nil, 1.25):ToTear()
            barbatos_tear.CollisionDamage = 99
            barbatos_tear:AddTearFlags(TearFlags.TEAR_SHIELDED | TearFlags.TEAR_EXTRA_GORE)
            barbatos_tear.Color = Color(0/255, 0/255, 0/255, 1.0, 100/255, 100/255, 100/255)
            barbatos_tear:Update()
        end
    end
    if player:HasCollectible(mod.Items.Paimon) == true and math.random(1,30) == 1 then
        if player:IsFrame(10, 0) then
            if player:HasCollectible(CollectibleType.COLLECTIBLE_XRAY_VISION) == false then
                player:AddCollectible(CollectibleType.COLLECTIBLE_XRAY_VISION)
                local itemConfig = Isaac.GetItemConfig()
                local itemConfigItem = itemConfig:GetCollectible(CollectibleType.COLLECTIBLE_XRAY_VISION)
                player:RemoveCostume(itemConfigItem)
            end
        end
    end
end
mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.PercUpdate)

--Marbas, Gusion, Sitri
function mod:TearCollide(tear, victim)
	for playerNum = 1, game:GetNumPlayers() do
        local player = game:GetPlayer(playerNum)

        if player:HasCollectible(mod.Items.Marbas) == true and math.random(1,100) == 1 then
            if victim:IsVulnerableEnemy() == true and victim.Type ~= EntityType.ENTITY_FLY then
                if victim:IsBoss() == false then
                    victim:ToNPC():Morph(EntityType.ENTITY_FLY, 0, 0, 0)
                    Isaac.Spawn(EntityType.ENTITY_FLY, 0, 0, victim.Position, Vector(0,0), nil)
                end
            end
        end
        if player:HasCollectible(mod.Items.Gusion) == true and math.random(1,10) == 1 then
            if victim:IsVulnerableEnemy() == true then
                if victim:IsBoss() == false then
                    victim:AddFreeze(EntityRef(player), 999)
                end
            end
        end
        if player:HasCollectible(mod.Items.Sitri) == true and math.random(1,5) == 1 then
            if victim:IsVulnerableEnemy() == true then
                if victim:IsBoss() == false then
                    victim:AddCharmed(EntityRef(player), 999)
                    local pink_cloud = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, victim.Position, Vector(0,0), nil)
                    pink_cloud.Color = Color(180/255, 180/255, 180/255, 1.0, 296/255, 52/255, 91/255)
                end
            end
        end
        if player:HasCollectible(mod.Items.Botis) == true then
            tear.CollisionDamage = tear.CollisionDamage + 1 * tear.FrameCount
        end
    end
end
mod:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, mod.TearCollide)

--Valefor
itemGrab:AddCallback(itemGrab.InventoryCallback.POST_ADD_ITEM, function (player, item, count, touched, fromQueue)
    if not touched or not fromQueue then
        for i=1,count do
            local pos = Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 0, true)

            local valefor_whipper = Isaac.Spawn(EntityType.ENTITY_WHIPPER, 0, 0, player.Position, Vector(0,0), nil):ToNPC()
            valefor_whipper:AddCharmed(EntityRef(player), -1)
            valefor_whipper.MaxHitPoints = 9999999999
            valefor_whipper.HitPoints = 9999999999
            valefor_whipper:Update()
        end
    end
end, mod.Items.Valefor)
----Welcome to the Item Descriptions. This section holds everything to do with the mod's compatibility with External Item Descriptions and Encyclopedia.
--Startup

mod.description = {
	Lucifer  = "Flight#{{ArrowUp}} 1.5x Damage multiplier",
	Mammon   = "Pink cobweb tears that slow enemies#Enemies drop a coin upon death",
	Satan    = "{{ArrowUp}} +5 Damage#Spawns the {{DevilRoom}} Devil Room door in the first room of every floor",
	Abbadon  = "Drops two {{Card78}} Cracked Keys#5% chance to spawn a friendly Gaper when hitting an enemy",
	Asmodeus = "{{ArrowUp}} MAX Speed#The first time you get hit on a floor, teleports you to the previous room.",
	Belzebub = "Gain the Beelzebub transformation#Poison and acid tears",
	Agares   = "Upon taking contact damage, there is a 10% chance to freeze the enemy",
	Belphegor = "Upon entering a new floor, gain either {{ArrowUp}} +10 Damage or {{ArrowUp}} +3 Tears",
    Bael = "Upon entering a new room, turn invisible#The first tear you shoot in a room will be a holy light tear",
    Vassago = "{{ArrowUp}} +0.5 Speed#Burn enemies on contact",
    Samigina = "Flight#Sometimes fire a laser tear",
    Marbas = "Rarely turns a hit enemy into a fly",
    Valefor = "Magnetic tears#Spawn a friendly immortal Whipper",
    Amon = "Often fire a purple flame that rarely charms enemies",
    Barbatos = "{{ArrowDown}} -50% Firerate#Sometimes fire a bullet tear that kills the enemy hit instantly#When first hit in a room, summon a Dead Bird",
    Paimon = "Reveals secret rooms#verytime you get collided with by an enemy, spawns an explosion#Spawns a random devil room item",
    Buer = "{{ArrowUp}} +1 Red heart#{{ArrowUp}} +0.4 Speed#{{ArrowUp}} +0.4 Tears# {{ArrowDown}} -3 Range",
    Gusion  = "{{ArrowUp}} +1 Red heart#{{ArrowUp}} +0.2 Tears#Tears now stun enemies for 5 seconds",
    Sitri = "Flight#Sometimes fire charming tears that explode into a pink cloud",
    Beleth  = "Fire a white brimstone laser for every 10 tears you fire",
    Leraje = "Piercing tears#Tears leave poison creep",
    Eligos = "First time you shoot in a room, fire random spear tears",
    Zepar = "Sometimes when hit, knock enemies back#{{ArrowUp}} +0.3 Speed for the room when damaged",
    Botis = "Fire sword/snake tears that increase damage the longer their distance",
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
    EID:addCollectible(mod.Items.Bael, mod.description.Bael)
	EID:addCollectible(mod.Items.Vassago, mod.description.Vassago)
	EID:addCollectible(mod.Items.Samigina, mod.description.Samigina)
	EID:addCollectible(mod.Items.Marbas, mod.description.Marbas)
	EID:addCollectible(mod.Items.Valefor, mod.description.Valefor)
	EID:addCollectible(mod.Items.Amon, mod.description.Amon)
	EID:addCollectible(mod.Items.Barbatos, mod.description.Barbatos)
	EID:addCollectible(mod.Items.Paimon, mod.description.Paimon)
	EID:addCollectible(mod.Items.Buer, mod.description.Buer)
	EID:addCollectible(mod.Items.Gusion, mod.description.Gusion)
	EID:addCollectible(mod.Items.Sitri, mod.description.Sitri)
	EID:addCollectible(mod.Items.Beleth, mod.description.Beleth)
	EID:addCollectible(mod.Items.Leraje, mod.description.Leraje)
	EID:addCollectible(mod.Items.Eligos, mod.description.Eligos)
    EID:addCollectible(mod.Items.Zepar, mod.description.Zepar)
	EID:addCollectible(mod.Items.Botis, mod.description.Botis)
end

--Encyclopedia documentation found here: https://github.com/AgentCucco/encyclopedia-docs/wiki.
if Encyclopedia then
	local Wiki = {
	}
end