-- [nfnl] fnl/lib/plugin-loader.fnl
local M = {}
local function table_3f(value)
  return (type(value) == "table")
end
local function empty_table_3f(value)
  return (table_3f(value) and (next(value) == nil))
end
local function lazy_spec_3f(value)
  return (table_3f(value) and ((type(value[1]) == "string") or (type(value.dir) == "string") or (type(value.import) == "string") or (type(value.url) == "string")))
end
local function lazy_spec_list_3f(value)
  if (table_3f(value) and not lazy_spec_3f(value)) then
    local found = false
    local valid = true
    for _, item in ipairs(value) do
      found = true
      if not lazy_spec_3f(item) then
        valid = false
      else
      end
    end
    return (found and valid)
  else
    return nil
  end
end
local function skipped_name_3f(name)
  return ((name == "index.fnl") or vim.startswith(name, "_"))
end
local function fnl_file_3f(name)
  return vim.endswith(name, ".fnl")
end
local function walk_plugin_files(dir, prefix, files)
  for name, kind in vim.fs.dir(dir) do
    local full_path = vim.fs.joinpath(dir, name)
    local relpath
    if (prefix == "") then
      relpath = name
    else
      relpath = vim.fs.joinpath(prefix, name)
    end
    if (kind == "directory") then
      if not skipped_name_3f(name) then
        walk_plugin_files(full_path, relpath, files)
      else
      end
    else
      if ((kind == "file") and fnl_file_3f(name) and not skipped_name_3f(name)) then
        table.insert(files, relpath)
      else
      end
    end
  end
  return nil
end
local function collect_plugin_files(root)
  local files = {}
  walk_plugin_files(root, "", files)
  table.sort(files)
  return files
end
local function module_name(relpath)
  local stem = relpath:gsub("%.fnl$", "")
  local dotted = stem:gsub("/", ".")
  return ("plugins." .. dotted)
end
local function add_plugin_module(plugins, module_name0, exported)
  if lazy_spec_3f(exported) then
    return table.insert(plugins, exported)
  elseif lazy_spec_list_3f(exported) then
    for _, spec in ipairs(exported) do
      table.insert(plugins, spec)
    end
    return nil
  elseif ((nil == exported) or (false == exported) or (true == exported) or empty_table_3f(exported)) then
    return nil
  else
    return vim.notify(("Ignoring non-plugin module " .. module_name0), vim.log.levels.WARN)
  end
end
M.load = function(_3fopts)
  local opts = (_3fopts or {})
  local root = (opts.root or vim.fs.joinpath(vim.fn.stdpath("config"), "fnl", "plugins"))
  local uv = (vim.uv or vim.loop)
  local plugins = {}
  if uv.fs_stat(root) then
    for _, relpath in ipairs(collect_plugin_files(root)) do
      local module = module_name(relpath)
      local exported = require(module)
      add_plugin_module(plugins, module, exported)
    end
  else
  end
  return plugins
end
return M
