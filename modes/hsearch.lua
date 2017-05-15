hsearch_loaded = true
if youdaokeyfrom == nil then youdaokeyfrom = 'hsearch' end
if youdaoapikey == nil then youdaoapikey = '1199732752' end
chooserSourceTable = {}
chooserSourceOverview = {}

function switchSource()
    function isInKeywords(value, tbl)
        for i=1,#tbl do
            if tbl[i].kw == value then
                sourcetable_index = i
                return true
            end
        end
        return false
    end
    local querystr = search_chooser:query()
    if string.len(querystr) > 0 then
        local matchstr = string.match(querystr,"^%w+")
        if matchstr == querystr then
            if isInKeywords(querystr, chooserSourceTable) then
                search_chooser:query('')
                chooser_data = {}
                search_chooser:choices(chooser_data)
                search_chooser:queryChangedCallback()
                chooserSourceTable[sourcetable_index].func()
            else
                chooser_data = {}
                local source_desc = {text="No source found!", subText="Maybe misspelled the keyword?"}
                table.insert(chooser_data, 1, source_desc)
                local more_tips = {text="Want to add your own source?", subText="Feel free to read the code and open PRs. :)"}
                table.insert(chooser_data, 2, more_tips)
                search_chooser:choices(chooser_data)
                search_chooser:queryChangedCallback()
            end
        else
            chooser_data = {}
            local source_desc = {text="Invalid Keyword", subText="Trigger keyword must only consist of alphanumeric characters."}
            table.insert(chooser_data, 1, source_desc)
            search_chooser:choices(chooser_data)
            search_chooser:queryChangedCallback()
        end
    else
        if hs_emoji_data then hs_emoji_data:close() hs_emoji_data = nil end
        chooser_data = chooserSourceOverview
        search_chooser:choices(chooser_data)
        search_chooser:queryChangedCallback()
    end
end

function launchChooser()
    if sourcetrigger == nil then
        sourcetrigger = hs.hotkey.bind("","tab",nil,switchSource)
    else
        sourcetrigger:enable()
    end
    if search_chooser == nil then
        chooser_data = {}
        search_chooser = hs.chooser.new(function(chosen)
            sourcetrigger:disable()
            if chosen ~= nil then
                if chosen.outputType == "safari" then
                    hs.urlevent.openURLWithBundle(chosen.url,"com.apple.Safari")
                elseif chosen.outputType == "chrome" then
                    hs.urlevent.openURLWithBundle(chosen.url,"com.google.Chrome")
                elseif chosen.outputType == "firefox" then
                    hs.urlevent.openURLWithBundle(chosen.url,"org.mozilla.firefox")
                elseif chosen.outputType == "browser" then
                    local defaultbrowser = hs.urlevent.getDefaultHandler('http')
                    hs.urlevent.openURLWithBundle(chosen.url,defaultbrowser)
                elseif chosen.outputType == "clipboard" then
                    hs.pasteboard.setContents(chosen.clipText)
                elseif chosen.outputType == "keystrokes" then
                    hs.window.orderedWindows()[1]:focus()
                    hs.eventtap.keyStrokes(chosen.typingText)
                elseif chosen.outputType == "taskkill" then
                    os.execute("kill -9 "..chosen.pid)
                elseif chosen.outputType == "menuclick" then
                    hs_belongto_app:activate()
                    hs_belongto_app:selectMenuItem(chosen.menuitem)
                end
            end
        end)
        search_chooser:query('')
        search_chooser:queryChangedCallback()
        chooser_data = chooserSourceOverview
        search_chooser:choices(chooser_data)
        search_chooser:rows(9)
    end
    search_chooser:show()
end

function safariTabsRequest()
    local stat, data= hs.osascript.applescript('tell application "Safari"\nset winlist to tabs of windows\nset tablist to {}\nrepeat with i in winlist\nif (count of i) > 0 then\nrepeat with currenttab in i\nset tabinfo to {name of currenttab as unicode text, URL of currenttab}\ncopy tabinfo to the end of tablist\nend repeat\nend if\nend repeat\nreturn tablist\nend tell')
    if stat then
        chooser_data = hs.fnutils.imap(data, function(item)
            return {text = item[1],subText = item[2], image=hs.image.imageFromPath("./resources/safari.png"), outputType = "safari", url=item[2]}
        end)
    end
