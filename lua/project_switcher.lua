local M = {}

local defs = {
  -- Dict from string project name to table of string paths
  -- Paths can be absolute, or relative.
  -- When relative, paths are attempted to be appended to be added
  -- to `relative_path_prefixes`.
  projects = {},
  -- No regex allowed
  common_project_roots = {},
  -- Can contain a regex. Example:
  -- '/home/[^/]+/work/'
  relative_path_prefixes = {},
}

local function cleanup_defs()
  -- Cleanup defs.projects paths
  for proj_name, paths in pairs(defs.projects) do
    for idx, proj_path in ipairs(paths) do
      defs.projects[proj_name][idx] = vim.fn.expand(proj_path)
    end
  end

  -- Cleanup defs.common_project_roots
  for idx, proj_path in ipairs(defs.common_project_roots) do
    defs.common_project_roots[idx] = vim.fn.expand(proj_path)
  end
end

local function tester(path)
  print(
    'Path ' .. path .. ' project paths are ',
    vim.inspect(M.get_project_paths(path))
  )
end

M.setup = function(opts)
  print('calling setup with ' .. vim.inspect(opts))

  local status, project_defs = pcall(require, 'project_defs')
  if not status then
    print('Could not get defs')
    return
  end

  defs = project_defs
  print('did find defs ' .. vim.inspect(project_defs))

  cleanup_defs()

  print('clean defs are ' .. vim.inspect(defs))

  tester('~/work/mdbook-i18n-helpers/i18n-helpers/src/lib.rs')
  tester('~/work/mdbook-i18n-helpers')
end

local function is_absolute_path(path)
  return string.sub(path, 1, 1) == '/'
end

local function has_absolute_paths(paths)
  for _, path in ipairs(paths) do
    if is_absolute_path(path) then
      return true
    end
  end
  return false
end

local function find_path(path)
  if path then
    path = vim.fn.expand(path)

    if vim.fn.isdirectory(path) and path:sub(path:len()) ~= '/' then
      path = path .. '/'
    end

    return path
  end

  local cur_buf = vim.fn.expand('%:p')
  if cur_buf:len() > 0 and cur_buf:sub(1, 1) == '/' then
    return cur_buf
  end

  local cwd = vim.fn.getcwd()
  if cwd ~= vim.fn.expand('~') then
    return cwd .. '/'
  end
  return ''
end

M.get_project_from_path = function(path)
  path = find_path(path)


  for proj_name, paths in pairs(defs.projects) do
    for _, proj_path in ipairs(paths) do
      if is_absolute_path(proj_path) then
        if
          proj_path:len() >= path:len()
          and string.sub(path, 1, proj_path:len()) == proj_path
        then
          return proj_name, nil, false
        end
      else
        for _, prefix in ipairs(defs.relative_path_prefixes) do
          local i, j = string.find(path, prefix)
          if i ~= nil then
            local rest = string.sub(path, j + 1)

            if
              rest:len() >= proj_path:len()
              and string.sub(rest, 1, proj_path:len()) == proj_path
            then
              return proj_name, string.sub(path, 1, j), false
            end
          end
        end
      end
    end
  end

  for _, common_root in ipairs(defs.common_project_roots) do
    if
      path:len() >= common_root:len()
      and string.sub(path, 1, common_root:len()) == common_root
    then
      local rest = string.sub(path, common_root:len() + 1)
      return string.sub(rest, string.find(rest, '/')), common_root, true
    end
  end

  return nil, nil, nil
end

M.get_project_paths = function(path)
  local project, prefix, from_common_root = M.get_project_from_path(path)

  -- Project not found
  if project == nil then
    error('No project found for', path)
    return
  end

  -- Common root project
  if from_common_root then
    return {
      prefix .. project,
    }
  end

  local result = {}

  for _, proj_path in ipairs(defs.projects[project]) do
    if is_absolute_path(proj_path) then
      table.insert(result, proj_path)
    else
      table.insert(result, prefix .. proj_path)
    end
  end

  return result
end

M.list_projects = function()
  local path = find_path()

  return {}
end

return M
