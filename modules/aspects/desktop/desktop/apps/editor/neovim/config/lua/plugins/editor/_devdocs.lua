-- [nfnl] fnl/plugins/editor/_devdocs.fnl
local _local_1_ = require("lib/nvim")
local v_2f_24 = _local_1_["v/$"]
local v_2fn = _local_1_["v/n"]
local v_2flater = _local_1_["v/later"]
local M = {}
local _filetype_aliases = {fennel = "lua", javascriptreact = "javascript", sh = "bash", tsx = "typescript", typescriptreact = "typescript"}
local _spinner_id = "devdocs-download"
local _progress_namespace = vim.api.nvim_create_namespace("devdocs-download-progress")
local _progress_inactive = "\226\150\177\226\150\177\226\150\177\226\150\177\226\150\177\226\150\177\226\150\177"
local _progress_complete = "\226\150\176\226\150\176\226\150\176\226\150\176\226\150\176\226\150\176\226\150\176"
local _download_worker_count = 4
local _line_similarity_weight = 40
local _active_progress = nil
local function _text(value)
  if (type(value) == "string") then
    return string.lower(value)
  else
    return ""
  end
end
local function _registry_matches_filetype_3f(registry, filetype)
  local filetype0 = (_filetype_aliases[filetype] or filetype)
  local filetype1 = _text(filetype0)
  local slug = _text(registry.slug)
  local alias = _text(registry.alias)
  local registry_type = _text(registry.type)
  local name = _text(registry.name)
  return ((filetype1 ~= "") and ((slug == filetype1) or (alias == filetype1) or (registry_type == filetype1) or (name == filetype1) or vim.startswith(slug, (filetype1 .. "~"))))
end
local function _registries_for_filetype(filetype)
  local registries_usecase = require("devdocs.application.usecases.registries_usecase")
  local registries = (registries_usecase.list() or {})
  local matches = {}
  for _, registry in ipairs(registries) do
    if _registry_matches_filetype_3f(registry, filetype) then
      table.insert(matches, registry)
    else
    end
  end
  return matches
end
local function _tailwind_context_3f(parser, range)
  local node = parser:named_node_for_range(range, {ignore_injections = false})
  local matches_3f = false
  while (node and not matches_3f) do
    if string.find(node:type(), "attribute", 1, true) then
      local text = vim.treesitter.get_node_text(node, 0)
      matches_3f = (string.match(text, "^%s*class%s*=") or string.match(text, "^%s*className%s*=") or string.match(text, "^%s*:class%s*=") or string.match(text, "^%s*v%-bind:class%s*="))
    else
    end
    node = node:parent()
  end
  return matches_3f
end
local function _cursor_filetypes()
  local _let_5_ = vim.api.nvim_win_get_cursor(0)
  local row = _let_5_[1]
  local col = _let_5_[2]
  local range = {(row - 1), col, (row - 1), col}
  local ok_3f, filetypes
  local function _6_()
    local parser = vim.treesitter.get_parser(0)
    if not parser:is_valid(false, range) then
      parser:parse(range)
    else
    end
    local language_tree = parser:language_for_range(range)
    local filetypes0 = {language_tree:lang()}
    if _tailwind_context_3f(parser, range) then
      table.insert(filetypes0, "tailwindcss")
    else
    end
    return filetypes0
  end
  ok_3f, filetypes = pcall(_6_)
  if ok_3f then
    return filetypes
  else
    return {vim.bo.filetype}
  end
end
local function _registry_matches_filetypes_3f(registry, filetypes)
  local matches_3f = false
  for _, filetype in ipairs(filetypes) do
    matches_3f = (matches_3f or _registry_matches_filetype_3f(registry, filetype))
  end
  return matches_3f
end
local function _progress_window_valid_3f(progress)
  return (progress.win and vim.api.nvim_win_is_valid(progress.win) and (vim.api.nvim_win_get_buf(progress.win) == progress.buf))
end
local function _close_progress(progress)
  if _progress_window_valid_3f(progress) then
    return vim.api.nvim_win_close(progress.win, true)
  else
    return nil
  end
end
local function _focus_progress_line(progress, line)
  if _progress_window_valid_3f(progress) then
    return pcall(vim.api.nvim_win_set_cursor, progress.win, {line, 0})
  else
    return nil
  end