end

function safariSource()
    local safarisource_overview = {text="Type sa<tab> to search Safari Tabs.", image=hs.image.imageFromPath("./resources/safari.png")}
    table.insert(chooserSourceOverview,safarisource_overview)
    function safariFunc()
        local source_desc = {text="Requesting data, please wait a while …"}
        table.insert(chooser_data, 1, source_desc)
        search_chooser:choices(chooser_data)
        safariTabsRequest()
        local source_desc = {text="Safari Tabs Search", subText="Search and select one item below to open in Safari.", image=hs.image.imageFromPath("./resources/safari.png")}
        table.insert(chooser_data, 1, source_desc)
        search_chooser:choices(chooser_data)
        search_chooser:queryChangedCallback()
        search_chooser:searchSubText(true)
    end
    local sourcepkg = {}
    sourcepkg.kw = "sa"
    sourcepkg.func = safariFunc
    table.insert(chooserSourceTable,sourcepkg)
end

safariSource()

function youdaoInstantTrans(querystr)
    local youdao_baseurl = 'http://fanyi.youdao.com/openapi.do?keyfrom='..youdaokeyfrom..'&key='..youdaoapikey..'&type=data&doctype=json&version=1.1&q='
    if string.len(querystr) > 0 then
        local encoded_query = hs.http.encodeForQuery(querystr)
        local query_url = youdao_baseurl..encoded_query

        hs.http.asyncGet(query_url,nil,function(status,data)
            if status == 200 then
                if pcall(function() hs.json.decode(data) end) then
                    local decoded_data = hs.json.decode(data)
                    if decoded_data.errorCode == 0 then
                        if decoded_data.basic then
                            basictrans = decoded_data.basic.explains
                        else
                            basictrans = {}
                        end
                        if decoded_data.web then
                            webtrans = hs.fnutils.imap(decoded_data.web,function(item) return item.key..' '..table.concat(item.value,',') end)
                        else
                            webtrans = {}
                        end
                        dictpool = hs.fnutils.concat(basictrans,webtrans)
                        if #dictpool > 0 then
                            chooser_data = hs.fnutils.imap(dictpool, function(item)
                                return {text=item, image=hs.image.imageFromPath("./resources/youdao.png"), outputType="clipboard", clipText=item}
                            end)
                            search_chooser:choices(chooser_data)
                            search_chooser:refreshChoicesCallback()
                        end
                    end
                end
            end
        end)
    else
        chooser_data = {}
        local source_desc = {text="Youdao Dictionary", subText="Type something to get it translated …", image=hs.image.imageFromPath("./resources/youdao.png")}
        table.insert(chooser_data, 1, source_desc)
        search_chooser:choices(chooser_data)
    end
end

function youdaoSource()
    local youdaosource_overview = {text="Type yd<tab> to use Yaodao Dictionary.", image=hs.image.imageFromPath("./resources/youdao.png")}
    table.insert(chooserSourceOverview,youdaosource_overview)
    function youdaoFunc()
        local source_desc = {text="Youdao Dictionary", subText="Type something to get it translated …", image=hs.image.imageFromPath("./resources/youdao.png")}
        table.insert(chooser_data, 1, source_desc)
        search_chooser:choices(chooser_data)
        search_chooser:queryChangedCallback(youdaoInstantTrans)
    end
    local sourcepkg = {}
    sourcepkg.kw = "yd"
    sourcepkg.func = youdaoFunc
    table.insert(chooserSourceTable,sourcepkg)
end

youdaoSource()

--------------------------------------------------------------------------------
-- Add a new source - kill processes
-- First request processes info and store them into $chooser_data$

local function splitByLine(str)
    local tailtrimmedstr = string.gsub(str,"%s+$","")
    local tmptbl = {}
    for w in string.gmatch(tailtrimmedstr,"[^\n]+") do table.insert(tmptbl,w) end
    if #tmptbl == 1 then
        local trimmedstr = string.gsub(tmptbl[1],"%s","")
        return trimmedstr
    else
        local tmptbl2 = {}
        for _,val in pairs(tmptbl) do
            local trimmedstr = string.gsub(val,"%s","")
            table.insert(tmptbl2,trimmedstr)
        end
        return tmptbl2
    end
