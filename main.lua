----Welcome to the "main.lua" file! Here is where all the magic happens, everything from functions to callbacks are done here.
--Startup
local mod = RegisterMod("Sigils of Demonic Intent", 1)
local game = Game()

mod.Items = {
    Passive = Isaac.GetItemIdByName("Lucifer Sigil"),
    Active = Isaac.GetItemIdByName("Active Example"),
    Trinket = Isaac.GetTrinketIdByName("Trinket Example"),
    Card = Isaac.GetCardIdByName("Card Example"),
}

function mod:UseItem(item, _, player, UseFlags, Slot, _)
	if UseFlags & UseFlag.USE_OWNED == UseFlag.USE_OWNED then
		if item == mod.Items.Active then
            player:AnimateCollectible(mod.Items.Active, "UseItem")
            for i = 1,2 do
                Isaac.Spawn(5, 300, mod.Items.Card, player.Position, Vector(0,-48), nil)
            end
        end
    end
end
mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.UseItem)

function mod:UseCard(card, player)
    if card == mod.Items.Card then
        for i = 1,8 do
            Isaac.Spawn(5, 10, 0, player.Position, RandomVector(), nil)
        end
    end
end
mod:AddCallback(ModCallbacks.MC_USE_CARD,mod.UseCard)

local function toTears(fireDelay) --thanks oat for the cool functions for calculating firerate
	return 30 / (fireDelay + 1)
end
local function fromTears(tears)
	return math.max((30 / tears) - 1, -0.99)
end

function mod:CacheEvaluation(player, cacheFlag)
	if player:HasCollectible(mod.Items.Passive) == true then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage * 1.50 * player:GetCollectibleNum(mod.Items.Passive, true)
		end
		if cacheFlag == CacheFlag.CACHE_FLYING then
			player.CanFly = true
		end
	end
	if player:HasTrinket(mod.Items.Trinket) == true then
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed - 0.2 * player:GetTrinketMultiplier(mod.Items.Trinket)
		end
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2 * player:GetTrinketMultiplier(mod.Items.Trinket)
		end
	end
end
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,mod.CacheEvaluation)

include("item-descriptions.lua")