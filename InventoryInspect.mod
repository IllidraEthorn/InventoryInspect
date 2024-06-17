return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Inventory Inspect` encountered an error loading the Darktide Mod Framework.")

		new_mod("InventoryInspect", {
			mod_script       = "InventoryInspect/scripts/mods/InventoryInspect/InventoryInspect",
			mod_data         = "InventoryInspect/scripts/mods/InventoryInspect/InventoryInspect_data",
			mod_localization = "InventoryInspect/scripts/mods/InventoryInspect/InventoryInspect_localization",
		})
	end,
	packages = {},
}