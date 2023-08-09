local utils = require 'mp.utils'
local msg = require 'mp.msg'
local settings = {

  filetypes = {
    'jpg', 'jpeg', 'png', 'tif', 'tiff', 'gif', 'webp', 'svg', 'bmp',
    'mp3', 'wav', 'ogm', 'flac', 'm4a', 'wma', 'ogg', 'opus',
    'mkv', 'avi', 'mp4', 'ogv', 'webm', 'rmvb', 'flv', 'wmv', 'mpeg', 'mpg', 'm4v', '3gp'
  },

  --linux(true)/windows(false)/auto(nil)
  linux_over_windows = nil,

  --at end of directory jump to start and vice versa
  allow_looping = true,
  
  --order by natural (version) numbers, thus behaving case-insensitively and treating multi-digit numbers atomically
  --e.x.: true will result in the following order:   09A 9A  09a 9a  10A 10a
  --      while false will result in:                09a 09A 10a 10A 9a  9A
  version_flag = true,
}

local filetype_lookup = {}
for _, ext in ipairs(settings.filetypes) do
  filetype_lookup[ext] = true
end

--check os
if settings.linux_over_windows==nil then
  local o = {}
  if mp.get_property_native('options/vo-mmcss-profile', o) ~= o then
    settings.linux_over_windows = false
  else
    settings.linux_over_windows = true
  end
end

function show_osd_message(file)
    mp.osd_message("Now playing: " .. file, 3)  -- Adjust OSD display time as needed
end

function nexthandler()
  movetofile(true)
end

function prevhandler()
  movetofile(false)
end

function get_files_windows(dir)
  local args = {
    'powershell', '-NoProfile', '-Command', [[& {
          Trap {
              Write-Error -ErrorRecord $_
              Exit 1
          }
          $path = "]]..dir..[["
          $escapedPath = [WildcardPattern]::Escape($path)
          cd $escapedPath
    
          $list = (Get-ChildItem -File | Sort-Object { [regex]::Replace($_.Name, '\d+', { $args[0].Value.PadLeft(20) }) }).Name
          $string = ($list -join "/")
          $u8list = [System.Text.Encoding]::UTF8.GetBytes($string)
          [Console]::OpenStandardOutput().Write($u8list, 0, $u8list.Length)
      }]]
  }
  local process = utils.subprocess({ args = args, cancellable = false })
  return parse_files(process, '%/')
end

function get_files_linux(dir)
  local flags = ('-1p' .. (settings.version_flag and 'v' or ''))
  local args = { 'ls', flags, dir }
  local process = utils.subprocess({ args = args, cancellable = false })
  return parse_files(process, '\n')
end

function parse_files(res, delimiter)
  if not res.error and res.status == 0 then
    local valid_files = {}
    for line in res.stdout:gmatch("[^"..delimiter.."]+") do
      local ext = line:match("^.+%.(.+)$")
      if ext and filetype_lookup[ext:lower()] then
        table.insert(valid_files, line)
      end
    end
    return valid_files, nil
  else
    return nil, res.error
  end
end

function movetofile(forward)
  if mp.get_property('filename'):match("^%a%a+:%/%/") then return end
  local pwd = mp.get_property('working-directory')
  local relpath = mp.get_property('path')
  if not pwd or not relpath then return end

  local path = utils.join_path(pwd, relpath)
  local filename = mp.get_property("filename")
  local dir = utils.split_path(path)

  local files, error
  if settings.linux_over_windows then
    files, error = get_files_linux(dir)
  else
    files, error = get_files_windows(dir)
  end

  if not files then
    msg.error("Subprocess failed: "..(error or ''))
    return
  end

  local found = false
  local memory = nil
  local lastfile = true
  local firstfile = nil
  for _, file in ipairs(files) do
    if found == true then
      mp.commandv("loadfile", utils.join_path(dir, file), "replace")
      lastfile = false
      show_osd_message(file)
      break
    end
    if file == filename then
      found = true
      if not forward then
        lastfile = false
        if settings.allow_looping and firstfile == nil then
          found = false
        else
          if firstfile == nil then break end
          mp.commandv("loadfile", utils.join_path(dir, memory), "replace")
          show_osd_message(memory)
          break
        end
      end
    end
    memory = file
    if firstfile == nil then firstfile = file end
  end
  if lastfile and firstfile and settings.allow_looping then
    mp.commandv("loadfile", utils.join_path(dir, firstfile), "replace")
    show_osd_message(firstfile)
  end
  if not found and memory then
    mp.commandv("loadfile", utils.join_path(dir, memory), "replace")
    show_osd_message(memory)
  end
end

mp.add_key_binding('Shift+RIGHT', 'nextfile', nexthandler)
mp.add_key_binding('Shift+LEFT', 'previousfile', prevhandler)