end

function appsInfoRequest()
    local taskname_tbl = splitByLine(hs.execute("ps -ero ucomm"))
    local pid_tbl = splitByLine(hs.execute("ps -ero pid"))
    local comm_tbl = splitByLine(hs.execute("ps -ero command"))
    for i=2,#taskname_tbl do
        local taskname = taskname_tbl[i]
        local pid = tonumber(pid_tbl[i])
        local comm = comm_tbl[i]
        local appbundle = hs.application.applicationForPID(pid)
        local function getBundleID()
            if appbundle then
                return appbundle:bundleID()
            end
        end
        local bundleid = getBundleID() or "nil"
        local function getAppImage()
            if bundleid ~= "nil" then
                return hs.image.imageFromAppBundle(bundleid)
            else
                return hs.image.iconForFileType("public.unix-executable")
            end
        end
        local appimage = getAppImage()
        local appinfoitem = {text=taskname.."#"..pid.."  "..bundleid, subText=comm, image=appimage, outputType="taskkill", pid=pid}
        table.insert(chooser_data,appinfoitem)
    end
end

-- Then we wrap the worker into appkillSource

function appKillSource()
    -- Give some tips for this source
    local appkillsource_overview = {text="Type kl<tab> to Kill running Process.", image=hs.image.imageFromPath("./resources/taskkill.png")}
    table.insert(chooserSourceOverview,appkillsource_overview)
    -- Run the function below when triggered.
    function appkillFunc()
        -- Request appsinfo
        appsInfoRequest()
        -- More tips
        local source_desc = {text="Kill Processes", subText="Search and select some items to get them killed.", image=hs.image.imageFromPath("./resources/taskkill.png")}
        table.insert(chooser_data, 1, source_desc)
        -- Make $chooser_data$ appear in search_chooser
        search_chooser:choices(chooser_data)
        -- Run some code or do nothing while querystring changed
        search_chooser:queryChangedCallback()
        -- Do something when select one item in search_chooser
    end
    local sourcepkg = {}
    -- Give this source a trigger keyword
    sourcepkg.kw = "kl"
    sourcepkg.func = appkillFunc
    -- Add this source to SourceTable
    table.insert(chooserSourceTable,sourcepkg)
end

-- Run the function once, so search_chooser can actually see the new source
appKillSource()

-- New source - kill processes End here
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- New source - Datamuse thesaurus

function thesaurusRequest(querystr)
    local datamuse_baseurl = 'http://api.datamuse.com'
    if string.len(querystr) > 0 then
        local encoded_query = hs.http.encodeForQuery(querystr)
        local query_url = datamuse_baseurl..'/words?ml='..encoded_query..'&max=20'

        hs.http.asyncGet(query_url,nil,function(status,data)
            if status == 200 then
                if pcall(function() hs.json.decode(data) end) then
                    local decoded_data = hs.json.decode(data)
                    if #decoded_data > 0 then
                        chooser_data = hs.fnutils.imap(decoded_data, function(item)
                            return {text = item.word, image=hs.image.imageFromPath("./resources/thesaurus.png"), outputType="keystrokes", typingText=item.word}
                        end)
                        search_chooser:choices(chooser_data)
                        search_chooser:refreshChoicesCallback()
                    end
                end
            end
        end)
    else
        chooser_data = {}
        local source_desc = {text="Datamuse Thesaurus", subText="Type something to get more words like it …", image=hs.image.imageFromPath("./resources/thesaurus.png")}
        table.insert(chooser_data, 1, source_desc)
        search_chooser:choices(chooser_data)
    end
end

