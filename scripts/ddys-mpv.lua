local mp = require("mp")
local utils = require("mp.utils")
local options = require("mp.options")

local opt = {
    api_base = "https://ddys.io/api/v1",
    site_base = "https://ddys.io",
    api_key = "",
    http_command = "curl",
    http_timeout = 15,
    page_size = 24,
    home_limit = 24,
    menu_rows = 12,
    osd_seconds = 8,
    prefer_direct = true,
    prefer_keywords = "1080,2160,4k,蓝光,高清,m3u8,mp4",
    include_external = true,
    direct_only = false,
    history_limit = 80,
    data_dir = "",
    auto_play_best = false,
    key_menu = "Ctrl+d",
    key_search = "Ctrl+s",
    key_latest = "Ctrl+l",
    key_history = "Ctrl+h",
    key_favorites = "Ctrl+f",
}

options.read_options(opt, "ddys-mpv")

local state = {
    mode = "home",
    page = 1,
    cursor = 1,
    items = {},
    title = "DDYS",
    query = "",
    current_movie = nil,
    current_resources = {},
    menu_open = false,
    nav_bound = false,
}

local source_defs = {
    { id = "latest", label = "最新更新", endpoint = "/latest", list = true },
    { id = "hot", label = "热门内容", endpoint = "/hot", list = true },
    { id = "movie", label = "电影", type = "movie" },
    { id = "series", label = "剧集", type = "series" },
    { id = "anime", label = "动漫", type = "anime" },
    { id = "variety", label = "综艺", type = "variety" },
    { id = "documentary", label = "纪录片", type = "documentary" },
}

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function clamp_number(value, fallback, min_value, max_value)
    local number = tonumber(value) or fallback
    if number < min_value then return min_value end
    if number > max_value then return max_value end
    return math.floor(number)
end

opt.page_size = clamp_number(opt.page_size, 24, 1, 100)
opt.home_limit = clamp_number(opt.home_limit, 24, 1, 100)
opt.menu_rows = clamp_number(opt.menu_rows, 12, 5, 30)
opt.history_limit = clamp_number(opt.history_limit, 80, 10, 500)
opt.osd_seconds = clamp_number(opt.osd_seconds, 8, 2, 60)

local function join_url(base, path)
    base = trim(base):gsub("/+$", "")
    path = trim(path)
    if path:sub(1, 1) ~= "/" then path = "/" .. path end
    return base .. path
end

local function urlencode(value)
    value = tostring(value or "")
    value = value:gsub("\n", "\r\n")
    value = value:gsub("([^%w%-%_%.%~])", function(char)
        return string.format("%%%02X", string.byte(char))
    end)
    return value
end

local function build_url(path, query)
    local url = join_url(opt.api_base, path)
    local parts = {}
    for key, value in pairs(query or {}) do
        if value ~= nil and trim(value) ~= "" then
            table.insert(parts, urlencode(key) .. "=" .. urlencode(value))
        end
    end
    if #parts > 0 then
        url = url .. "?" .. table.concat(parts, "&")
    end
    return url
end

local function script_dir()
    if opt.data_dir and trim(opt.data_dir) ~= "" then
        return trim(opt.data_dir)
    end
    return mp.command_native({"expand-path", "~~/"})
end

local function ensure_data_dir()
    return script_dir()
end

local function read_json_file(path, fallback)
    local file = io.open(path, "r")
    if not file then return fallback end
    local body = file:read("*a")
    file:close()
    local parsed = utils.parse_json(body)
    if parsed == nil then return fallback end
    return parsed
end

local function write_json_file(path, value)
    local file = io.open(path, "w")
    if not file then return false end
    file:write(utils.format_json(value or {}))
    file:write("\n")
    file:close()
    return true
end

local function data_file(name)
    return utils.join_path(ensure_data_dir(), "ddys-mpv-" .. name)
end

