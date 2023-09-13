----Welcome to the "main.lua" file! Here is where all the magic happens, everything from functions to callbacks are done here.
--Startup
local mod = RegisterMod("Commission Template - Items (Passive, Active, Trinket and Card)", 1)
local game = Game()

mod.Items = {
    Passive = Isaac.GetItemIdByName("Passive Example"),
    Active = Isaac.GetItemIdByName("Active Example"),
    Trinket = Isaac.GetTrinketIdByName("Trinket Example"),
    Card = Isaac.GetCardIdByName("Card Example"),

	Lucifer = Isaac.GetItemIdByName("Lucifer Sigil"),
	Mammon = Isaac.GetItemIdByName("Mammon Sigil"),
	Satan = Isaac.GetItemIdByName("Satan Sigil"),
	Abbadon = Isaac.GetItemIdByName("Abbadon Sigil"),
	Asmodeus = Isaac.GetItemIdByName("Asmodeus Sigil"),
	Belzebub = Isaac.GetItemIdByName("Beelzebub Sigil"),
	Agares = Isaac.GetItemIdByName("Agares Sigil"),
	Belphegor = Isaac.GetItemIdByName("Belphegor Sigil"),
}

function mod:UseItem(item, _, player, UseFlags, Slot, _)
	if UseFlags & UseFlag.USE_OWNED == UseFlag.USE_OWNED then
		if item == mod.Items.Active then
            player:AnimateCollectible(mod.Items.Active, "UseItem")
            game:Fart(player.Position, 85, nil, 1, 0, Color(0,0,0,0,0,0,0))
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
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = math.max(1.0, fromTears(toTears(player.MaxFireDelay) + 1.22 * player:GetCollectibleNum(mod.Items.Passive, true)))
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

	if player:HasCollectible(mod.Items.Lucifer) == true then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage * 1.5 * player:GetCollectibleNum(mod.Items.Lucifer, true)
		end
		if cacheFlag == CacheFlag.CACHE_FLYING then
			player.CanFly = true
		end
	end
end
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,mod.CacheEvaluation)

----Welcome to the "item-descriptions.lua" file! This file holds everything to do with the mod's compatibility with External Item Descriptions and Encyclopedia.
--Startup
mod.item = {
    Passive = Isaac.GetItemIdByName("Passive Example"),
    Active = Isaac.GetItemIdByName("Active Example"),
    Trinket = Isaac.GetTrinketIdByName("Trinket Example"),
    Card = Isaac.GetCardIdByName("Card Example"),

	Lucifer = Isaac.GetItemIdByName("Lucifer Sigil"),
	Mammon = Isaac.GetItemIdByName("Mammon Sigil"),
	Satan = Isaac.GetItemIdByName("Satan Sigil"),
	Abbadon = Isaac.GetItemIdByName("Abbadon Sigil"),
	Asmodeus = Isaac.GetItemIdByName("Asmodeus Sigil"),
	Belzebub = Isaac.GetItemIdByName("Beelzebub Sigil"),
	Agares = Isaac.GetItemIdByName("Agares Sigil"),
	Belphegor = Isaac.GetItemIdByName("Belphegor Sigil"),
}

mod.description = {
	Passive  = "{{ArrowUp}} +1.22 Fire Rate",
	Active   = "On use, spawns 1 or 2 Card Examples",
	Trinket  = "{{ArrowDown}} -0.20 Speed#{{ArrowUp}} +2 Damage",
	Card     = "Spawns 8 random hearts",

	Lucifer  = "Flight                               #{{ArrowUp}} 1.5x Damage multiplier",
	Mammon   = "Cobweb tears that slow enemies       #Enemies drop one coin upon death",
	Satan    = "{{ArrowUp}} +5 Damage                #100% chance for devil deals",
	Abbadon  = "Drops two {{Card78}} Cracked Keys    #Sometimes spawns a friendly Gaper when hitting an enemy",
	Asmodeus = "{{ArrowUp}} MAX Speed                #The first time you get hit on a floor, teleports you to the previous room.",
	Belzebub = "Gain the Beelzebub transformation    #Poison tears",
	Agares   = "10% chance to freeze enemies when taking contact damage from an enemy",
	Belphego = "Upon entering a new floor, gain either {{ArrowUp}} +10 Damage or {{ArrowUp}} +3 Tears",
}

--External Item Descriptions documentation found here: https://github.com/wofsauge/External-Item-Descriptions/wiki.
if EID then
	EID:addCollectible(mod.item.Passive, mod.description.Passive)
	EID:addCollectible(mod.item.Active, mod.description.Active)
	EID:addTrinket(mod.item.Trinket, mod.description.Trinket)
	EID:addCard(mod.item.Card, mod.description.Card)
end

--Encyclopedia documentation found here: https://github.com/AgentCucco/encyclopedia-docs/wiki.
if Encyclopedia then
	local Wiki = {
		Passive = {
			{ -- Description
				{str = "description", fsize = 2, clr = 3, halign = 0},
				{str = "+1.22 Fire Rate"},
			},
		},
		Active = {
			{ -- Description
				{str = "description", fsize = 2, clr = 3, halign = 0},
				{str = "On use, spawns 1 or 2 Card Examples"},
			},
		},
		Trinket = {
			{ -- Description
				{str = "description", fsize = 2, clr = 3, halign = 0},
				{str = "-0.20 Speed"},
				{str = "+2 Damage"},
			},
		},
		Card = {
			{ -- Description
				{str = "description", fsize = 2, clr = 3, halign = 0},
				{str = "Spawns 8 random hearts"},
			},
		},
	}

	Encyclopedia.AddItem({
		ID = mod.item.Passive,
		WikiDesc = Wiki.Passive,
		Pools = {
			Encyclopedia.ItemPools.POOL_BOSS,
			Encyclopedia.ItemPools.POOL_GREED_BOSS,
		},
	})
	Encyclopedia.AddItem({
		ID = mod.item.Active,
		WikiDesc = Wiki.Active,
		Pools = {
			Encyclopedia.ItemPools.POOL_TREASURE,
			Encyclopedia.ItemPools.POOL_GREED_TREASURE,
		},
	})
	Encyclopedia.AddTrinket({
		ID = mod.item.Trinket,
		WikiDesc = Wiki.Trinket,
	})
	Encyclopedia.AddCard({
		ID = mod.item.Card,
		WikiDesc = Wiki.Card,
		Sprite = Encyclopedia.RegisterSprite("mod.path/content/gfx/ui_cardfronts.anm2", "Card Example"),
	  })
end