function thesaurusSource()
  local thesaurus_overview = {text="Type th<tab> to find English Thesaurus.", image=hs.image.imageFromPath("./resources/thesaurus.png")}
    table.insert(chooserSourceOverview,thesaurus_overview)
    function thesaurusFunc()
      local source_desc = {text="Datamuse Thesaurus", subText="Type something to get more words like it …", image=hs.image.imageFromPath("./resources/thesaurus.png")}
        table.insert(chooser_data, 1, source_desc)
        search_chooser:choices(chooser_data)
        search_chooser:queryChangedCallback(thesaurusRequest)
    end
    local sourcepkg = {}
    sourcepkg.kw = "th"
    sourcepkg.func = thesaurusFunc
    -- Add this source to SourceTable
    table.insert(chooserSourceTable,sourcepkg)
end

thesaurusSource()

-- New source - Datamuse Thesaurus End here
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- New source - Menuitems Search

function table.clone(org)
    return {table.unpack(org)}
end

function getMenuChain(t)
    for pos,val in pairs(t) do
        if type(val) == "table" then
            if type(val.AXChildren) == "table" then
                hs_currentlevel = hs_currentlevel + 1
                hs_currententry[hs_currentlevel] = val.AXTitle
                getMenuChain(val.AXChildren[1])
                hs_currentlevel = hs_currentlevel - 1
                for i=hs_currentlevel+1,#hs_currententry do
                    table.remove(hs_currententry,i)
                end
            elseif val.AXRole == "AXMenuItem" and not val.AXChildren then
                if val.AXTitle ~= "" then
                    local upperlevel = table.clone(hs_currententry)
                    table.insert(upperlevel,val.AXTitle)
                    table.insert(hs_menuchain,upperlevel)
                end
            end
        end
    end
end

