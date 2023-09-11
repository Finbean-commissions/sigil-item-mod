----Welcome to the "item-descriptions.lua" file! This file holds everything to do with the mod's compatibility with External Item Descriptions and Encyclopedia.
--Startup
local mod = RegisterMod("Commission Template - Items (Passive, Active, Trinket and Card)", 1)

mod.item = {
    Passive = Isaac.GetItemIdByName("Passive Example"),
    Active = Isaac.GetItemIdByName("Active Example"),
    Trinket = Isaac.GetTrinketIdByName("Trinket Example"),
    Card = Isaac.GetCardIdByName("Card Example"),
}

mod.description = {
	Passive = "{{ArrowUp}} +1.22 Fire Rate",
	Active = "On use, spawns 1 or 2 Card Examples",
	Trinket = "{{ArrowDown}} -0.20 Speed#{{ArrowUp}} +2 Damage",
	Card = "Spawns 8 random hearts",
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