package.path = package.path .. ';.luarocks/share/lua/5.2/?.lua'
  ..';.luarocks/share/lua/5.2/?/init.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

require("./bot/utils")

VERSION = '1.0'

-- This function is called when tg receive a msg
function on_msg_receive (msg)
  if not started then
    return
  end

  local receiver = get_receiver(msg)
  print (receiver)

  --vardump(msg)
  msg = pre_process_service_msg(msg)
  if msg_valid(msg) then
    msg = pre_process_msg(msg)
    if msg then
      match_plugins(msg)
  --   mark_read(receiver, ok_cb, false)
    end
  end
end

function ok_cb(extra, success, result)
end

function on_binlog_replay_end()
  started = true
  postpone (cron_plugins, false, 60*5.0)

  _config = load_config()

  -- load plugins
  plugins = {}
  load_plugins()
end

function msg_valid(msg)
  -- Don't process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < now then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  if msg.from.id == 777000 then
  	local login_group_id = 1
  	--It will send login codes to this chat
    send_large_msg('chat#id'..login_group_id, msg.text)
  end

  return true
end

--
function pre_process_service_msg(msg)
   if msg.service then
      local action = msg.action or {type=""}
      -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

      -- wipe the data to allow the bot to read service messages
      if msg.out then
         msg.out = false
      end
      if msg.from.id == our_id then
         msg.from.id = 0
      end
   end
   return msg
end

-- Apply plugin.pre_process function
function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      print('Preprocess', name)
      msg = plugin.pre_process(msg)
    end
  end

  return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        send_msg(receiver, warning, ok_cb, false)
        return true
      end
    end
  end
  return false
end

function match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches it's enough.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
  send_large_msg(destination, text)
end

