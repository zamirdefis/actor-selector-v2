---@diagnostic disable-next-line: undefined-global
local aegisub = aegisub -- for lsp :P

-- CONSTS
script_author = "loksuf (aka pohnui)" -- не трогать!
script_name = "actor-selector-v2" -- не трогать!
script_version = "0.1" -- не трогать!
script_description =
  "Скрипт для выбора актеров" -- это можно изменить

local macro_headers = {
  name = "Выбрать актеров [🎭]", -- название скрипта в меню выбора автоматизаций
  hint = "Открыть интерфейс выбора актеров", -- текст при наведении
} macro_headers.hint = "[" .. script_name .. "] " .. macro_headers.hint -- можно изменить, но не стоит

local config = {

  selector_max_x = 3, -- максимальное количество колонок на странице
  selector_max_y = 20, -- максимальное количество строк в колонке
  default_option = 2, -- режим выбора (от 1 до 4)

  ui = {
    button = {
      selection_apply = "Применить",
      selection_cancel = "Отмена",
      selection_next = ">",
      selection_previous = "<",
      selection_sel_all = "Все",
      selection_desel_all = "Никто"
    },
    dropdown = {
      sel_options = {
        "Выделить строки выбранных актёров",
        "Выделить всё, кроме строк выбранных актёров",
        "Удалить строки выбранных актёров",
        "Удалить всё, кроме строк выбранных актёров"
      }
    }
  }
}

-- LUA UTILS

local function shallow_copy(original)
  local copy = {}
  for key, value in pairs(original) do
    copy[key] = value
  end
  return copy
end

--  dbg
local function co(msg, endl)
  if (type(msg) == "number") then
    msg = tostring(msg)
  end
  if (endl) then
    msg = msg .. "\n"
  end
  aegisub.debug.out(msg)
end

local function con(msg)
  co(msg, true)
end

-- разраб aegisub даун, не описал таблицу линии и мне пришлось написать эту уродскую функцию >_<
-- view_table(subtitles[20])
local function view_table(tbl, layer_)
  layer_ = layer_ or 0

  local function val_format(val)
    if (type(val) == "string") then
      return string.format("\"%s\"", val)
    else
      return tostring(val)
    end
  end

  local function rep_co(msg, add, count)
    count = count or layer_
    if (add) then count = count + add end
    if count ~= 0 then
      co(string.format("%s%s", string.rep("  ", count), msg))
    else
      co(msg)
    end
  end
  
  rep_co("{\n")
  for key, value in pairs(tbl) do
    if (type(key) == "table") then
      view_table(key, layer_ + 1)
    else
      rep_co(val_format(key), 1)
    end
    co(" = ")
    if (type(value) == "table") then
      co("\n")
      view_table(value, layer_ + 1)
    else
      co(val_format(value))
      co("\n")
    end
  end
  rep_co("}\n")
end