function MenuitemsRequest()
    local frontmost_win = hs.window.orderedWindows()[1]
    hs_belongto_app = frontmost_win:application()
    local all_menuitems = hs_belongto_app:getMenuItems()
    hs_menuchain = {}
    hs_currententry = {}
    hs_currentlevel = 0
    getMenuChain(all_menuitems)
    for idx,val in pairs(hs_menuchain) do
      local menuitem = {text=val[#val], subText=table.concat(val," | "), image=hs.image.imageFromAppBundle(hs_belongto_app:bundleID()), outputType="menuclick", menuitem=val}
        table.insert(chooser_data,menuitem)
    end
end

function MenuitemsSource()
    local menuitems_overview = {text="Type me<tab> to search Menuitems.", image=hs.image.imageFromPath("./resources/menus.png")}
    table.insert(chooserSourceOverview,menuitems_overview)
    function menuitemsFunc()
        MenuitemsRequest()
        local source_desc = {text="Menuitems Search", subText="Search and select some menuitem to get it clicked.", image=hs.image.imageFromPath("./resources/menus.png")}
        table.insert(chooser_data, 1, source_desc)
        search_chooser:choices(chooser_data)
        search_chooser:queryChangedCallback()
        search_chooser:searchSubText(true)
    end
    local sourcepkg = {}
    sourcepkg.kw = "me"
    sourcepkg.func = menuitemsFunc
    -- Add this source to SourceTable
    table.insert(chooserSourceTable,sourcepkg)
end

MenuitemsSource()

-- New source - Menuitems Search End here
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- New source - v2ex Posts

function v2exRequest()
    local query_url = 'https://www.v2ex.com/api/topics/latest.json'
    local stat, body = hs.http.asyncGet(query_url,nil,function(status,data)
        if status == 200 then
            if pcall(function() hs.json.decode(data) end) then
                local decoded_data = hs.json.decode(data)
                if #decoded_data > 0 then
                    chooser_data = hs.fnutils.imap(decoded_data, function(item)
                        local sub_content = string.gsub(item.content,"\r\n"," ")
                        local function trim_content()
                            if utf8.len(sub_content) > 40 then
                                return string.sub(sub_content,1,utf8.offset(sub_content,40)-1)
                            else
                                return sub_content
                            end
                        end
                        local final_content = trim_content()
                        return {text=item.title, subText=final_content, image=hs.image.imageFromPath("./resources/v2ex.png"), outputType="browser", url=item.url}
                    end)
                    local source_desc = {text="v2ex Posts", subText="Select some item to get it opened in default browser …", image=hs.image.imageFromPath("./resources/v2ex.png")}
                    table.insert(chooser_data, 1, source_desc)
                    search_chooser:choices(chooser_data)
                    search_chooser:refreshChoicesCallback()
                end
            end
        end
    end)
end

function v2exSource()
    local v2ex_overview = {text="Type v2<tab> to fetch v2ex Posts.", image=hs.image.imageFromPath("./resources/v2ex.png")}
    table.insert(chooserSourceOverview,v2ex_overview)
    function v2exFunc()
        local source_desc = {text="Requesting data, please wait a while …"}
        table.insert(chooser_data, 1, source_desc)
        search_chooser:choices(chooser_data)
        v2exRequest()
        search_chooser:queryChangedCallback()
        search_chooser:searchSubText(true)
    end
    local sourcepkg = {}
    sourcepkg.kw = "v2"
    sourcepkg.func = v2exFunc
    table.insert(chooserSourceTable,sourcepkg)
end

v2exSource()

-- New source - v2ex Posts End here
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- New source - Emoji Source

function emojiRequest(querystr)
    local emoji_baseurl = 'https://emoji.getdango.com'
    if string.len(querystr) > 0 then
        local encoded_query = hs.http.encodeForQuery(querystr)
        local query_url = emoji_baseurl..'/api/emoji?q='..encoded_query

        hs.http.asyncGet(query_url,nil,function(status,data)
            if status == 200 then
                if pcall(function() hs.json.decode(data) end) then
                    local decoded_data = hs.json.decode(data)
                    if decoded_data.results and #decoded_data.results > 0 then
                        if not hs_emoji_data then
                            local emoji_database_path = "/System/Library/Input Methods/CharacterPalette.app/Contents/Resources/CharacterDB.sqlite3"
                            hs_emoji_data = hs.sqlite3.open(emoji_database_path)
                        end
                        if hs_emoji_canvas then hs_emoji_canvas:delete() hs_emoji_canvas=nil end
                        local hs_emoji_canvas = hs.canvas.new({x=0,y=0,w=96,h=96})
                        chooser_data = hs.fnutils.imap(decoded_data.results, function(item)
                            hs_emoji_canvas[1] = {type="text",text=item.text,textSize=64,frame={x="15%",y="10%",w="100%",h="100%"}}
                            local hexcode = string.format("%#X",utf8.codepoint(item.text))
                            local function getEmojiDesc()
                                for w in hs_emoji_data:rows("SELECT info FROM unihan_dict WHERE uchr=\'"..item.text.."\'") do
                                    return w[1]
                                end
                            end
                            local emoji_description = getEmojiDesc()
                            local formatted_desc = string.gsub(emoji_description,"|||||||||||||||","")
                            return {text = formatted_desc, image=hs_emoji_canvas:imageFromCanvas(), subText="Hex Code: "..hexcode, outputType="keystrokes", typingText=item.text}
                        end)
                        search_chooser:choices(chooser_data)
                        search_chooser:refreshChoicesCallback()
                    end
                end
            end
        end)
    else
        chooser_data = {}
        local source_desc = {text="Relevant Emoji", subText="Type something to find relevant emoji from text …", image=hs.image.imageFromPath("./resources/emoji.png")}
        table.insert(chooser_data, 1, source_desc)
        search_chooser:choices(chooser_data)
    end
end

function emojiSource()
  local emoji_overview = {text="Type mo<tab> to find relevant Emoji.", image=hs.image.imageFromPath("./resources/emoji.png")}
    table.insert(chooserSourceOverview,emoji_overview)
    function emojiFunc()
        local source_desc = {text="Relevant Emoji", subText="Type something to find relevant emoji from text …", image=hs.image.imageFromPath("./resources/emoji.png")}
        table.insert(chooser_data, 1, source_desc)
        search_chooser:choices(chooser_data)
        search_chooser:queryChangedCallback(emojiRequest)
    end
    local sourcepkg = {}
    sourcepkg.kw = "mo"
    sourcepkg.func = emojiFunc
    -- Add this source to SourceTable
    table.insert(chooserSourceTable,sourcepkg)
end

emojiSource()

-- New source - Emoji Source End here
--------------------------------------------------------------------------------
