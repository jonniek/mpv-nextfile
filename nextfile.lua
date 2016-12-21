local settings = {

    --filetypes,{'*mp4','*mkv'} for specific or {'*'} for all filetypes
    filetypes = {'*mkv','*mp4','*jpg','*gif','*png'}, 

    --linux(true)/windows(false)
    linux_over_windows = true,

    --at end of directory jump to start and vice versa
    allow_looping = true

}

function on_loaded()
    path = string.sub(mp.get_property("path"), 1, string.len(mp.get_property("path"))-string.len(mp.get_property("filename")))
    file = mp.get_property("filename")
end

function nexthandler()
	movetofile(true)
end

function prevhandler()
	movetofile(false)
end


function movetofile(forward)
	local search = ' '
    for w in pairs(settings.filetypes) do
        if settings.linux_over_windows then
			search = search..string.gsub(path, "%s+", "\\ ")..settings.filetypes[w]..' '
        else
            search = search..'"'..path..settings.filetypes[w]..'" '
        end
    end

    local popen=nil
    if settings.linux_over_windows then
        popen = io.popen('find '..search..' -maxdepth 1 -type f -printf "%f\\n" 2>/dev/null | sort -f')
    else
        popen = io.popen('dir /b '..search) 
    end
    if popen then 
        local found = false
        local memory = nil
        local lastfile = true
        local firstfile = nil
        for dirx in popen:lines() do
            if found == true then
                mp.commandv("loadfile", path..dirx, "replace")
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
            			mp.commandv("loadfile", path..memory, "replace")
                		break
                	end
               	end
            end
            memory = dirx
        	if firstfile==nil then firstfile=dirx end
        end
        if lastfile and settings.allow_looping then
            mp.commandv("loadfile", path..firstfile, "replace")
        end
        if not found then
            mp.commandv("loadfile", path..memory, "replace")
        end

        popen:close()
    else
        print("error: could not scan for files")
    end
end


mp.add_key_binding('SHIFT+PGDWN', 'nextfile', nexthandler)
mp.add_key_binding('SHIFT+PGUP', 'previousfile', prevhandler)
mp.register_event('file-loaded', on_loaded)