-- сюда передавать таблицу с таблицами вида { name = "checkbox_name", value = true/false } или просто строки с названием (им будет применено значение второго аргумента)
local function view_selector_ui(els, default_value, x_max, y_max, page, select_mode)
  local checkbox_template = {
    class = "checkbox",
    value = true,
    name = "view_selector_element_checkbox",
    x = 0,
    y = 0,
    width = 1,
    height = 1
  }

  local label_template = {
    class = "label",
    label = "",
    x = 0,
    y = 0,
    width = 1,
    height = 1
  }

  local ui_config = {}
  x_max = x_max or 3
  y_max = y_max or 10
  if (x_max < 1) then x_max = 1 end
  if (y_max < 1) then y_max = 1 end
  default_value = default_value or false

  local res = {}

  table.insert(ui_config, shallow_copy(label_template))

  table.insert(ui_config, {
    class = "dropdown",
    name = "select_mode",
    items = config.ui.dropdown.sel_options,
    value = select_mode or config.ui.dropdown.sel_options[2],
    x = (x_max * 2) - 1, y = y_max + 1, width = 1, height = 1
  })

  local x = 0
  local y = 1

  for index, el in ipairs(els) do
    local value = default_value
    local name = "<!!!UNDEFINED!!!>"
    if (type(el) == "table") then
      value = el.value == nil and default_value or el.value
      name = el.name or name
    elseif (type(el) == "string") then
      name = el
    end

    if (index <= (x_max * y_max * page) and index > (x_max * y_max * page) - (x_max * y_max)) then

      local label = shallow_copy(label_template)
      label.x = x + 1
      label.y = y
      label.label = name

      local checkbox = shallow_copy(checkbox_template)
      checkbox.x = x
      checkbox.y = y
      checkbox.name = checkbox.name .. tostring(index)
      checkbox.value = value

      table.insert(ui_config, label)
      table.insert(ui_config, checkbox)
      y = y + 1
      if (y >= y_max + 1) then
        x = x + 2
        y = 1
      end

    end
    table.insert(res, {name = name, value = value})
  end

  local pages = math.ceil(#res / (x_max * y_max))
  ui_config[1].label = string.format("%d/%d [%d/%d]", page, pages,
        page * x_max * y_max < #res and page * x_max * y_max or #res, #res)

  local ui_buttons = {
    config.ui.button.selection_sel_all,
    config.ui.button.selection_desel_all,
    config.ui.button.selection_previous,
    config.ui.button.selection_next,
    config.ui.button.selection_apply,
    config.ui.button.selection_cancel
  }

  local ui_pressed_btn, ui_res = aegisub.dialog.display(ui_config, ui_buttons)
  if (ui_pressed_btn == config.ui.button.selection_cancel) then
    return { res = els, pressed_btn = config.ui.button.selection_cancel, ui_res = ui_res}
  end

  for key, value in pairs(ui_res) do
    local str_num = string.match(key, "^" .. checkbox_template.name .. "(%d+)$")
    if (str_num) then
      local num = tonumber(str_num)
      if num <= #res then
        res[num].value = value
      end
    end
  end
  return {res = res, pressed_btn = ui_pressed_btn, ui_res = ui_res}
end

-- MAIN
local entry = function(subtitles, selected_lines, active_line)

  local sub_begin_index = -1

  local actors_map = {}
  local actors_array = {}
  local num_lines = #subtitles
  for index = 1, num_lines do
    local line = subtitles[index]
    if (line.class == "dialogue" and line.actor) then
      sub_begin_index = (sub_begin_index == -1) and index or sub_begin_index
      if not actors_map[line.actor] then
        actors_map[line.actor] = {}
      end
      table.insert(actors_map[line.actor], index)
    end
  end

  for actor, value in pairs(actors_map) do
    table.insert(actors_array, actor)
  end
  table.sort(actors_array)
  for index = 1, #actors_array do
    actors_array[index] = { name = actors_array[index], value = false }
  end

  local current_page = 1
  local local_actors_array = shallow_copy(actors_array)
  local select_mode = false
  while (true) do
    local res = view_selector_ui(local_actors_array, true, config.selector_max_x, config.selector_max_y, current_page, select_mode)
    select_mode = res.ui_res.select_mode
    if (not res) then break end
    local_actors_array = res.res
    if (res.pressed_btn == config.ui.button.selection_previous) then
      current_page = current_page - 1
      if (current_page < 1) then
        current_page = 1
      end
    elseif (res.pressed_btn == config.ui.button.selection_next) then
      current_page = current_page + 1
      local max_page = math.ceil(#actors_array / (config.selector_max_x * config.selector_max_y))
      if (current_page > max_page) then
        current_page = max_page
      end
    elseif (res.pressed_btn == config.ui.button.selection_sel_all) then
      for index = 1, #res.res do
        res.res[index].value = true
      end
    elseif (res.pressed_btn == config.ui.button.selection_desel_all) then
      for index = 1, #res.res do
        res.res[index].value = false
      end
    elseif (res.pressed_btn == config.ui.button.selection_apply) then
      actors_array = local_actors_array
      break
    else
      return
    end
  end
  
  local indexes = {}
  for index, actor in ipairs(actors_array) do
    if (actor.value) then
      local actor_indexes = actors_map[actor.name]
      for jndex, actor_index in ipairs(actor_indexes) do
        table.insert(indexes, actor_index)
      end
    end
  end

  local function make_set(indexed_table)
    local set = {}
    for index, value in ipairs(indexed_table) do
      set[value] = true
    end
    return set
  end

  local indexes_set = make_set(indexes)
  
  if (select_mode == config.ui.dropdown.sel_options[1]) then
    return indexes
  elseif (select_mode == config.ui.dropdown.sel_options[3]) then
    table.sort(indexes)
    for i = #indexes, 1, -1 do
      local target_index = indexes[i]
      subtitles.delete(target_index)
    end
  else
    local neg_indexes = {}
    for index = 1, #subtitles do
      local line = subtitles[index]
      if (line.class == "dialogue" and line.actor) then
        if not indexes_set[index] then
          table.insert(neg_indexes, index)
        end
      end
    end
    if (select_mode == config.ui.dropdown.sel_options[2]) then
      return neg_indexes
    elseif (select_mode == config.ui.dropdown.sel_options[4]) then
      table.sort(neg_indexes)
      for i = #neg_indexes, 1, -1 do
        subtitles.delete(neg_indexes[i])
      end
    end
  end
end

aegisub.register_macro(
  macro_headers.name,
  macro_headers.hint,
  entry
)
