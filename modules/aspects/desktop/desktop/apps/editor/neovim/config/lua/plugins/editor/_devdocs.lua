-- [nfnl] fnl/plugins/editor/_devdocs.fnl
local _local_1_ = require("lib/nvim")
local v_2f_24 = _local_1_["v/$"]
local v_2fn = _local_1_["v/n"]
local v_2flater = _local_1_["v/later"]
local M = {}
local _filetype_aliases = {fennel = "lua", javascriptreact = "javascript", sh = "bash", typescriptreact = "typescript"}
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
      local case_7_ = row.status
      if (case_7_ == "active") then
        marker = (spinner_text or _progress_inactive)
      elseif (case_7_ == "done") then
        marker = _progress_complete
      elseif (case_7_ == "failed") then
        marker = _progress_inactive
      else
        local _0 = case_7_
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
        local case_9_ = row.status
        if (case_9_ == "done") then
          hl_group = "DiagnosticOk"
        elseif (case_9_ == "failed") then
          hl_group = "DiagnosticError"
        else
          local _ = case_9_
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
      local function _17_()
        return _close_progress(progress)
      end
      vim.keymap.set("n", key, _17_, {buffer = buf, nowait = true, silent = true})
    end
    do
      local spinner = require("spinner")
      local function _18_(event)
        return _render_progress(progress, event.text)
      end
      spinner.config(_spinner_id, {kind = "custom", pattern = "aesthetic", placeholder = _progress_inactive, ui_scope = _spinner_id, on_update_ui = _18_})
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
    local function _20_()
      if ((_active_progress == progress) and not progress.running) then
        _close_progress(progress)
        _active_progress = nil
        return nil
      else
        return nil
      end
    end
    return vim.defer_fn(_20_, 1500)
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
  local function _23_(result)
    if (result.code ~= 0) then
      local error_text = vim.trim((result.stderr or ""))
      local _24_
      if (error_text == "") then
        _24_ = ""
      else
        _24_ = (": " .. error_text)
      end
      v_2fn(("Failed to install " .. registry.name .. " documentation" .. _24_), vim.log.levels.ERROR)
      return on_done(false)
    else
      local function _26_()
        locks_repository.save({id = registry.slug, name = registry.name})
        return on_done(true)
      end
      return entries_usecase.install_async(registry.slug, _26_)
    end
  end
  return vim.system({"python3", installer, url, destination}, {text = true}, vim.schedule_wrap(_23_))
end
local function _install_queue(registries)
  local progress = _open_progress(registries)
  if progress then
    local spinner = require("spinner")
    local next_index = 1
    local active = 0
    local completed = 0
    local start_available = nil
    local function _28_()
      while ((active < _download_worker_count) and (next_index <= #registries)) do
        local index = next_index
        local row = progress.rows[index]
        next_index = (next_index + 1)
        active = (active + 1)
        row.status = "active"
        _focus_progress_line(progress, (index + 2))
        local function _29_(success)
          if success then
            row.status = "done"
          else
            row.status = "failed"
          end
          if not success then
            progress.failed = (progress.failed + 1)
          else
          end
          local function _32_()
            collectgarbage("collect")
            active = (active - 1)
            completed = (completed + 1)
            if (completed == #registries) then
              return _finish_progress(progress)
            else
              return start_available()
            end
          end
          return vim.schedule(_32_)
        end
        _install_registry(row.registry, _29_)
      end
      return _render_progress(progress, spinner.render(_spinner_id))
    end
    start_available = _28_
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
  local function _38_(a, b)
    return (a.name < b.name)
  end
  table.sort(queue, _38_)
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
  local _let_41_ = _trigram_counts(right)
  local right_grams = _let_41_[1]
  local right_count = _let_41_[2]
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
local function _target_line(lines, entry)
  local path_parts = vim.split(entry.path, "#", {plain = true})
  local anchor = _normalize_heading((path_parts[2] or ""))
  local name = _normalize_heading(entry.name)
  local _44_
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
    _44_ = target
  end
  return (_44_ or 1)
end
local function _resolve_item(repository, document_cache, item)
  local path_parts = vim.split(item.entry.path, "#", {plain = true})
  local path = path_parts[1]
  local cache_key = (item.lock.id .. ":" .. path)
  local cached
  local or_46_ = document_cache[cache_key]
  if not or_46_ then
    local document = repository.find(item.lock.id, path)
    if document then
      local value = {text = document, lines = vim.split(document, "\n", {plain = true})}
      document_cache[cache_key] = value
      or_46_ = value
    else
      or_46_ = nil
    end
  end
  cached = or_46_
  if cached then
    item.preview = {text = cached.text, ft = "markdown"}
    item.pos = {_target_line(cached.lines, item.entry), 0}
    return nil
  else
    return nil
  end
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
    local function _53_()
      vim.api.nvim_win_set_cursor(0, item.pos)
      return v_2f_24("normal! zz")
    end
    return v_2flater(_53_)
  else
    return nil
  end
end
M.cursor_lookup = function()
  local container = require("devdocs.application.ports.dependency_registry")
  local entries_usecase = require("devdocs.application.usecases.entries_usecase")
  local registries_usecase = require("devdocs.application.usecases.registries_usecase")
  local repository = container.documentations_repository()
  local renderer = container.buffer()
  local locks_repository = container.locks_repository()
  local locks = (locks_repository.list() or {})
  local snacks = require("snacks")
  local registries_by_slug = {}
  local relevant_locks = {}
  local all_locks = {}
  local filetype = vim.bo.filetype
  local cursor_word = vim.fn.expand("<cWORD>")
  local line_context = _without_cursor_word(vim.api.nvim_get_current_line(), cursor_word)
  local _let_55_ = _trigram_counts(line_context)
  local context_grams = _let_55_[1]
  local context_count = _let_55_[2]
  local items = {}
  local document_cache = {}
  for _, registry in ipairs((registries_usecase.list() or {})) do
    registries_by_slug[registry.slug] = registry
  end
  for _, lock in pairs(locks) do
    table.insert(all_locks, lock)
    local registry = registries_by_slug[lock.id]
    if (registry and _registry_matches_filetype_3f(registry, filetype)) then
      table.insert(relevant_locks, lock)
    else
    end
  end
  local function _57_()
    if (#relevant_locks > 0) then
      return relevant_locks
    else
      return all_locks
    end
  end
  for _, lock in ipairs(_57_()) do
    for _0, entry in ipairs((entries_usecase.find(lock.id) or {})) do
      local item = {idx = (#items + 1), text = string.format("[%s] %s \194\183 %s", lock.name, entry.name, (entry.type or "")), entry = entry, lock = lock}
      local function _58_(resolved)
        return _resolve_item(repository, document_cache, resolved)
      end
      item.resolve = _58_
      table.insert(items, item)
    end
  end
  if (#items == 0) then
    return v_2fn("No DevDocs documentation is installed", vim.log.levels.WARN)
  else
    local function _59_(_, item)
      local similarity = (item.line_similarity or _trigram_similarity(context_grams, context_count, item.text))
      item.line_similarity = similarity
      item.score = (item.score + (_line_similarity_weight * similarity))
      return nil
    end
    local function _60_(picker, item)
      picker:close()
      return _open_item(renderer, item)
    end
    return snacks.picker.pick({source = "select", title = "DevDocs", items = items, pattern = cursor_word, matcher = {on_match = _59_}, format = "text", preview = _preview, layout = {preset = "default"}, confirm = _60_})
  end
end
return M