local function osd(lines, seconds)
    if type(lines) == "table" then
        mp.osd_message(table.concat(lines, "\n"), seconds or opt.osd_seconds)
    else
        mp.osd_message(tostring(lines or ""), seconds or opt.osd_seconds)
    end
end

local function notify(message)
    osd("DDYS: " .. tostring(message or ""), math.min(opt.osd_seconds, 5))
end

local function first_value(item, keys)
    if type(item) ~= "table" then return "" end
    for _, key in ipairs(keys) do
        local value = item[key]
        if value ~= nil and trim(value) ~= "" then
            if type(value) == "table" then
                local out = {}
                for _, v in ipairs(value) do
                    if trim(v) ~= "" then table.insert(out, trim(v)) end
                end
                return table.concat(out, " / ")
            end
            return trim(value)
        end
    end
    return ""
end

local function array_from(value)
    if type(value) ~= "table" then return {} end
    local out = {}
    for index = 1, #value do table.insert(out, value[index]) end
    return out
end

local function data_node(root)
    if type(root) == "table" and root.data ~= nil then return root.data end
    return root
end

local function array_items(value)
    if type(value) ~= "table" then return {} end
    if #value > 0 then return array_from(value) end
    for _, key in ipairs({ "items", "list", "results", "movies", "records", "data" }) do
        if type(value[key]) == "table" then return array_from(value[key]) end
    end
    return {}
end

local function abs_url(value)
    value = trim(value)
    if value == "" then return "" end
    if value:match("^https?://") then return value end
    if value:match("^//") then return "https:" .. value end
    if value:sub(1, 1) == "/" then return opt.site_base:gsub("/+$", "") .. value end
    return value
end

local function normalize_movie(item)
    local slug = first_value(item, { "slug", "id", "vod_id", "key", "code", "video_id" })
    local title = first_value(item, { "title", "name", "vod_name", "title_cn" })
    if title == "" then title = slug end
    return {
        slug = slug,
        title = title,
        poster = abs_url(first_value(item, { "poster", "cover", "pic", "vod_pic", "image", "thumbnail" })),
        fanart = abs_url(first_value(item, { "fanart", "backdrop", "background", "vod_pic_slide" })),
        year = first_value(item, { "year", "release_year", "vod_year", "date", "release_date" }),
        type_name = first_value(item, { "type_name", "typeName", "type", "category", "vod_class" }),
        remarks = first_value(item, { "remarks", "vod_remarks", "episode", "episode_text", "score", "rate" }),
        overview = first_value(item, { "overview", "intro", "description", "summary", "content", "vod_content" }),
        url = abs_url(first_value(item, { "url", "link", "href" })),
    }
end

local function http_json(path, query)
    local url = build_url(path, query)
    local args = {
        opt.http_command,
        "-fsSL",
        "--max-time", tostring(opt.http_timeout),
        "-H", "Accept: application/json",
        "-H", "User-Agent: ddys-mpv/0.1.0",
    }
    if trim(opt.api_key) ~= "" then
        table.insert(args, "-H")
        table.insert(args, "Authorization: Bearer " .. trim(opt.api_key))
    end
    table.insert(args, url)

    local result = mp.command_native({
        name = "subprocess",
        args = args,
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
    })
    if not result or result.status ~= 0 then
        local err = result and result.stderr or "request failed"
        error(trim(err) ~= "" and err or "request failed")
    end
    local root = utils.parse_json(result.stdout or "{}")
    if type(root) == "table" and root.success == false then
        error(first_value(root, { "message", "error", "msg" }) ~= "" and first_value(root, { "message", "error", "msg" }) or "DDYS API failed")
    end
    return root
end

local function safe_call(fn)
    local ok, result = pcall(fn)
    if not ok then
        notify(result)
        return nil
    end
    return result
end