end
local function _progress_lines(progress, spinner_text)
  local lines = {}
  local header
  if progress.running then
    header = ((spinner_text or _progress_inactive) .. " Downloading DevDocs documentation")
  elseif (progress.failed > 0) then
    header = string.format("Finished with %d failed download(s)", progress.failed)
  else
    header = "All DevDocs downloads completed"
  end
  table.insert(lines, header)
  table.insert(lines, "")
  for _, row in ipairs(progress.rows) do
    local marker
    do
      local case_13_ = row.status
      if (case_13_ == "active") then
        marker = (spinner_text or _progress_inactive)
      elseif (case_13_ == "done") then
        marker = _progress_complete
      elseif (case_13_ == "failed") then
        marker = _progress_inactive
      else
        local _0 = case_13_
        marker = _progress_inactive
      end
    end
    table.insert(lines, string.format("%s %s", marker, row.registry.name))
  end
  return lines
end
local function _render_progress(progress, spinner_text)
  if (vim.api.nvim_buf_is_valid(progress.buf) and _progress_window_valid_3f(progress)) then
    local lines = _progress_lines(progress, spinner_text)
    vim.api.nvim_set_option_value("modifiable", true, {buf = progress.buf})
    vim.api.nvim_buf_set_lines(progress.buf, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(progress.buf, _progress_namespace, 0, -1)
    for index, row in ipairs(progress.rows) do
      local hl_group
      do
        local case_15_ = row.status
        if (case_15_ == "done") then
          hl_group = "DiagnosticOk"
        elseif (case_15_ == "failed") then
          hl_group = "DiagnosticError"
        else
          local _ = case_15_
          hl_group = nil
        end
      end
      if hl_group then
        vim.api.nvim_buf_add_highlight(progress.buf, _progress_namespace, hl_group, (index + 1), 0, #_progress_complete)
      else
      end
    end
    return vim.api.nvim_set_option_value("modifiable", false, {buf = progress.buf})
  else
    return nil
  end
end
local function _open_progress(registries)
  if (_active_progress and _active_progress.running) then
    if _progress_window_valid_3f(_active_progress) then
      vim.api.nvim_set_current_win(_active_progress.win)
    else
    end
    v_2fn("A DevDocs download is already in progress", vim.log.levels.WARN)
  else
  end
  if (_active_progress and _active_progress.running) then
    return nil
  else
    if _active_progress then
      _close_progress(_active_progress)
    else
    end
    local buf = vim.api.nvim_create_buf(false, true)
    local rows
    do
      local tbl_26_ = {}
      local i_27_ = 0
      for _, registry in ipairs(registries) do
        local val_28_ = {registry = registry, status = "pending"}
        if (nil ~= val_28_) then
          i_27_ = (i_27_ + 1)
          tbl_26_[i_27_] = val_28_
        else
        end
      end
      rows = tbl_26_
    end
    local max_name_width
    do
      local width = 0
      for _, registry in ipairs(registries) do
        width = math.max(width, vim.fn.strdisplaywidth(registry.name))
      end
      max_name_width = width
    end
    local width = math.max(44, math.min((max_name_width + 10), (vim.o.columns - 4)))
    local height = math.max(3, math.min((#rows + 2), (vim.o.lines - 4)))
    local row = math.max(0, math.floor(((vim.o.lines - height) / 2)))
    local col = math.max(0, math.floor(((vim.o.columns - width) / 2)))
    local win = vim.api.nvim_open_win(buf, true, {relative = "editor", row = row, col = col, width = width, height = height, style = "minimal", focusable = true, border = "rounded", title = " DevDocs Downloads ", title_pos = "center"})
    local progress = {buf = buf, win = win, rows = rows, running = true, failed = 0}
    vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
    vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
    vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
    vim.api.nvim_set_option_value("undolevels", -1, {buf = buf})
    vim.api.nvim_set_option_value("filetype", "devdocs-progress", {buf = buf})
    for _, key in ipairs({"q", "<Esc>"}) do
      local function _23_()
        return _close_progress(progress)
      end
      vim.keymap.set("n", key, _23_, {buffer = buf, nowait = true, silent = true})
    end
    do
      local spinner = require("spinner")
      local function _24_(event)
        return _render_progress(progress, event.text)
      end
      spinner.config(_spinner_id, {kind = "custom", pattern = "aesthetic", placeholder = _progress_inactive, ui_scope = _spinner_id, on_update_ui = _24_})
    end
    _active_progress = progress
    _render_progress(progress, _progress_inactive)
    return progress
  end
end
local function _finish_progress(progress)
  local spinner = require("spinner")
  progress.running = false
  spinner.stop(_spinner_id, true)
  _focus_progress_line(progress, 1)
  _render_progress(progress, _progress_inactive)
  if (progress.failed == 0) then
    local function _26_()
      if ((_active_progress == progress) and not progress.running) then
        _close_progress(progress)
        _active_progress = nil
        return nil
      else
        return nil
      end
    end
    return vim.defer_fn(_26_, 1500)
  else
    return nil
  end
end
local function _install_registry(registry, on_done)
  local container = require("devdocs.application.ports.dependency_registry")
  local locks_repository = container.locks_repository()
  local entries_usecase = require("devdocs.application.usecases.entries_usecase")
  local setup_config = require("devdocs.domain.defaults.setup_config")
  local installer = vim.fs.joinpath(vim.fn.stdpath("config"), "scripts", "devdocs_install.py")
  local destination = vim.fs.joinpath(vim.fn.stdpath("data"), "devdocs", setup_config.plataform, registry.slug)
  local url = string.format("https://documents.devdocs.io/%s/db.json", registry.slug)
  local function _29_(result)
    if (result.code ~= 0) then
      local error_text = vim.trim((result.stderr or ""))
      local _30_
      if (error_text == "") then
        _30_ = ""
      else
        _30_ = (": " .. error_text)
      end
      v_2fn(("Failed to install " .. registry.name .. " documentation" .. _30_), vim.log.levels.ERROR)
      return on_done(false)
    else
      local function _32_()
        locks_repository.save({id = registry.slug, name = registry.name})
        return on_done(true)
      end
      return entries_usecase.install_async(registry.slug, _32_)
    end
  end
  return vim.system({"python3", installer, url, destination}, {text = true}, vim.schedule_wrap(_29_))
end
local function _install_queue(registries)
  local progress = _open_progress(registries)
  if progress then
    local spinner = require("spinner")
    local next_index = 1
    local active = 0
    local completed = 0
    local start_available = nil
    local function _34_()
      while ((active < _download_worker_count) and (next_index <= #registries)) do
        local index = next_index
        local row = progress.rows[index]
        next_index = (next_index + 1)
        active = (active + 1)
        row.status = "active"
        _focus_progress_line(progress, (index + 2))
        local function _35_(success)
          if success then
            row.status = "done"
          else
            row.status = "failed"
          end
          if not success then
            progress.failed = (progress.failed + 1)
          else
          end
          local function _38_()
            collectgarbage("collect")
            active = (active - 1)
            completed = (completed + 1)
            if (completed == #registries) then
              return _finish_progress(progress)
            else
              return start_available()
            end
          end
          return vim.schedule(_38_)
        end
        _install_registry(row.registry, _35_)
      end
      return _render_progress(progress, spinner.render(_spinner_id))
    end
    start_available = _34_
    spinner.start(_spinner_id)
    return start_available()
  else
    return nil
  end
end
local function _install_selected_registry(registry)
  return _install_queue({registry})
end
M.ui_call = function(fn_name, ...)
  local dvd = require("devdocs")
  local dvd_ui = dvd.ui.documentations
  return dvd_ui[fn_name](...)
end
M.install_for_filetype = function()
  local filetype = vim.bo.filetype
  local registries = _registries_for_filetype(filetype)
  if (#registries == 0) then
    return v_2fn(("No DevDocs entries match filetype `" .. filetype .. "`"), vim.log.levels.WARN)
  elseif (#registries == 1) then
    return _install_queue(registries)
  else
    local container = require("devdocs.application.ports.dependency_registry")
    local picker = container.picker()
    return picker.registries(_install_selected_registry, registries)
  end
end
M.install_browse = function()
  local container = require("devdocs.application.ports.dependency_registry")
  local picker = container.picker()
  local registries_usecase = require("devdocs.application.usecases.registries_usecase")
  local registries = (registries_usecase.list() or {})
  if (#registries == 0) then
    return v_2fn("No DevDocs documentation is available", vim.log.levels.WARN)
  else
    return picker.registries(_install_selected_registry, registries)
  end
end
M.install_all = function()
  local registries_usecase = require("devdocs.application.usecases.registries_usecase")
  local latest_registries = {}
  local queue = {}
  for _, registry in ipairs((registries_usecase.list() or {})) do
    local latest = latest_registries[registry.name]
    if (not latest or ((registry.mtime or 0) > (latest.mtime or 0))) then
      latest_registries[registry.name] = registry
    else
    end
  end
  for _, registry in pairs(latest_registries) do
    table.insert(queue, registry)
  end
  local function _44_(a, b)
    return (a.name < b.name)
  end
  table.sort(queue, _44_)
  if (#queue == 0) then
    return v_2fn("No DevDocs documentation is available", vim.log.levels.WARN)
  else
    return _install_queue(queue)
  end
end
local function _normalize_heading(text)
  local normalized = string.gsub(string.lower(text), "[^%w]+", "-")
  local without_prefix = string.gsub(normalized, "^%-+", "")
  return string.gsub(without_prefix, "%-+$", "")
end
local function _trigram_counts(text)
  local normalized = string.lower(text)
  local grams = {}
  local size = #normalized
  if (size == 0) then
    return {grams, 0}
  elseif (size < 3) then
    grams[normalized] = 1
    return {grams, 1}
  else
    local count = (size - 2)
    for index = 1, count do
      local gram = string.sub(normalized, index, (index + 2))
      grams[gram] = ((grams[gram] or 0) + 1)
    end
    return {grams, count}
  end
end
local function _trigram_similarity(left_grams, left_count, right)
  local _let_47_ = _trigram_counts(right)
  local right_grams = _let_47_[1]
  local right_count = _let_47_[2]
  if ((left_count == 0) or (right_count == 0)) then
    return 0
  else
    local shared
    do
      local total = 0
      for gram, count in pairs(left_grams) do
        total = (total + math.min(count, (right_grams[gram] or 0)))
      end
      shared = total
    end
    return ((2 * shared) / (left_count + right_count))
  end
end
local function _without_cursor_word(line, cursor_word)
  if (cursor_word == "") then
    return line
  else
    local context = string.gsub(line, vim.pesc(cursor_word), "", 1)
    return context
  end
end
local function _pattern_matches_any_3f(pattern, items)
  if (pattern == "") then
    return true
  else
    local Matcher = require("snacks.picker.core.matcher")
    local matcher = Matcher.new()
    matcher:init(pattern)
    local matches_3f = false
    for _, item in ipairs(items) do
      matches_3f = (matches_3f or (matcher:match(item) > 0))
    end
    return matches_3f
  end
end
local function _target_line(lines, entry)
  local path_parts = vim.split(entry.path, "#", {plain = true})
  local anchor = _normalize_heading((path_parts[2] or ""))
  local name = _normalize_heading(entry.name)
  local _51_
  do
    local target = nil
    for index, line in ipairs(lines) do
      if target then
        target = target
      else
        local heading_3f = vim.startswith(line, "#")
        local normalized = _normalize_heading(line)
        local anchor_match_3f = ((anchor ~= "") and string.find(normalized, anchor, 1, true))
        local name_match_3f = ((name ~= "") and string.find(normalized, name, 1, true))
        target = (heading_3f and (anchor_match_3f or name_match_3f) and index)
      end
    end
    _51_ = target
  end
  return (_51_ or 1)
end
local function _cached_document(repository, document_cache, lock_id, path)
  local cache_key = (lock_id .. ":" .. path)
  local or_53_ = document_cache[cache_key]
  if not or_53_ then
    local document = repository.find(lock_id, path)
    if document then
      local cached = {text = document, lines = vim.split(document, "\n", {plain = true})}
      document_cache[cache_key] = cached
      or_53_ = cached
    else
      or_53_ = nil
    end
  end
  return or_53_
end
local function _resolve_item(repository, document_cache, item)
  local path_parts = vim.split(item.entry.path, "#", {plain = true})
  local path = path_parts[1]
  local cached = _cached_document(repository, document_cache, item.lock.id, path)
  if cached then
    item.preview = {text = cached.text, ft = "markdown"}
    item.pos = {_target_line(cached.lines, item.entry), 0}
    return nil
  else
    return nil
  end
end
local function _heading_matches(repository, document_cache, items, pattern)
  local Matcher = require("snacks.picker.core.matcher")
  local matcher = Matcher.new()
  local seen = {}
  local matches = {}
  matcher:init(pattern)
  for _, source_item in ipairs(items) do
    local path_parts = vim.split(source_item.entry.path, "#", {plain = true})
    local path = path_parts[1]
    local cache_key = (source_item.lock.id .. ":" .. path)
    if not seen[cache_key] then
      seen[cache_key] = true
      local cached = _cached_document(repository, document_cache, source_item.lock.id, path)
      if cached then
        local in_fence_3f = false
        for _0, line in ipairs(cached.lines) do
          if (string.match(line, "^%s*```") or string.match(line, "^%s*~~~")) then
            in_fence_3f = not in_fence_3f
          elseif not in_fence_3f then
            local heading = string.match(line, "^#+%s+(.+)$")
            if heading then
              local without_suffix = string.gsub(heading, "%s+#+%s*$", "")
              local name = string.gsub(without_suffix, "`", "")
              local item = {idx = (#items + #matches + 1), text = string.format("[%s] %s \194\183 Heading", source_item.lock.name, name), entry = {name = name, path = path, type = "Heading"}, lock = source_item.lock}
              if (matcher:match(item) > 0) then
                local function _58_(resolved)
                  return _resolve_item(repository, document_cache, resolved)
                end
                item.resolve = _58_
                table.insert(matches, item)
              else
              end
            else
            end
          else
          end
        end
      else
      end
    else
    end
  end
  return matches
end
local function _preview(ctx)
  ctx.preview:reset()
  ctx.preview:set_lines(vim.split(ctx.item.preview.text, "\n", {plain = true}))
  do
    local buf = ctx.preview.win.buf
    local eventignore = vim.o.eventignore
    vim.o.eventignore = "all"
    vim.api.nvim_set_option_value("filetype", "markdown", {buf = buf})
    vim.o.eventignore = eventignore
    if not pcall(vim.treesitter.start, buf, "markdown") then
      vim.api.nvim_set_option_value("syntax", "markdown", {buf = buf})
    else
    end
  end
  return ctx.preview:loc()
end
local function _open_item(renderer, item)
  if item.resolve then
    item.resolve(item)
    item.resolve = nil
  else
  end
  if item.preview then
    v_2f_24("vsplit")
    renderer.create_scratch_buffer(vim.split(item.preview.text, "\n", {plain = true}), "markdown")
    local function _66_()
      vim.api.nvim_win_set_cursor(0, item.pos)
      return v_2f_24("normal! zz")
    end
    return v_2flater(_66_)
  else
    return nil
  end
end
local function _lookup(query)
  local container = require("devdocs.application.ports.dependency_registry")
  local entries_usecase = require("devdocs.application.usecases.entries_usecase")
  local registries_usecase = require("devdocs.application.usecases.registries_usecase")
  local repository = container.documentations_repository()
  local renderer = container.buffer()
  local locks_repository = container.locks_repository()
  local locks = (locks_repository.list() or {})
  local snacks = require("snacks")
  local registries_by_slug = {}
  local filetypes = _cursor_filetypes()
  local relevant_locks = {}
  local cursor_word = query
  local line_context = _without_cursor_word(vim.api.nvim_get_current_line(), cursor_word)
  local _let_68_ = _trigram_counts(line_context)
  local context_grams = _let_68_[1]
  local context_count = _let_68_[2]
  local items = {}
  local document_cache = {}
  for _, registry in ipairs((registries_usecase.list() or {})) do
    registries_by_slug[registry.slug] = registry
  end
  for _, lock in pairs(locks) do
    local registry = registries_by_slug[lock.id]
    if (registry and _registry_matches_filetypes_3f(registry, filetypes)) then
      table.insert(relevant_locks, lock)
    else
    end
  end
  for _, lock in ipairs(relevant_locks) do
    for _0, entry in ipairs((entries_usecase.find(lock.id) or {})) do
      local item = {idx = (#items + 1), text = string.format("[%s] %s \194\183 %s", lock.name, entry.name, (entry.type or "")), entry = entry, lock = lock}
      local function _70_(resolved)
        return _resolve_item(repository, document_cache, resolved)
      end
      item.resolve = _70_
      table.insert(items, item)
    end
  end
  local pattern_matches_3f = _pattern_matches_any_3f(cursor_word, items)
  if (not pattern_matches_3f and (cursor_word ~= "")) then
    local heading_items = _heading_matches(repository, document_cache, items, cursor_word)
    for _, item in ipairs(heading_items) do
      table.insert(items, item)
    end
    pattern_matches_3f = (#heading_items > 0)
  else
  end
  if (#items == 0) then
    return v_2fn("No DevDocs documentation is installed", vim.log.levels.WARN)
  elseif not pattern_matches_3f then
    return v_2fn(("No DevDocs entries or headings match `" .. cursor_word .. "`"), vim.log.levels.WARN)
  else
    local function _72_(_, item)
      local similarity = (item.line_similarity or _trigram_similarity(context_grams, context_count, item.text))
      item.line_similarity = similarity
      item.score = (item.score + (_line_similarity_weight * similarity))
      return nil
    end
    local function _73_(picker, item)
      picker:close()
      return _open_item(renderer, item)
    end
    return snacks.picker.pick({source = "select", title = "DevDocs", items = items, pattern = cursor_word, matcher = {sort_empty = true, on_match = _72_}, format = "text", preview = _preview, layout = {preset = "default"}, confirm = _73_})
  end
end
M.cursor_lookup = function()
  return _lookup(vim.fn.expand("<cword>"))
end
M.selection_lookup = function()
  local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), {type = vim.fn.mode()})
  local selection = vim.trim(table.concat(lines, " "))
  if (selection ~= "") then
    return _lookup(selection)
  else
    return nil
  end
end
return M
