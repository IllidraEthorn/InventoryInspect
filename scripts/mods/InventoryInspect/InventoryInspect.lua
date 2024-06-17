local mod = get_mod("InventoryInspect")
local UIWidget = require("scripts/managers/ui/ui_widget")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")
local PartyImmateriumManager = require("scripts/managers/party_immaterium/party_immaterium_manager")
local InventoryBackgroundView = require("scripts/ui/views/inventory_background_view/inventory_background_view")

local partyList = mod:persistent_table("partyList", {nil,  nil,  nil, nil})
local ii_queue = nil
local ii_view_queue = nil
local active_view = nil

--recursively prints an entire table, used for debugging only
function tprint (t, s)
    for k, v in pairs(t) do
        local kfmt = '["' .. tostring(k) ..'"]'
        if type(k) ~= 'string' then
            kfmt = '[' .. k .. ']'
        end
        local vfmt = '"'.. tostring(v) ..'"'
        if type(v) == 'table' then
            tprint(v, (s or '')..kfmt)
        else
            if type(v) ~= 'string' then
                vfmt = tostring(v)
            end
            print(type(t)..(s or '')..kfmt..' = '..vfmt)
        end
    end
end

local player_from_account_id = function(account_id)
    local player_info = Managers.data_service.social:get_player_info_by_account_id(account_id)
    local is_own_player = player_info:is_own_player()
    local unique_id = player_info._player_unique_id
    local player = unique_id and Managers.player:player_from_unique_id(unique_id)

    if not player then
        player = table.clone_instance(player_info)
        player.local_player_id = function()
            return 1
        end
        player.peer_id = function()
            return Managers.player:local_player(1):peer_id()
        end
        player.name = player.character_name
    end

    player._ii_account_id = account_id
    player._ii_is_own_player = is_own_player

    return player
end

local refresh_partyList = function(self)
    local all_members = Managers.party_immaterium:all_members()
    partyList = {nil,  nil,  nil, nil}
    for i, member in ipairs(all_members) do

        local player = player_from_account_id(member:account_id())

        if player and player.profile then
            local profile = player:profile()

            if profile then
                partyList[i] = player
            end
        end     
    end
end

local _open_inventory = function(parent, player)
    if player and player.profile then
        if Managers.ui:view_active("inventory_background_view") then
            ii_queue = player
            ii_view_queue = active_view
            Managers.ui:close_view("inventory_background_view")
        else
            player = player_from_account_id(player._ii_account_id)
            if not player._ii_is_own_player then
                Managers.ui:open_view("inventory_background_view", nil, nil, nil, nil, {
                    is_readonly = true,
                    player = player
                })
            else
                Managers.ui:open_view("inventory_background_view")
            end
        end
    end
end

local button_def_table = {
    __inspect_player_1 = {
        scenegraph_definition = {
            parent = "screen",
            vertical_alignment = "bottom",
            horizontal_alignment = "left",
            size = { 300, 60 },
            position = { 350, 0, 100 }
        },
        pressed_callback = function(self, widget)
            _open_inventory(self, partyList[1])
        end,
        get_player = function(self)
            return partyList[1]
        end,
        allow_readonly = true,
    },
    __inspect_player_2 = {
        scenegraph_definition = {
            parent = "screen",
            vertical_alignment = "bottom",
            horizontal_alignment = "left",
            size = { 300, 60 },
            position = { 350+300*1, 0, 100 }
        },
        pressed_callback = function(self, widget)
            _open_inventory(self, partyList[2])
        end,
        get_player = function(self)
            return partyList[2]
        end,
        allow_readonly = true,
    },
    __inspect_player_3 = {
        scenegraph_definition = {
            parent = "screen",
            vertical_alignment = "bottom",
            horizontal_alignment = "left",
            size = { 300, 60 },
            position = { 350+300*2, 0, 100 }
        },
        pressed_callback = function(self, widget)
            _open_inventory(self, partyList[3])
        end,
        get_player = function(self)
            return partyList[3]
        end,
        allow_readonly = true,
    },
    __inspect_player_4 = {
        scenegraph_definition = {
            parent = "screen",
            vertical_alignment = "bottom",
            horizontal_alignment = "left",
            size = { 300, 60 },
            position = { 350+300*3, 0, 100 }
        },
        pressed_callback = function(self, widget)
            _open_inventory(self, partyList[4])
        end,
        get_player = function(self)
            return partyList[4]
        end,
        allow_readonly = true,
    }
}

mod:hook_require("scripts/ui/views/inventory_background_view/inventory_background_view_definitions", function(definitions)
	for name, button_def in pairs(button_def_table) do
		local button = UIWidget.create_definition(ButtonPassTemplates.terminal_button_small, name, {
			text = mod:localize("widget" .. name),
			view_name = button_def.view_name
		})
		definitions.widget_definitions[name] = button
		definitions.scenegraph_definition[name] = button_def.scenegraph_definition
	end
end)

mod:hook_safe(InventoryBackgroundView, "on_enter", function(self)
    refresh_partyList(self)
	for name, button_def in pairs(button_def_table) do
		local widget = self._widgets_by_name[name]
		if widget then
            if button_def:get_player() then
                widget.visible = true
                local tl = get_mod("true_level")
                local tl_is_enabled = tl and tl:is_enabled()
                local text = button_def:get_player():profile().archetype.string_symbol..' '..button_def:get_player():name()

                if tl_is_enabled then
                    local character_id = button_def:get_player():profile().character_id
                    local memory = tl._memory
                    local progression_data = memory.progression[character_id] or memory.temp[character_id]
                    if progression_data then
                        text = text..'\n'..tl.replace_level_text("", progression_data, "social_menu", true)
                    end
                else
                    text = text.." - "..button_def:get_player():profile().current_level.." "
                end
                
                widget.content.text = text
            else
                widget.visible = false
            end
			widget.content.hotspot.pressed_callback = function()
				button_def.pressed_callback(self, widget)
			end
		end
	end
end)

mod:hook_safe(PartyImmateriumManager, "update", function(self, ...)
    if ii_queue then
        local player = ii_queue
        local profile = player:profile()

        if profile and not Managers.ui:view_active("inventory_background_view") then
            _open_inventory(self, player)
            ii_queue = nil
        end
    end
end)

mod:hook_safe(InventoryBackgroundView, "update", function(self)
    if self._top_panel and self._top_panel:selected_index() ~= 1 then
        active_view = self._top_panel:selected_index()
    else
        active_view = nil
    end

    if ii_view_queue and active_view ~= ii_view_queue then
        self:_force_select_panel_index(ii_view_queue)
        ii_view_queue = nil
    end
end)

mod.debug = {
    is_enabled = function()
        return mod:get("enable_debug_mode")
    end,
    echo = function(text)
        if mod.debug.is_enabled() then
            mod:echo(text)
        end
    end,
}

--checks to see if a table has a specified value
function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end