local function list_movies(source, page, query)
    if source.id == "latest" then
        local root = http_json("/latest", { limit = opt.home_limit })
        return array_items(data_node(root)), false
    end
    if source.id == "hot" then
        local root = http_json("/hot", { limit = opt.home_limit })
        return array_items(data_node(root)), false
    end
    if source.id == "search" then
        local root = http_json("/search", { q = query, page = page, per_page = opt.page_size })
        local data = data_node(root)
        local meta = root.meta or root.pagination or data.meta or data.pagination or {}
        local total_pages = tonumber(meta.total_pages or meta.totalPages or meta.last_page or meta.lastPage or meta.pages or 1) or 1
        return array_items(data), page < total_pages
    end
    local root = http_json("/movies", { type = source.type, page = page, per_page = opt.page_size })
    local data = data_node(root)
    local meta = root.meta or root.pagination or data.meta or data.pagination or {}
    local total_pages = tonumber(meta.total_pages or meta.totalPages or meta.last_page or meta.lastPage or meta.pages or 1) or 1
    return array_items(data), page < total_pages
end

local function is_direct(url)
    return trim(url):lower():match("%.m3u8[%?#]?$") or
        trim(url):lower():match("%.mp4[%?#]?$") or
        trim(url):lower():match("%.m4v[%?#]?$") or
        trim(url):lower():match("%.mkv[%?#]?$") or
        trim(url):lower():match("%.mov[%?#]?$") or
        trim(url):lower():match("%.flv[%?#]?$") or
        trim(url):lower():match("%.avi[%?#]?$") or
        trim(url):lower():match("%.ts[%?#]?$") or
        trim(url):lower():match("%.webm[%?#]?$") or
        trim(url):lower():match("%.mpd[%?#]?$") or
        trim(url):lower():match("%.m3u8[?#]") or
        trim(url):lower():match("%.mp4[?#]") or
        trim(url):lower():match("%.mpd[?#]")
end

local function read_resource(item, index, group_name, group_index)
    if type(item) == "string" then
        return {
            name = "资源 " .. index,
            url = trim(item),
            group_name = group_name,
            group_index = group_index,
            direct = is_direct(item) ~= nil,
        }
    end
    if type(item) ~= "table" then return nil end
    local url = first_value(item, { "url", "link", "href", "src", "file", "play_url", "playUrl", "download_url", "downloadUrl", "magnet", "ed2k" })
    if url == "" then return nil end
    local label = first_value(item, { "name", "title", "label", "episode", "episode_name", "quality", "format" })
    if label == "" then label = "资源 " .. index end
    local code = first_value(item, { "extract_code", "extractCode", "code", "password", "passcode" })
    if code ~= "" and not label:find(code, 1, true) then label = label .. " 提取码 " .. code end
    return {
        name = label,
        url = url,
        group_name = group_name,
        group_index = group_index,
        direct = is_direct(url) ~= nil,
    }
end

local function collect_arrays(group)
    local out = {}
    for _, key in ipairs({ "items", "resources", "episodes", "playlist", "play", "urls", "list", "online", "download", "downloads", "cloud", "netdisk", "drive", "magnet", "magnets" }) do
        if type(group[key]) == "table" then
            for _, value in ipairs(array_from(group[key])) do table.insert(out, value) end
        end
    end
    return out
end

local function has_resource_array(group)
    if type(group) ~= "table" then return false end
    return #collect_arrays(group) > 0
end

