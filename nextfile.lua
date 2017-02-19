local utils = require 'mp.utils'
local msg = require 'mp.msg'
local settings = {

    --filetypes,{'mp4','mkv'} for specific or {''} for all filetypes
    filetypes = {'mkv', 'avi', 'mp4', 'ogv', 'webm', 'rmvb', 'flv', 'wmv', 'mpeg', 'mpg', 'm4v', '3gp',
'mp3', 'wav', 'ogv', 'flac', 'm4a', 'wma', 'jpg', 'gif', 'png', 'jpeg', 'webp'}, 

    --linux(true)/windows(false)/auto(nil)
    linux_over_windows = nil,

    --at end of directory jump to start and vice versa
    allow_looping = true,

    --load next file automatically default value
    --recommended to keep as false and cycle with toggle or set with a script message
    --KEY script-message loadnextautomatically [true|false]
    --KEY script-binding toggleauto
    load_next_automatically = false,

    accepted_eof_reasons = {
        ['eof']=true,     --The file has ended. This can (but doesn't have to) include incomplete files or broken network connections under circumstances.
        ['stop']=true,    --Playback was ended by a command.
        ['quit']=false,    --Playback was ended by sending the quit command.
        ['error']=true,   --An error happened. In this case, an error field is present with the error string.
        ['redirect']=true,--Happens with playlists and similar. Details see MPV_END_FILE_REASON_REDIRECT in the C API.
        ['unknown']=true, --Unknown. Normally doesn't happen, unless the Lua API is out of sync with the C API.
    }
}
--check os
if settings.linux_over_windows==nil then
  local o = {}
  if mp.get_property_native('options/vo-mmcss-profile', o) ~= o then
    settings.linux_over_windows = false
  else
    settings.linux_over_windows = true
  end
end

local lock = true --to avoid infinite loops
function on_loaded()
    plen = mp.get_property_number('playlist-count')
    path = utils.join_path(mp.get_property('working-directory'), mp.get_property('path'))
    file = mp.get_property("filename")
    dir = utils.split_path(path)
    lock = true
end

function on_close(reason)
    if settings.accepted_eof_reasons[reason.reason] and settings.load_next_automatically and lock then
        msg.info("Loading next file in directory")
        mp.command("playlist-clear")
        lock = false
        nexthandler()
    end
end

function nexthandler()
    movetofile(true)
end

function prevhandler()
    movetofile(false)
end

function toggleauto()
    if not settings.load_next_automatically then
        settings.load_next_automatically = true
        if mp.get_property_number('playlist-count', 0) > 1 then
            mp.osd_message("Playlist will be purged when loading new file")
        else
            mp.osd_message("Loading next when file ends")
        end
    else
        settings.load_next_automatically = false
        mp.osd_message("Not loading next when file ends")
    end
end

function escapepath(dir, escapechar)
  return string.gsub(dir, escapechar, '\\'..escapechar)
end

function movetofile(forward)
    settings.load_next_automatically = false
    local search = ' '
    for w in pairs(settings.filetypes) do
        if settings.linux_over_windows then
            if settings.filetypes[w] ~= "" then settings.filetypes[w] = "*"..settings.filetypes[w] end
            search = search.."*"..settings.filetypes[w]..' '
        else
            search = search..'"'..escapepath(dir, '"').."*"..settings.filetypes[w]..'" '
        end
    end

    local popen, err = nil, nil
    if settings.linux_over_windows then
        popen, err = io.popen('cd "'..escapepath(dir, '"')..'";ls -1vp'..search..'2>/dev/null')
    else
        popen, err = io.popen('dir /b'..(search:gsub("/", "\\")))
    end
    if popen then
        local found = false
        local memory = nil
        local lastfile = true
        local firstfile = nil
        for dirx in popen:lines() do
            if found == true then
                mp.commandv("loadfile", dir..dirx, "replace")
                lastfile=false
                break
            end
            if dirx == file then
                found = true
                if not forward then
                    lastfile=false 
                    if settings.allow_looping and firstfile==nil then 
                        found=false
                    else
                        if firstfile==nil then break end
                        mp.commandv("loadfile", dir..memory, "replace")
                        break
                    end
                end
            end
            memory = dirx
            if firstfile==nil then firstfile=dirx end
        end
        if lastfile and firstfile and settings.allow_looping then
            mp.commandv("loadfile", dir..firstfile, "replace")
        end
        if not found and memory then
            mp.commandv("loadfile", dir..memory, "replace")
        end
        popen:close()
    else
        msg.error("could not scan for files: "..(err or ""))
    end
    settings.load_next_automatically = load_memory
end

--read settings from a script message
function loadnext(msg, value)
  if msg == "next" then nexthandler() ; return end
  if msg == "previous" then prevhandler() ; return end
  if msg == "auto" then
    if value == "toggle" then toggleauto() ; return end
    toggleauto(value:lower() == 'true' )
  end
end

mp.register_script_message("nextfile", loadnext)
mp.add_key_binding('SHIFT+PGDWN', 'nextfile', nexthandler)
mp.add_key_binding('SHIFT+PGUP', 'previousfile', prevhandler)
mp.add_key_binding('CTRL+N', 'autonextfiletoggle', toggleauto)
mp.register_event('file-loaded', on_loaded)
mp.register_event('end-file', on_close)
