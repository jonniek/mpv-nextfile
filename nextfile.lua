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

function alphanumsort(o)
  local function padnum(d) local dec, n = string.match(d, "(%.?)0*(.+)")
    return #dec > 0 and ("%.12f"):format(d) or ("%s%03d%s"):format(dec, #n, n) end
  table.sort(o, function(a,b)
    return tostring(a):gsub("%.?%d+",padnum)..("%3d"):format(#b)
         < tostring(b):gsub("%.?%d+",padnum)..("%3d"):format(#a) end)
  return o
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
  local args = { 'find', dir, '-type', 'f', '-printf', '%f/' }
  local process = utils.subprocess({ args = args, cancellable = false })
  return parse_files(process, '/')
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
    alphanumsort(files)
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
          break
        end
      end
    end
    memory = file
    if firstfile == nil then firstfile = file end
  end
  if lastfile and firstfile and settings.allow_looping then
    mp.commandv("loadfile", utils.join_path(dir, firstfile), "replace")
  end
  if not found and memory then
    mp.commandv("loadfile", utils.join_path(dir, memory), "replace")
  end
end

mp.add_key_binding('Shift+RIGHT', 'nextfile', nexthandler)
mp.add_key_binding('Shift+LEFT', 'previousfile', prevhandler)