local function flatten_sources(data)
    data = data_node(data)
    local resources = {}
    local function add_group(group_name, values, group_index)
        local index = 1
        for _, item in ipairs(values) do
            local resource = read_resource(item, index, group_name, group_index)
            if resource and resource.url ~= "" then table.insert(resources, resource) end
            index = index + 1
        end
    end

    if type(data) ~= "table" then return resources end
    if #data > 0 then
        if has_resource_array(data[1]) then
            for group_index, group in ipairs(data) do
                local name = first_value(group, { "name", "title", "label", "source", "type" })
                if name == "" then name = "线路 " .. group_index end
                add_group(name, collect_arrays(group), group_index)
            end
        else
            add_group("Online", array_from(data), 1)
        end
        return resources
    end

    local group_index = 1
    for _, key in ipairs({ "online", "play", "playlist", "episodes", "items", "resources", "urls", "list", "download", "downloads", "cloud", "netdisk", "drive", "magnet", "magnets" }) do
        if type(data[key]) == "table" then
            add_group(key, array_from(data[key]), group_index)
            group_index = group_index + 1
        end
    end
    return resources
end

local function resource_score(resource)
    local text = (resource.name .. " " .. resource.url):lower()
    local score = resource.direct and 100 or 0
    local weight = 20
    for keyword in string.gmatch(opt.prefer_keywords or "", "([^,]+)") do
        keyword = trim(keyword):lower()
        if keyword ~= "" and text:find(keyword, 1, true) then score = score + weight end
        weight = math.max(1, weight - 2)
    end
    if text:find("magnet:", 1, true) then score = score - 40 end
    return score
end

local function filtered_resources(resources)
    local out = {}
    for _, resource in ipairs(resources or {}) do
        if resource.url ~= "" and (not opt.direct_only or resource.direct) and (opt.include_external or resource.direct) then
            table.insert(out, resource)
        end
    end
    table.sort(out, function(a, b)
        return resource_score(a) > resource_score(b)
    end)
    return out
end

local function load_history()
    return read_json_file(data_file("history.json"), {})
end

local function save_history(history)
    while #history > opt.history_limit do table.remove(history) end
    write_json_file(data_file("history.json"), history)
end

local bind_navigation
local unbind_navigation

local function load_favorites()
    return read_json_file(data_file("favorites.json"), {})
end

local function save_favorites(favorites)
    write_json_file(data_file("favorites.json"), favorites)
end

local function remember(movie, resource)
    local history = load_history()
    table.insert(history, 1, {
        title = movie and movie.title or "",
        slug = movie and movie.slug or "",
        resource = resource and resource.name or "",
        url = resource and resource.url or "",
        at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })
    save_history(history)
end

local function play_resource(resource, movie)
    if not resource or trim(resource.url) == "" then
        notify("没有可播放链接")
        return
    end
    mp.commandv("loadfile", resource.url, "replace")
    state.menu_open = false
    if unbind_navigation then unbind_navigation() end
    remember(movie or state.current_movie or {}, resource)
    notify("播放: " .. (movie and movie.title or state.current_movie and state.current_movie.title or resource.name))
end

local function selected_item()
    return state.items[state.cursor]
end

