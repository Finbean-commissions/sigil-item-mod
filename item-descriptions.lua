----Welcome to the "item-descriptions.lua" file! This file holds everything to do with the mod's compatibility with External Item Descriptions and Encyclopedia.
--Startup
local mod = RegisterMod("Ars Goetla", 1)

mod.item = {
    Lucifer = Isaac.GetItemIdByName("Lucifer Sigil"),
}

mod.description = {
	Lucifer = "{{ArrowUp}} +1.22 Fire Rate",
}

--External Item Descriptions documentation found here: https://github.com/wofsauge/External-Item-Descriptions/wiki.
if EID then
	EID:addCollectible(mod.item.Lucifer, mod.description.Lucifer)
end

--Encyclopedia documentation found here: https://github.com/AgentCucco/encyclopedia-docs/wiki.
if Encyclopedia then
	local Wiki = {
		Lucifer = {
			{ -- Description
				{str = "description", fsize = 2, clr = 3, halign = 0},
				{str = "+1.22 Fire Rate"},
			},
		},
	}

	Encyclopedia.AddItem({
		ID = mod.item.Lucifer,
		WikiDesc = Wiki.Lucifer,
		Pools = {
			Encyclopedia.ItemPools.POOL_DEVIL,
			Encyclopedia.ItemPools.POOL_GREED_DEVIL,
		},
	})
end