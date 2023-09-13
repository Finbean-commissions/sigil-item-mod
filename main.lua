----Welcome to the "main.lua" file! Here is where all the magic happens, everything from functions to callbacks are done here.
--Startup
local mod = RegisterMod("Ars Goetla", 1)
local game = Game()

mod.Items = {
	Lucifer = Isaac.GetItemIdByName("Lucifer Sigil"),
}

local function toTears(fireDelay) --thanks oat for the cool functions for calculating firerate
	return 30 / (fireDelay + 1)
end
local function fromTears(tears)
	return math.max((30 / tears) - 1, -0.99)
end

function mod:CacheEvaluation(player, cacheFlag)
	if player:HasCollectible(mod.Items.Lucifer) == true then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.50 * player:GetCollectibleNum(mod.Items.Lucifer, true)
		end
		if cacheFlag == CacheFlag.CACHE_FLYING then
			player.CanFly = true
		end
		print("got")
	end
end
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,mod.CacheEvaluation)

include("item-descriptions.lua")