local function render_menu()
    state.menu_open = true
    if bind_navigation then bind_navigation() end
    local lines = { state.title }
    if #state.items == 0 then
        table.insert(lines, "")
        table.insert(lines, "没有内容")
        osd(lines)
        return
    end
    local start = math.max(1, state.cursor - math.floor(opt.menu_rows / 2))
    local stop = math.min(#state.items, start + opt.menu_rows - 1)
    for index = start, stop do
        local prefix = index == state.cursor and "➤ " or "  "
        local item = state.items[index]
        table.insert(lines, string.format("%s%d. %s", prefix, index, item.label or item.title or item.name or item.url or "item"))
    end
    table.insert(lines, "")
    table.insert(lines, "↑/↓ 选择  Enter 打开  Backspace 返回  Ctrl+s 搜索")
    osd(lines)
end

local function set_menu(mode, title, items)
    state.mode = mode
    state.title = title
    state.items = items or {}
    state.cursor = math.min(math.max(1, state.cursor), math.max(1, #state.items))
    render_menu()
end

local function home_menu()
    local items = {}
    for _, source in ipairs(source_defs) do
        table.insert(items, { label = source.label, source = source })
    end
    table.insert(items, { label = "搜索", action = "search" })
    table.insert(items, { label = "播放历史", action = "history" })
    table.insert(items, { label = "收藏/稍后看", action = "favorites" })
    set_menu("home", "DDYS mpv", items)
end

local function movies_menu(source, page, query)
    local result = safe_call(function()
        local raw_items, has_next = list_movies(source, page, query)
        local items = {}
        for _, raw in ipairs(raw_items) do
            local movie = normalize_movie(raw)
            if movie.title ~= "" and movie.slug ~= "" then
                local label = movie.title
                if movie.year ~= "" then label = label .. " (" .. movie.year:sub(1, 4) .. ")" end
                if movie.remarks ~= "" then label = label .. " - " .. movie.remarks end
                table.insert(items, { label = label, movie = movie, source = source, page = page, query = query })
            end
        end
        if has_next then
            table.insert(items, { label = "下一页", action = "next_page", source = source, page = page + 1, query = query })
        end
        return items
    end)
    if result then
        local title = source.label
        if query and query ~= "" then title = "搜索: " .. query end
        set_menu("movies", title .. " 第 " .. page .. " 页", result)
    end
end

local function detail_menu(movie)
    local resources = safe_call(function()
        local root = http_json("/movies/" .. urlencode(movie.slug) .. "/sources")
        return filtered_resources(flatten_sources(root))
    end)
    if not resources then return end
    state.current_movie = movie
    state.current_resources = resources
    if opt.auto_play_best and #resources > 0 then
        play_resource(resources[1], movie)
        return
    end

    local items = {
        { label = "自动选择最佳线路", action = "play_best", movie = movie },
        { label = "加入收藏/稍后看", action = "favorite", movie = movie },
        { label = "导出 M3U 播放列表", action = "export_m3u", movie = movie },
        { label = "导出 PLS 播放列表", action = "export_pls", movie = movie },
    }
    for _, resource in ipairs(resources) do
        local label = (resource.group_name or "资源") .. " - " .. (resource.name or resource.url)
        if resource.direct then label = label .. " [direct]" end
        table.insert(items, { label = label, resource = resource, movie = movie })
    end
    if #resources == 0 then
        table.insert(items, { label = "没有接口资源，打开 DDYS 页面", resource = { name = "DDYS page", url = movie.url }, movie = movie })
    end
    set_menu("detail", movie.title, items)
end

local function export_playlist(kind, movie, resources)
    local dir = ensure_data_dir()
    local slug = movie.slug ~= "" and movie.slug or "ddys"
    local ext = kind == "pls" and "pls" or "m3u"
    local path = utils.join_path(dir, slug .. "." .. ext)
    local file = io.open(path, "w")
    if not file then
        notify("无法写入播放列表")
        return
    end
    if kind == "pls" then
        file:write("[playlist]\n")
        file:write("NumberOfEntries=" .. tostring(#resources) .. "\n")
        for index, resource in ipairs(resources) do
            file:write("File" .. index .. "=" .. resource.url .. "\n")
            file:write("Title" .. index .. "=" .. movie.title .. " - " .. resource.name .. "\n")
        end
        file:write("Version=2\n")
    else
        file:write("#EXTM3U\n")
        for _, resource in ipairs(resources) do
            file:write("#EXTINF:-1," .. movie.title .. " - " .. resource.name .. "\n")
            file:write(resource.url .. "\n")
        end
    end
    file:close()
    notify("已导出: " .. path)
end

local function add_favorite(movie)
    local favorites = load_favorites()
    for _, item in ipairs(favorites) do
        if item.slug == movie.slug then
            notify("已在收藏中")
            return
        end
    end
    table.insert(favorites, 1, movie)
    save_favorites(favorites)
    notify("已收藏: " .. movie.title)
end

local function history_menu()
    local items = {}
    for _, item in ipairs(load_history()) do
        table.insert(items, {
            label = (item.title or "历史") .. " - " .. (item.resource or ""),
            resource = { name = item.resource or "history", url = item.url or "" },
            movie = { title = item.title or "", slug = item.slug or "" },
        })
    end
    set_menu("history", "播放历史", items)
end

local function favorites_menu()
    local items = {}
    for _, movie in ipairs(load_favorites()) do
        table.insert(items, { label = movie.title or movie.slug or "收藏", movie = movie })
    end
    set_menu("favorites", "收藏/稍后看", items)
end

local function prompt_search()
    mp.command("script-message-to console type \"script-message ddys-mpv-search \"")
    notify("在控制台输入关键词后回车")
end

local function open_item(item)
    if not item then return end
    if item.action == "search" then return prompt_search() end
    if item.action == "history" then return history_menu() end
    if item.action == "favorites" then return favorites_menu() end
    if item.action == "next_page" then return movies_menu(item.source, item.page, item.query) end
    if item.action == "play_best" then return play_resource(state.current_resources[1], item.movie) end
    if item.action == "favorite" then return add_favorite(item.movie) end
    if item.action == "export_m3u" then return export_playlist("m3u", item.movie, state.current_resources) end
    if item.action == "export_pls" then return export_playlist("pls", item.movie, state.current_resources) end
    if item.source then return movies_menu(item.source, 1, "") end
    if item.resource then return play_resource(item.resource, item.movie) end
    if item.movie then return detail_menu(item.movie) end
end

local function back()
    if state.mode == "home" then
        render_menu()
    else
        home_menu()
    end
end

local function move_cursor(delta)
    if #state.items == 0 then return end
    state.cursor = state.cursor + delta
    if state.cursor < 1 then state.cursor = #state.items end
    if state.cursor > #state.items then state.cursor = 1 end
    render_menu()
end

function bind_navigation()
    if state.nav_bound then return end
    state.nav_bound = true
    mp.add_forced_key_binding("UP", "ddys-mpv-up", function() if state.menu_open then move_cursor(-1) end end)
    mp.add_forced_key_binding("DOWN", "ddys-mpv-down", function() if state.menu_open then move_cursor(1) end end)
    mp.add_forced_key_binding("ENTER", "ddys-mpv-enter", function() if state.menu_open then open_item(selected_item()) end end)
    mp.add_forced_key_binding("BS", "ddys-mpv-back", function() if state.menu_open then back() end end)
    mp.add_forced_key_binding("ESC", "ddys-mpv-close", function()
        state.menu_open = false
        if unbind_navigation then unbind_navigation() end
        mp.osd_message("")
    end)
end

function unbind_navigation()
    if not state.nav_bound then return end
    state.nav_bound = false
    for _, name in ipairs({ "ddys-mpv-up", "ddys-mpv-down", "ddys-mpv-enter", "ddys-mpv-back", "ddys-mpv-close" }) do
        pcall(mp.remove_key_binding, name)
    end
end

local function open_latest()
    movies_menu(source_defs[1], 1, "")
end

local function perform_search(query)
    query = trim(query)
    if query == "" then return notify("搜索关键词为空") end
    movies_menu({ id = "search", label = "搜索" }, 1, query)
end

mp.register_script_message("ddys-mpv-search", perform_search)
mp.add_key_binding(opt.key_menu, "ddys-mpv-menu", home_menu)
mp.add_key_binding(opt.key_search, "ddys-mpv-search-prompt", prompt_search)
mp.add_key_binding(opt.key_latest, "ddys-mpv-latest", open_latest)
mp.add_key_binding(opt.key_history, "ddys-mpv-history", history_menu)
mp.add_key_binding(opt.key_favorites, "ddys-mpv-favorites", favorites_menu)

mp.register_event("file-loaded", function()
    if state.mode ~= "home" and state.mode ~= "" then
        render_menu()
    end
end)

notify("已加载，按 " .. opt.key_menu .. " 打开 DDYS 菜单")