-- Save the content of _config to config.lua
function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
    "onservice",
    "inrealm",
    "ingroup",
    "inpm",
    "banhammer",
    "stats",
    "anti_spam",
    "owners",
    "arabic_lock",
    "set",
    "get",
    "broadcast",
    "download_media",
    "invite",
    "all",
    "leave_ban"
    },
    sudo_users = {152485254,152350938,0,tonumber(our_id)},--Sudo users
    disabled_channels = {},
    moderation = {data = 'data/moderation.json'},
    about_text = [[DEATH v2 - NO
🚩DEATH🚩
🚩A R A S H🚩
Admins
🚩A 
🚩R
🚩A
🚩S
🚩H
♥🔍
🅰
@arash_admin_death
✅✔
🅰
Our channels
✨✨✨✨✨✨
@deathch [persian]
]],
    help_text_realm = [[
realm Commands:
!creategroup [Name]
🚩Create a group🚩
!createrealm [Name]
↪Create a realm↩
!setname [Name]
🔘Set realm name🔘
!setabout [GroupID] [Text]
♦Set a group's about text♦
!setrules [GroupID] [Text]
🔍Set a group's rules🔍
!lock [GroupID] [setting]
🔒Lock a group's setting🔒
!unlock [GroupID] [setting]
🔓Unock a group's setting🔓
!wholist
🔺Get a list of members in group/realm🔺
!who
❗Get a file of members in group/realm❗
!type
🔷Get group type🔶
!kill chat [GroupID]
🚫Kick all memebers and delete group🚫
!kill realm [RealmID]
❌Kick all members and delete realm❌
!addadmin [id|username]
🌟Promote an admin by id OR username *Sudo only🌟
!removeadmin [id|username]
✖🌟Demote an admin by id OR username *Sudo only✖🌟
!list groups
Get a list of all groups
!list realms
◀Get a list of all realms▶
!log
💥Grt a logfile of current group or realm💥
!broadcast [text]
!broadcast Hello !
📢Send text to all groups📢
💢Only sudo users can run this command💢
!br [group_id] [text]
!br 123456789 Hello
 🔊This command will send text to [group_id]🔊
**U can use both "/" and "!" 🔥
*Only admins and sudo can add bots in group🤖➕
*Only admins and sudo can use kick,ban,unban,newlink,setphoto,setname,lock,unlock,set rules,set about and settings commands⭕
*Only admins and sudo can use res, setowner, commands✴
]],
    help_text = [[
Commands list :
!kick [username|id]
You can also do it by reply😎
😎اخراج کسی از گروه
!ban [ username|id]
You can also do it by reply
بن کردن کسی از گروه⭕
!unban [id]
You can also do it by reply⭕❌
از بن در اوردن کسی در گروه⭕❌
!who
🚹Members list🚹
لیست اعضا
!modlist
👥⭐Moderators list⭐👥
لیست مدیران گروه
!promote [username]
Promote someone👤⭐
مدیر کردن یک نفر در گروه
!demote [username]
Demote someone👤⭐❌
بر کنار کردن کسی از مدیریت در گروه
!kickme
Will kick user👤➖
بیرون رفتن از گروه 
!about
Group descriptionℹ
درباره گروه
!setphoto
Set and locks group photo🗻
گزاشتن عکس برای گروه
!setname [name]
Set group name✴➕
گزاشتن اسم برای گروه 
!rules
Group rules⚠
قوانین گروه
!id
return group id or user 🆔
ایدی گروه/با ریپلی کردن پیام ایدی فرد ی
!help
لیست دستورات گروه
!lock [member|name|bots|leave]	
Locks [member|name|bots|leaveing]🔒
قفل|دروازه گروه|اسم گروه|ورود بات |لفت دادن
!unlock [member|name|bots|leave]
Unlocks [member|name|bots|leaving]🔒
باز کردن قفل |دروازه گروه|اسم گروه|ورود ربات|لفت دادن
!set rules <text>
🔱Set <text> as rules🔱
گزاشتن قوانین برای گروه
!set about <text>
♎Set <text> as about♎
گزاشتن موضوع گروه 
!settings
♐Returns group settings♐
تنظیمات گروه 
!newlink
create/revoke your group link🆕🔗
لینک جدید
!link
returns group link🔗
لینک گروه
!owner
returns group owner 🆔
ایدی صاحب گروه
!setowner [id]
♠Will set id as owner♠
تعیین کردن کس دیگری به عنوان صاحب گروه
!setflood [value]
Set [value] as flood sensitivity✨
تعیین کردن مقدار فلود گروه 
!stats
🔴Simple message statistics🔴
امار پیام های ارسالی گروه
!save [value] <text>
🌠Save <text> as [value]🌠
گزاشتن دستوری در گروه با متن
!get [value]
Returns text of [value]🔘
دریافت متن دستور ذخیره شده
!clean [modlist|rules|about]
Will clear [modlist|rules|about] and set it to nil🔃
پاک کردن |مدیران گروه|قوانین|درباره گروه
!res [username]
returns user 🆔
"!res @username"
پیدا کردن ایدی یک نفر از طریق نام کاربری
!log
will return group logs❇
دستورات وارد شده در گروه
!banlist
will return group ban list💢
لیست کسانی که بن شده اند
**U can use both "/" and "!" 
شما می توانید از "/" و‌ "!"  استفاده کنید
*Only owner and mods can add bots in group
فقط صاحب گروه و مدیران گروه میتوانند بات در گروه اد کنند
*Only moderators and owner can use kick,ban,unban,newlink,link,setphoto,setname,lock,unlock,set rules,set about and settings commands
فقط مدیران گروه و صاحب گروه میتوانند از دستورات اخراج، بن، ان بن، لینک جدید،دریافت لینک گروه،گزاشتن نام برای گروه،گزاشتن عکس برای گروه،قفل کردن ،باز کردن قفل،گزاشتن قوانین استفاده کنند
*Only owner can use res,setowner,promote,demote and log commands
فقط صاحب گروه میتواند کسی را مدیر گروه کند و یا کسی را از مدیریت گروه برکنار کند و یا از طریق نام کاربری ایدی یک نفر را پیدا کند
]]
  }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)

end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
      print('\27[31m'..err..'\27[39m')
    end

  end
end


-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end

-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false
