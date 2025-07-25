-- mapper.lua

--[[

Authors: Original by Nick Gammon. Modified heavily for Aardwolf by Fiendish.

Generic MUD mapper.

Exposed functions:

init (t)            -- call once, supply:
   t.findpath    -- function for finding the path between two rooms (src, dest)
   t.config      -- ie. colours, sizes
   t.get_room    -- info about room (uid)
   t.show_help   -- function that displays some help
   t.room_click  -- function that handles RH click on room (uid, flags)
   t.timing      -- true to show timing
   t.show_completed  -- true to show "Speedwalk completed."
   t.show_other_areas -- true to show non-current areas
   t.show_up_down    -- follow up/down exits
   t.speedwalk_prefix   -- if not nil, speedwalk by prefixing with this

zoom_in ()          -- zoom in map view
zoom_out ()         -- zoom out map view
mapprint (message)  -- like print, but uses mapper colour
maperror (message)  -- like print, but prints in red
hide ()             -- hides map window (eg. if plugin disabled)
show ()             -- show map window  (eg. if plugin enabled)
save_state ()       -- call to save plugin state (ie. in OnPluginSaveState)
draw (uid)          -- draw map - starting at room 'uid'
start_speedwalk (path)  -- starts speedwalking. path is a table of directions/uids
build_speedwalk (path)  -- builds a client speedwalk string from path
cancel_speedwalk ()     -- cancel current speedwalk, if any
check_we_can_find ()    -- returns true if doing a find is OK right now
find (f, show_uid, count, walk)      -- generic room finder

Exposed variables:

win                 -- the window (in case you want to put up menus)
VERSION             -- mapper version
last_hyperlink_uid  -- room uid of last hyperlink click (destination)
last_speedwalk_uid  -- room uid of last speedwalk attempted (destination)
<various functions> -- functions required to be global by the client (eg. for mouseup)

Room info should include:

   name          (what to show as room name)
   exits         (table keyed by direction, value is exit uid)
   area          (area name)
   hovermessage  (what to show when you mouse-over the room)
   bordercolour  (colour of room border)     - RGB colour
   borderpen     (pen style of room border)  - see WindowCircleOp (values 0 to 6)
   borderpenwidth(pen width of room border)  - eg. 1 for normal, 2 for current room
   fillcolour    (colour to fill room)       - RGB colour, nil for default
   fillbrush     (brush to fill room)        - see WindowCircleOp (values 0 to 12)
   texture       (background texture file)   - cached in textures

--]]

module (..., package.seeall)

VERSION = 3.0   -- for querying by plugins
require "aard_register_z_on_create"

require "mw_theme_base"
require "movewindow"
require "copytable"
require "gauge"
require "pairsbykeys"
dofile (GetInfo(60) .. "darkwiz_colors.lua")


local FONT_ID     = "fn"  -- internal font identifier
local FONT_ID_UL  = "fnu" -- internal font identifier - underlined
local CONFIG_FONT_ID = "cfn"
local CONFIG_FONT_ID_UL = "cfnu"

-- size of room box
local ROOM_SIZE = tonumber(GetVariable("ROOM_SIZE")) or 12

-- how far away to draw rooms from each other
local DISTANCE_TO_NEXT_ROOM = 0--24 --tonumber(GetVariable("DISTANCE_TO_NEXT_ROOM")) or 8 --CURRENTLY SET TO 24
-- supplied in init
local supplied_get_room
local room_click
local timing            -- true to show timing and other info
local show_completed    -- true to show "Speedwalk completed."

-- current room number
local current_room

-- our copy of rooms info
local rooms = {}
local last_visited = {}
local textures = {}
local last_result_list = {}

-- other locals
local HALF_ROOM, connectors, half_connectors, arrows
local plan_to_draw, drawn, drawn_coords

-- Function to draw scaled transparent images
function draw_scaled_image_alpha(target_win, image_path, image_id, x, y, size, alpha, original_size)
   original_size = original_size or 32  -- default assumption
   alpha = alpha or 1
   
   local unique_id = image_id .. "_" .. tostring(x) .. "_" .. tostring(y)
   local hidden_win = "hidden_" .. unique_id
   local alpha_mask_win = "alpha_" .. unique_id  
   local alpha_stretched_win = "alpha_str_" .. unique_id
   
   -- Step 1: Create stretched image
   WindowCreate(hidden_win, 0, 0, size, size, 6, 0, 0)
   WindowLoadImage(hidden_win, image_id, image_path)
   WindowDrawImage(hidden_win, image_id, 0, 0, size, size, miniwin.image_stretch)
   
   -- Step 2: Create alpha mask from original
   WindowCreate(alpha_mask_win, 0, 0, original_size, original_size, 6, 0, 0)
   WindowLoadImage(alpha_mask_win, image_id, image_path)
   WindowGetImageAlpha(alpha_mask_win, image_id, 0, 0, original_size, original_size, 0, 0)
   
   -- Step 3: Stretch the alpha mask
   WindowCreate(alpha_stretched_win, 0, 0, size, size, 6, 0, 0)
   WindowImageFromWindow(alpha_stretched_win, "alpha_mask", alpha_mask_win)
   WindowDrawImage(alpha_stretched_win, "alpha_mask", 0, 0, size, size, miniwin.image_stretch)
   
   -- Step 4: Import and merge
   WindowImageFromWindow(target_win, unique_id .. "_img", hidden_win)
   WindowImageFromWindow(target_win, unique_id .. "_alpha", alpha_stretched_win)
   
   local left = x - size / 2
   local top = y - size / 2
   local right = x + size / 2
   local bottom = y + size / 2
   
   WindowMergeImageAlpha(target_win, unique_id .. "_img", unique_id .. "_alpha", left, top, right, bottom, 0, alpha, 0, 0, 0, 0)
   
   -- Clean up
   WindowDelete(hidden_win)
   WindowDelete(alpha_mask_win)
   WindowDelete(alpha_stretched_win)
end
local last_drawn, depth, font_height
local walk_to_room_name
local total_times_drawn = 0
local total_time_taken = 0

default_width = 269
default_height = 335
default_x = 868 + Theme.RESIZER_SIZE + 2
default_y = 0

function reset_pos()
   config.WINDOW.width = default_width
   config.WINDOW.height = default_height
   WindowPosition(win, default_x, default_y, 0, 18)
   WindowResize(win, default_width, default_height, BACKGROUND_COLOUR.colour)
   Repaint() -- hack because WindowPosition doesn't immediately update coordinates
end

local function build_room_info ()

   HALF_ROOM   = math.ceil(ROOM_SIZE / 2)
   local THIRD_WAY   = math.ceil(DISTANCE_TO_NEXT_ROOM / 3)
   local HALF_WAY = math.ceil(DISTANCE_TO_NEXT_ROOM / 2)

   barriers = {
      n =  { x1 = -HALF_ROOM, y1 = -HALF_ROOM, x2 = HALF_ROOM, y2 = -HALF_ROOM},
      s =  { x1 = -HALF_ROOM, y1 =  HALF_ROOM, x2 = HALF_ROOM, y2 =  HALF_ROOM},
      e =  { x1 =  HALF_ROOM, y1 = -HALF_ROOM, x2 =  HALF_ROOM, y2 = HALF_ROOM},
      w =  { x1 = -HALF_ROOM, y1 = -HALF_ROOM, x2 = -HALF_ROOM, y2 = HALF_ROOM},

      u = { x1 =  HALF_ROOM-HALF_WAY, y1 = -HALF_ROOM-HALF_WAY, x2 =  HALF_ROOM+HALF_WAY, y2 = -HALF_ROOM+HALF_WAY},
      d = { x1 = -HALF_ROOM+HALF_WAY, y1 =  HALF_ROOM+HALF_WAY, x2 = -HALF_ROOM-HALF_WAY, y2 =  HALF_ROOM-HALF_WAY},

   } -- end barriers

   -- how to draw a line from this room to the next one (relative to the center of the room)
   connectors = {
      n =  { x1 = 0,            y1 = - HALF_ROOM, x2 = 0,                             y2 = - HALF_ROOM - HALF_WAY, at = { 0, -1 } },
      s =  { x1 = 0,            y1 =   HALF_ROOM, x2 = 0,                             y2 =   HALF_ROOM + HALF_WAY, at = { 0,  1 } },
      e =  { x1 =   HALF_ROOM,  y1 = 0,           x2 =   HALF_ROOM + HALF_WAY,  y2 = 0,                            at = {  1,  0 }},
      w =  { x1 = - HALF_ROOM,  y1 = 0,           x2 = - HALF_ROOM - HALF_WAY,  y2 = 0,                            at = { -1,  0 }},

      u = { x1 =   HALF_ROOM,  y1 = - HALF_ROOM, x2 =   HALF_ROOM + HALF_WAY , y2 = - HALF_ROOM - HALF_WAY, at = { 1, -1 } },
      d = { x1 = - HALF_ROOM,  y1 =   HALF_ROOM, x2 = - HALF_ROOM - HALF_WAY , y2 =   HALF_ROOM + HALF_WAY, at = {-1,  1 } },

   } -- end connectors

   -- how to draw a stub line
   half_connectors = {
      n =  { x1 = 0,            y1 = - HALF_ROOM, x2 = 0,                        y2 = - HALF_ROOM - THIRD_WAY, at = { 0, -1 } },
      s =  { x1 = 0,            y1 =   HALF_ROOM, x2 = 0,                        y2 =   HALF_ROOM + THIRD_WAY, at = { 0,  1 } },
      e =  { x1 =   HALF_ROOM,  y1 = 0,           x2 =   HALF_ROOM + THIRD_WAY,  y2 = 0,                       at = {  1,  0 }},
      w =  { x1 = - HALF_ROOM,  y1 = 0,           x2 = - HALF_ROOM - THIRD_WAY,  y2 = 0,                       at = { -1,  0 }},

      u = { x1 =   HALF_ROOM,  y1 = - HALF_ROOM, x2 =   HALF_ROOM + THIRD_WAY , y2 = - HALF_ROOM - THIRD_WAY, at = { 1, -1 } },
      d = { x1 = - HALF_ROOM,  y1 =   HALF_ROOM, x2 = - HALF_ROOM - THIRD_WAY , y2 =   HALF_ROOM + THIRD_WAY, at = {-1,  1 } },

   } -- end half_connectors

   -- how to draw one-way arrows (relative to the center of the room)
   arrows = {
      n =  { - 2, - HALF_ROOM - 2,  2, - HALF_ROOM - 2,  0, - HALF_ROOM - 6 },
      s =  { - 2,   HALF_ROOM + 2,  2,   HALF_ROOM + 2,  0,   HALF_ROOM + 6  },
      e =  {   HALF_ROOM + 2, -2,   HALF_ROOM + 2, 2,   HALF_ROOM + 6, 0 },
      w =  { - HALF_ROOM - 2, -2, - HALF_ROOM - 2, 2, - HALF_ROOM - 6, 0 },

      u = {   HALF_ROOM + 3,  - HALF_ROOM,  HALF_ROOM + 3, - HALF_ROOM - 3,  HALF_ROOM, - HALF_ROOM - 3 },
      d = { - HALF_ROOM - 3,    HALF_ROOM,  - HALF_ROOM - 3,   HALF_ROOM + 3,  - HALF_ROOM,   HALF_ROOM + 3},

   } -- end of arrows

end -- build_room_info

-- assorted colours
BACKGROUND_COLOUR     = { name = "Area Background",  colour =  ColourNameToRGB "#111111"}
ROOM_COLOUR           = { name = "Room",             colour =  ColourNameToRGB "#dcdcdc"}
EXIT_COLOUR           = { name = "Exit",             colour =  ColourNameToRGB "#e0ffff"}
EXIT_COLOUR_UP_DOWN   = { name = "Exit up/down",     colour =  ColourNameToRGB "#ffb6c1"}
ROOM_NOTE_COLOUR      = { name = "Room notes",       colour =  ColourNameToRGB "lightgreen"}
OUR_ROOM_COLOUR       = { name = "Our Room Colour",  colour =  tonumber(GetPluginVariable("b6eae87ccedd84f510b74714", "OUR_ROOM_COLOUR")) or 0xFF }
WAYPOINT_FILL_COLOUR  = { name = "waypoint",         colour =  ColourNameToRGB "lime"}
UNKNOWN_ROOM_COLOUR   = { name = "Unknown room",     colour =  ColourNameToRGB "#9b0000"}
DIFFERENT_AREA_COLOUR = { name = "Another area",     colour =  ColourNameToRGB "#ff0000"}
PK_BORDER_COLOUR      = { name = "PK border",        colour =  ColourNameToRGB "red"}
SHOP_FILL_COLOUR      = { name = "Shop",             colour =  ColourNameToRGB "#ffad2f"}
REGULAR_FILL_COLOUR   = { name = "Regular",          colour =  ColourNameToRGB "white"}
FORGE_FILL_COLOUR     = { name = "Forge",            colour =  ColourNameToRGB "darkorange"}
HEALER_FILL_COLOUR    = { name = "Healer",           colour =  ColourNameToRGB "#9acd32"}
TRAINER_FILL_COLOUR   = { name = "Trainer",          colour =  ColourNameToRGB "#9acd32"}
QUESTOR_FILL_COLOUR   = { name = "Questor",          colour =  ColourNameToRGB "deepskyblue"}
BANK_FILL_COLOUR      = { name = "Bank",             colour =  ColourNameToRGB "#ffD700"}
GUILD_FILL_COLOUR     = { name = "Guild",            colour =  ColourNameToRGB "magenta"}
MAGE_TRAINER_FILL_COLOUR      = { name = "Mage Trainer",     colour =  ColourNameToRGB "slategray"}
CLERIC_TRAINER_FILL_COLOUR    = { name = "Cleric Trainer",   colour =  ColourNameToRGB "cyan"}
THIEF_TRAINER_FILL_COLOUR     = { name = "Thief Trainer",    colour =  ColourNameToRGB "purple"}
WARRIOR_TRAINER_FILL_COLOUR   = { name = "Warrior Trainer",  colour =  ColourNameToRGB "red"}
NECRO_TRAINER_FILL_COLOUR     = { name = "Necro Trainer",    colour =  ColourNameToRGB "mediumslateblue"}
DRUID_TRAINER_FILL_COLOUR     = { name = "Druid Trainer",    colour =  ColourNameToRGB "green"}
RANGER_TRAINER_FILL_COLOUR    = { name = "Ranger Trainer",   colour =  ColourNameToRGB "yellow"}
MISC_TRAINER_FILL_COLOUR      = { name = "Priest",           colour =  ColourNameToRGB "white"}
SAFEROOM_FILL_COLOUR  = { name = "Safe room",        colour =  ColourNameToRGB "lightblue"}
MAPPER_NOTE_COLOUR    = { name = "Messages",         colour =  ColourNameToRGB "lightgreen"}

ROOM_NAME_TEXT        = { name = "Room name text",   colour = ColourNameToRGB "#BEF3F1"}
ROOM_NAME_FILL        = { name = "Room name fill",   colour = ColourNameToRGB "#105653"}
ROOM_NAME_BORDER      = { name = "Room name box",    colour = ColourNameToRGB "black"}

AREA_NAME_TEXT        = { name = "Area name text",   colour = ColourNameToRGB "#BEF3F1"}
AREA_NAME_FILL        = { name = "Area name fill",   colour = ColourNameToRGB "#105653"}
AREA_NAME_BORDER      = { name = "Area name box",    colour = ColourNameToRGB "black"}

-- how many seconds to show "recent visit" lines (default 3 minutes)
LAST_VISIT_TIME = 60 * 3

default_config = {
   FONT = { name =  get_preferred_font {"Dina",  "Lucida Console",  "Fixedsys", "Courier",} ,
            size = 8
         } ,

   -- size of map window
   WINDOW = { width = default_width, height = default_height },

   -- how far from where we are standing to draw (rooms)
   SCAN = { depth = 300 },

   -- show custom tiling background textures
   USE_TEXTURES = { enabled = true },

   SHOW_ROOM_ID = false,

   SHOW_AREA_EXITS = false
}

local expand_direction = {
   n = "north",
   s = "south",
   e = "east",
   w = "west",
   u = "up",
   d = "down",
}  -- end of expand_direction

local function get_room (uid)
   local room = supplied_get_room (uid)
   room = room or { unknown = true }

   -- defaults in case they didn't supply them ...
   room.name = room.name or string.format ("Room %s", uid)
   room.name = strip_colours (room.name)  -- no colour codes for now
   room.exits = room.exits or {}
   room.area = room.area or "<No area>"
   room.hovermessage = room.hovermessage or "<Unexplored room>"
   room.bordercolour = room.bordercolour or ROOM_COLOUR.colour
   room.borderpen = room.borderpen or 0 -- solid
   room.borderpenwidth = room.borderpenwidth or 1
   room.fillcolour = room.fillcolour or 0x000000
   room.fillbrush = room.fillbrush or 1 -- no fill
   room.texture = room.texture or nil -- no texture

   room.textimage = nil

   if room.texture == nil or room.texture == "" then room.texture = "test5.png" end
   if textures[room.texture] then
      room.textimage = textures[room.texture] -- assign image
   else
      if textures[room.texture] ~= false then
         local dir = GetInfo(66)
         imgpath = dir .. "worlds\\plugins\\images\\" ..room.texture
         if WindowLoadImage(win, room.texture, imgpath) ~= 0 then
            textures[room.texture] = false  -- just indicates not found
         else
            textures[room.texture] = room.texture -- imagename
            room.textimage = room.texture
         end
      end
   end

   return room

end -- get_room

function check_connected ()
   if not IsConnected() then
      mapprint ("You are not connected to", WorldName())
      return false
   end -- if not connected
   return true
end -- check_connected

local function make_number_checker (title, min, max, decimals)
   return function (s)
      local n = tonumber (s)
      if not n then
         utils.msgbox (title .. " must be a number", "Incorrect input", "ok", "!", 1)
         return false  -- bad input
      end -- if
      if n < min or n > max then
         utils.msgbox (title .. " must be in range " .. min .. " to " .. max, "Incorrect input", "ok", "!", 1)
         return false  -- bad input
      end -- if
      if not decimals then
         if string.match (s, "%.") then
            utils.msgbox (title .. " cannot have decimal places", "Incorrect input", "ok", "!", 1)
            return false  -- bad input
         end -- if
      end -- no decimals
      return true  -- good input
   end -- generated function
end -- make_number_checker


local function get_number_from_user (msg, title, current, min, max, decimals)
   local max_length = math.ceil (math.log10 (max) + 1)

   -- if decimals allowed, allow room for them
   if decimals then
      max_length = max_length + 2  -- allow for 0.x
   end -- if

   -- if can be negative, allow for minus sign
   if min < 0 then
      max_length = max_length + 1
   end -- if can be negative

   return tonumber (utils.inputbox (msg, title, current, nil, nil,
      { validate = make_number_checker (title, min, max, decimals),
         prompt_height = 14,
         box_height = 130,
         box_width = 300,
         reply_width = 150,
         max_length = max_length,
      }  -- end extra stuff
   ))
end -- get_number_from_user

local function draw_configuration ()

   local config_entries = {"Map Configuration", "Show Room ID", "Show Area Exits", "Font", "Depth", "Area Textures", "Room size"}
   local width =  max_text_width (config_win, CONFIG_FONT_ID, config_entries , true)
   local GAP = 5

   local x = 0
   local y = 0
   local box_size = font_height - 2
   local rh_size = math.max (box_size, max_text_width (config_win, CONFIG_FONT_ID,
      {config.FONT.name .. " " .. config.FONT.size,
      ((config.USE_TEXTURES.enabled and "On") or "Off"),
      "- +",
      tostring (config.SCAN.depth)},
      true))
   local frame_width = GAP + width + GAP + rh_size + GAP  -- gap / text / gap / box / gap

   WindowCreate(config_win, windowinfo.window_left, windowinfo.window_top, frame_width, font_height * #config_entries + GAP+GAP, windowinfo.window_mode, windowinfo.window_flags, 0xDCDCDC)
   WindowSetZOrder(config_win, 99999) -- always on top

   -- frame it
   draw_3d_box (config_win, 0, 0, frame_width, font_height * #config_entries + GAP+GAP)

   y = y + GAP
   x = x + GAP

   -- title
   WindowText (config_win, CONFIG_FONT_ID, "Map Configuration", ((frame_width-WindowTextWidth(config_win,CONFIG_FONT_ID,"Map Configuration"))/2), y, 0, 0, 0x808080)

   -- close box
   WindowRectOp (config_win,
      miniwin.rect_frame,
      x,
      y + 1,
      x + box_size,
      y + 1 + box_size,
      0x808080)
   WindowLine (config_win,
      x + 3,
      y + 4,
      x + box_size - 3,
      y - 2 + box_size,
      0x808080,
      miniwin.pen_solid, 1)
   WindowLine (config_win,
      x + box_size - 4,
      y + 4,
      x + 2,
      y - 2 + box_size,
      0x808080,
      miniwin.pen_solid, 1)

   -- close configuration hotspot
   WindowAddHotspot(config_win, "$<close_configure>",
      x,
      y + 1,
      x + box_size,
      y + 1 + box_size,    -- rectangle
      "", "", "", "", "mapper.mouseup_close_configure",  -- mouseup
      "Click to close",
      miniwin.cursor_hand, 0)  -- hand cursor

   y = y + font_height

   -- depth
   WindowText(config_win, CONFIG_FONT_ID, "Depth", x, y, 0, 0, 0x000000)
   WindowText(config_win, CONFIG_FONT_ID_UL,   tostring (config.SCAN.depth), width + rh_size / 2 + box_size - WindowTextWidth(config_win, CONFIG_FONT_ID_UL, config.SCAN.depth)/2, y, 0, 0, 0x808080)

   -- depth hotspot
   WindowAddHotspot(config_win,
      "$<depth>",
      x + GAP,
      y,
      x + frame_width,
      y + font_height,   -- rectangle
      "", "", "", "", "mapper.mouseup_change_depth",  -- mouseup
      "Click to change scan depth",
      miniwin.cursor_hand, 0)  -- hand cursor
   y = y + font_height

   -- font
   WindowText(config_win, CONFIG_FONT_ID, "Font", x, y, 0, 0, 0x000000)
   WindowText(config_win, CONFIG_FONT_ID_UL,  config.FONT.name .. " " .. config.FONT.size, x + width + GAP, y, 0, 0, 0x808080)

   -- font hotspot
   WindowAddHotspot(config_win,
      "$<font>",
      x + GAP,
      y,
      x + frame_width,
      y + font_height,   -- rectangle
      "", "", "", "", "mapper.mouseup_change_font",  -- mouseup
      "Click to change font",
      miniwin.cursor_hand, 0)  -- hand cursor
   y = y + font_height

   -- area textures
   WindowText(config_win, CONFIG_FONT_ID, "Area Textures", x, y, 0, 0, 0x000000)
   WindowText(config_win, CONFIG_FONT_ID_UL, ((config.USE_TEXTURES.enabled and "On") or "Off"), width + rh_size / 2 + box_size - WindowTextWidth(config_win, CONFIG_FONT_ID_UL, ((config.USE_TEXTURES.enabled and "On") or "Off"))/2, y, 0, 0, 0x808080)

   -- area textures hotspot
   WindowAddHotspot(config_win,
      "$<area_textures>",
      x + GAP,
      y,
      x + frame_width,
      y + font_height,   -- rectangle
      "", "", "", "", "mapper.mouseup_change_area_textures",  -- mouseup
      "Click to toggle use of area textures",
      miniwin.cursor_hand, 0)  -- hand cursor
   y = y + font_height


   -- show ID
   WindowText(config_win, CONFIG_FONT_ID, "Show Room ID", x, y, 0, 0, 0x000000)
   WindowText(config_win, CONFIG_FONT_ID_UL, ((config.SHOW_ROOM_ID and "On") or "Off"), width + rh_size / 2 + box_size - WindowTextWidth(config_win, CONFIG_FONT_ID_UL, ((config.SHOW_ROOM_ID and "On") or "Off"))/2, y, 0, 0, 0x808080)

   -- show ID hotspot
   WindowAddHotspot(config_win,
      "$<room_id>",
      x + GAP,
      y,
      x + frame_width,
      y + font_height,   -- rectangle
      "", "", "", "", "mapper.mouseup_change_show_id",  -- mouseup
      "Click to toggle display of room UID",
      miniwin.cursor_hand, 0)  -- hand cursor
   y = y + font_height


   -- show area exits
   WindowText(config_win, CONFIG_FONT_ID, "Show Area Exits", x, y, 0, 0, 0x000000)
   WindowText(config_win, CONFIG_FONT_ID_UL, ((config.SHOW_AREA_EXITS and "On") or "Off"), width + rh_size / 2 + box_size - WindowTextWidth(config_win, CONFIG_FONT_ID_UL, ((config.SHOW_AREA_EXITS and "On") or "Off"))/2, y, 0, 0, 0x808080)

   -- show area exits hotspot
   WindowAddHotspot(config_win,
      "$<area_exits>",
      x + GAP,
      y,
      x + frame_width,
      y + font_height,   -- rectangle
      "", "", "", "", "mapper.mouseup_change_show_area_exits",  -- mouseup
      "Click to toggle display of area exits",
      miniwin.cursor_hand, 0)  -- hand cursor
   y = y + font_height


   -- room size
   WindowText(config_win, CONFIG_FONT_ID, "Room size", x, y, 0, 0, 0x000000)
   WindowText(config_win, CONFIG_FONT_ID, "("..tostring (ROOM_SIZE)..")", x + WindowTextWidth(config_win, CONFIG_FONT_ID, "Room size "), y, 0, 0, 0x808080)
   WindowText(config_win, CONFIG_FONT_ID_UL, "-", width + rh_size / 2 + box_size/2 - WindowTextWidth(config_win,CONFIG_FONT_ID,"-"), y, 0, 0, 0x808080)
   WindowText(config_win, CONFIG_FONT_ID_UL, "+", width + rh_size / 2 + box_size + GAP, y, 0, 0, 0x808080)

   -- room size hotspots
   WindowAddHotspot(config_win,
      "$<room_size_down>",
      width + rh_size / 2 + box_size/2 - WindowTextWidth(config_win,CONFIG_FONT_ID,"-"),
      y,
      width + rh_size / 2 + box_size/2 + WindowTextWidth(config_win,CONFIG_FONT_ID,"-"),
      y + font_height,   -- rectangle
      "", "", "", "", "mapper.zoom_out",  -- mouseup
      "Click to zoom out",
      miniwin.cursor_hand, 0)  -- hand cursor
   WindowAddHotspot(config_win,
      "$<room_size_up>",
      width + rh_size / 2 + box_size + GAP,
      y,
      width + rh_size / 2 + box_size + GAP + WindowTextWidth(config_win,CONFIG_FONT_ID,"+"),
      y + font_height,   -- rectangle
      "", "", "", "", "mapper.zoom_in",  -- mouseup
      "Click to zoom in",
      miniwin.cursor_hand, 0)  -- hand cursor
   y = y + font_height

   WindowShow(config_win, true)
end -- draw_configuration

-- for calculating one-way paths
local inverse_direction = {
   n = "s",
   s = "n",
   e = "w",
   w = "e",
   u = "d",
   d = "u",
   ne = "sw",
   se = "nw",
   sw = "ne",
   nw = "se"
}  -- end of inverse_direction

local function add_another_room (uid, path, x, y)
   local path = path or {}
   return {uid=uid, path=path, x = x, y = y}
end  -- add_another_room

-- Cache for tile images
local tile_images = {}

-- Helper function to get a tile variation based on variation_num
local function get_tile_variation(base_tile_name, variation_num)
   local dir = GetInfo(66) .. "worlds\\plugins\\images\\"
   local variation_name = string.format("%s_%03d.png", base_tile_name, variation_num)
   local base_variation = base_tile_name .. ".png"

   -- Attempt to load the specific variation
   if tile_images[variation_name] == nil then
       local imgpath = dir .. variation_name
       if WindowLoadImage(win, variation_name, imgpath) == 0 then
           tile_images[variation_name] = variation_name -- Cache the valid image
       else
           tile_images[variation_name] = false -- Cache as not found
       end
   end

   if tile_images[variation_name] then
       return tile_images[variation_name]
   else
       -- Fallback to base tile if specific variation is not found
       if tile_images[base_variation] == nil then
           local base_imgpath = dir .. base_variation
           if WindowLoadImage(win, base_variation, base_imgpath) == 0 then
               tile_images[base_variation] = base_variation -- Cache the valid image
           else
               tile_images[base_variation] = false -- Cache as not found
           end
       end

       if tile_images[base_variation] then
           return tile_images[base_variation]
       else
           return nil -- Optionally, return a default image or handle the missing base tile
       end
   end
end


function draw_room(uid, path, x, y)
   local coords = string.format("%i,%i", math.floor(x), math.floor(y))
   drawn_coords[coords] = uid

   -- If we already drew this room, skip
   if drawn[uid] then
      return
   end
   drawn[uid] = { coords = coords, path = path }

   local room = rooms[uid] or get_room(uid)
   rooms[uid] = room

   local left   = x - HALF_ROOM
   local top    = y - HALF_ROOM
   local right  = x + HALF_ROOM
   local bottom = y + HALF_ROOM

   -- Off-screen check
   if (x < HALF_ROOM)
      or (y < (title_bottom or font_height) + HALF_ROOM)
      or (x > config.WINDOW.width - HALF_ROOM)
      or (y > config.WINDOW.height - HALF_ROOM)
   then
      return
   end

   ----------------------------------------------------------------------------
   -- Gather connector lines for later
   ----------------------------------------------------------------------------
   local lines_to_draw  = {}
   local arrows_to_draw = {}

   for dir, exit_uid in pairs(room.exits) do
      -- For non-up/down exits, honor the show_up_down flag.
      if (dir == "u" or dir == "d") and not show_up_down then
         -- We do NOT queue neighbor rooms or connector lines for up/down exits when disabled,
         -- but we still want to draw the arrow later.
         if false then goto continue end
      end

      local exit_info      = connectors[dir]
      local stub_exit_info = half_connectors[dir]
      local locked_exit    = false
      local arrow          = arrows[dir]
      local exit_color     = EXIT_COLOUR.colour  -- Default color for exits

      -- Special color for up/down exits
      if dir == "u" or dir == "d" then
         exit_color = EXIT_COLOUR_UP_DOWN.colour
      end

      if exit_info then
         local linetype  = miniwin.pen_solid
         local linewidth = locked_exit and 2 or 1

         if not rooms[exit_uid] then
            rooms[exit_uid] = get_room(exit_uid)
         end

         if rooms[exit_uid].unknown then
            linetype = miniwin.pen_dot
         end

         local next_x = x + exit_info.at[1] * (ROOM_SIZE + DISTANCE_TO_NEXT_ROOM)
         local next_y = y + exit_info.at[2] * (ROOM_SIZE + DISTANCE_TO_NEXT_ROOM)

         -- Add vertical offset for up/down exits when drawing
         if dir == "u" then
            next_y = next_y - (ROOM_SIZE * 2)
         elseif dir == "d" then
            next_y = next_y + (ROOM_SIZE * 2)
         end

         local next_coords = string.format("%i,%i", math.floor(next_x), math.floor(next_y))

         if drawn_coords[next_coords] and drawn_coords[next_coords] ~= exit_uid then
            exit_info = stub_exit_info
         elseif exit_uid == uid then
            exit_info = stub_exit_info
            linetype  = miniwin.pen_dash
         else
            -- Only queue neighbor rooms if show_up_down is true or if not an up/down exit.
            if not ((dir == "u" or dir == "d") and not show_up_down) then
               local new_path = copytable.deep(path)
               table.insert(new_path, {dir = dir, uid = exit_uid})
               table.insert(rooms_to_be_drawn, {uid = exit_uid, path = new_path, x = next_x, y = next_y})
               drawn_coords[next_coords] = exit_uid
               plan_to_draw[exit_uid] = next_coords
            end
         end

         -- For non-up/down exits, add the connector line (or if up/down exits are enabled)
         if (dir ~= "u" and dir ~= "d") or show_up_down then
            table.insert(lines_to_draw, {
               x + exit_info.x1, y + exit_info.y1,
               x + exit_info.x2, y + exit_info.y2,
               exit_color,
               linetype + 0x0200, -- smoothing
               linewidth
            })
         end
      end

      ::continue::
   end

   ----------------------------------------------------------------------------
   -- Draw the tile image/fill UNDER the borders
   ----------------------------------------------------------------------------
   if room.unknown then
      WindowCircleOp(
          win, miniwin.circle_rectangle,
          left, top, right, bottom,
          UNKNOWN_ROOM_COLOUR.colour,
          miniwin.pen_dot, 1,
          0, miniwin.brush_hatch_forwards_diagonal
      )
   else
      local tile_mode = GetPluginVariable("b6eae87ccedd84f510b74714", "tile_mode") or "1"
      local tileName  = room.terrain
      if tileName and tileName ~= "" and tile_mode == "1" then
          local variation_num = (uid % 10 == 0) and 10 or (uid % 10)
          local variation_tile = get_tile_variation(tileName, variation_num)
          if variation_tile then
              WindowDrawImage(win, variation_tile, left, top, right, bottom, miniwin.image_stretch)
          end
      else
          WindowCircleOp(
              win, miniwin.circle_rectangle,
              left, top, right, bottom,
              0, miniwin.pen_null, 0,
              room.fillcolour, room.fillbrush
          )
      end
  end

   if room.notes and room.notes ~= "" then
      local highlight_width = 3
      WindowCircleOp(
          win, miniwin.circle_rectangle,
          left + highlight_width, top + highlight_width,
          right - highlight_width, bottom - highlight_width,
          ROOM_NOTE_COLOUR.colour,
          miniwin.pen_solid, highlight_width,
          -1, miniwin.brush_null
      )
   end

   ----------------------------------------------------------------------------
   -- Handle special rooms: shops, guild trainers, etc.
   ----------------------------------------------------------------------------
   local special_room = false

   if room.building and room.building ~= "" then
       local building_map = {
           ["waypoint"] = { image = "waypoint",       fill = WAYPOINT_FILL_COLOUR.colour },
           ["weaponshop"] = { image = "weaponshop",   fill = REGULAR_FILL_COLOUR.colour },
           ["armorshop"] = { image = "armorshop",     fill = REGULAR_FILL_COLOUR.colour },
           ["foodshop"] = { image = "foodshop",       fill = REGULAR_FILL_COLOUR.colour },
           ["itemshop"] = { image = "itemshop",       fill = REGULAR_FILL_COLOUR.colour },
           ["petshop"] = { image = "petshop",         fill = REGULAR_FILL_COLOUR.colour },
           ["lightshop"] = { image = "lightshop",     fill = REGULAR_FILL_COLOUR.colour },
           ["forge"] = { image = "forge",             fill = FORGE_FILL_COLOUR.colour },
       }

       for building_type, data in pairs(building_map) do
           if string.match(room.building, building_type) then
               special_room = true
               WindowDrawImage(win, data.image, left, top, right, bottom, miniwin.image_stretch)
               WindowCircleOp(
                   win, miniwin.circle_rectangle,
                   left - 2 - room.borderpenwidth, top - 2 - room.borderpenwidth,
                   right + 2 + room.borderpenwidth, bottom + 2 + room.borderpenwidth,
                   data.fill,
                   room.borderpen, room.borderpenwidth,
                   -1, miniwin.brush_null
               )
               break
           end
       end
   end

   if not special_room and room.name and room.name ~= "" then
       local name_map = {
           ["The Warriors Guild"]    = { image = "warriortrainer",      fill = WARRIOR_TRAINER_FILL_COLOUR.colour },
           ["The Clerics Guild"]     = { image = "clerictrainer",       fill = CLERIC_TRAINER_FILL_COLOUR.colour },
           ["The Mages Guild"]       = { image = "magetrainer",         fill = MAGE_TRAINER_FILL_COLOUR.colour },
           ["The Psionicists Guild"] = { image = "necromancertrainer",  fill = NECRO_TRAINER_FILL_COLOUR.colour },
           ["The Thieves Guild"]     = { image = "thieftrainer",        fill = THIEF_TRAINER_FILL_COLOUR.colour },
           ["Krynn Bank"]            = { image = "bank",                fill = BANK_FILL_COLOUR.colour },
       }

       for name_type, data in pairs(name_map) do
           if string.match(room.name, name_type) then
               special_room = true
               WindowDrawImage(win, data.image, left, top, right, bottom, miniwin.image_stretch)
               break
           end
       end
   end

   ----------------------------------------------------------------------------
   -- Draw the tile borders AFTER images, with bright yellow, skipping sides w/ exits
   ----------------------------------------------------------------------------
   local neighbor_offset = {
      n = {0, -(ROOM_SIZE + DISTANCE_TO_NEXT_ROOM)},
      s = {0,  (ROOM_SIZE + DISTANCE_TO_NEXT_ROOM)},
      e = {(ROOM_SIZE + DISTANCE_TO_NEXT_ROOM),  0},
      w = {-(ROOM_SIZE + DISTANCE_TO_NEXT_ROOM), 0},
   }

   local border_color = ColourNameToRGB("white")
   local border_pen   = miniwin.pen_solid
   local border_width = 3

   for dir, coords in pairs(barriers) do
      if (dir == "n" or dir == "s" or dir == "e" or dir == "w") then
         if not room.exits[dir] then
            local nx = x + neighbor_offset[dir][1]
            local ny = y + neighbor_offset[dir][2]
            local neighbor_coords = string.format("%i,%i", math.floor(nx), math.floor(ny))
            local neighbor_uid = drawn_coords[neighbor_coords]
            if neighbor_uid then
               local neighbor_room = rooms[neighbor_uid]
               if neighbor_room and neighbor_room.exits[inverse_direction[dir]] == uid then
                  goto skip_border
               end
            end

            WindowLine(
               win,
               x + coords.x1, y + coords.y1,
               x + coords.x2, y + coords.y2,
               border_color,
               border_pen,
               border_width
            )

            ::skip_border::
         end
      end
   end

   ----------------------------------------------------------------------------
   -- Draw all connector lines & arrows last (on top)
   ----------------------------------------------------------------------------
   for _, ln in ipairs(lines_to_draw) do
      local x1, y1, x2, y2, color, penstyle, width = unpack(ln)
      WindowLine(win, x1, y1, x2, y2, color, penstyle, width)
   end

   -- Draw arrows from the earlier loop
   for _, arr in ipairs(arrows_to_draw) do
      local ax1, ay1, ax2, ay2, ax3, ay3, color = unpack(arr)
      local points = string.format("%i,%i,%i,%i,%i,%i", ax1, ay1, ax2, ay2, ax3, ay3)
      WindowPolygon(win, points,
         color, miniwin.pen_solid, 1,
         color, miniwin.brush_solid,
         true, true)
   end

   ----------------------------------------------------------------------------
   -- Highlight current room (draw on top of everything)
   ----------------------------------------------------------------------------
   if uid == current_room then
      local char_alpha = 1
      if room.exits["u"] or room.exits["d"] then
         char_alpha = 0.7  -- make it slightly transparent if an up/down exit exists
      end
      draw_scaled_image_alpha(win, GetInfo(66) .. "worlds\\plugins\\images\\character.png", "character", x, y, ROOM_SIZE, char_alpha, 32)
   end

   ----------------------------------------------------------------------------
   -- Mouse hotspot
   ----------------------------------------------------------------------------
   WindowAddHotspot(
      win, uid,
      left, top, right, bottom,
      "", "", "", "",
      "mapper.mouseup_room",
      room.hovermessage,
      miniwin.cursor_hand, 0
   )
   WindowScrollwheelHandler(win, uid, "mapper.zoom_map")
   
   ----------------------------------------------------------------------------
   -- Always draw up/down arrows (even if neighbor processing was skipped)
   ----------------------------------------------------------------------------
   for dir, exit_uid in pairs(room.exits) do
      if dir == "u" or dir == "d" then
         -- Use smaller multipliers so the arrow is not huge.
         local base_offset = ROOM_SIZE * 0.35      -- inset from the tile edge
         local half_base   = ROOM_SIZE * 0.2      -- half the base width (~40% of ROOM_SIZE total)
         local height      = (ROOM_SIZE * 0.3) * 0.866  -- equilateral triangle height
         local arrow = {}
         if dir == "u" then
            arrow = { -half_base, -HALF_ROOM + base_offset,
                      half_base,  -HALF_ROOM + base_offset,
                      0,          -HALF_ROOM + base_offset - height }
         else
            arrow = { -half_base, HALF_ROOM - base_offset,
                      half_base,  HALF_ROOM - base_offset,
                      0,          HALF_ROOM - base_offset + height }
         end
         local arrow_color = (dir == "u" and ColourNameToRGB("magenta")) or (dir == "d" and ColourNameToRGB("red"))
         table.insert(arrows_to_draw, {
            x + arrow[1], y + arrow[2],
            x + arrow[3], y + arrow[4],
            x + arrow[5], y + arrow[6],
            arrow_color
         })
         -- Draw the newly added arrow immediately
         local ax1, ay1, ax2, ay2, ax3, ay3, color = unpack(arrows_to_draw[#arrows_to_draw])
         local points = string.format("%i,%i,%i,%i,%i,%i", ax1, ay1, ax2, ay2, ax3, ay3)
         
         -- Draw subtle dark outline first for up/down arrows
            WindowPolygon(win, points,
               0x404040, miniwin.pen_solid, 1,
               -1, miniwin.brush_null,
               true, true)
         
         -- Draw the main colored arrow on top
         WindowPolygon(win, points,
            color, miniwin.pen_null, 0,
            color, miniwin.brush_solid,
            true, true)
      end
   end
end



local function changed_room (uid)
   if current_speedwalk then
      if uid ~= expected_room then
         local exp = rooms [expected_room]
         if not exp then
            exp = get_room (expected_room) or { name = expected_room }
         end -- if
         local here = rooms [uid]
         if not here then
            here = get_room (uid) or { name = uid }
         end -- if
         exp = expected_room
         here = uid
         maperror (string.format ("Speedwalk failed! Expected to be in '%s' but ended up in '%s'.", exp, here))
         cancel_speedwalk ()
      else
         if #current_speedwalk > 0 then
            local dir = table.remove (current_speedwalk, 1)
            SetStatus ("Walking " .. (expand_direction [dir.dir] or dir.dir) ..
               " to " .. walk_to_room_name ..
               ". Speedwalks to go: " .. #current_speedwalk + 1)
            expected_room = dir.uid
            Send (dir.dir)
         else
            last_hyperlink_uid = nil
            last_speedwalk_uid = nil
            if show_completed then
               mapprint ("Speedwalk completed.")
            end -- if wanted
            cancel_speedwalk ()
         end -- if any left
      end -- if expected room or not
   end -- if have a current speedwalk
end -- changed_room

local function draw_zone_exit (exit)
   local x, y, def = exit.x, exit.y, exit.def
   local offset = ROOM_SIZE

   WindowLine (win, x + def.x1, y + def.y1, x + def.x2, y + def.y2, ColourNameToRGB("yellow"), miniwin.pen_solid + 0x0200, 5)
   WindowLine (win, x + def.x1, y + def.y1, x + def.x2, y + def.y2, ColourNameToRGB("green"), miniwin.pen_solid + 0x0200, 1)
end --  draw_zone_exit


----------------------------------------------------------------------------------
--  EXPOSED FUNCTIONS
----------------------------------------------------------------------------------

-- can we find another room right now?

function check_we_can_find ()
   if not current_room then
      mapprint ("I don't know where you are right now - try: LOOK")
      check_connected ()
      return false
   end
   if current_speedwalk then
      mapprint ("The mapper has detected a speedwalk initiated inside another speedwalk. Aborting.")
      return false
   end -- if
   return true
end -- check_we_can_find

-- draw our map starting at room: uid
dont_draw = false
function halt_drawing(halt)
   dont_draw = halt
end

blink_cycle = {
   "@R",
   "@Y",
   "@W"
}
function blink_title()
   next_blink_color = (next_blink_color % (#blink_cycle)) + 1
   title_color = blink_cycle[next_blink_color]
   dress_window(truncated_room_name, current_room, current_area)
   CallPlugin("abc1a0944ae4af7586ce88dc", "BufferedRepaint")
end

function dress_window(room_name, room_uid, area_name)
   bodyleft, bodytop, bodyright, bodybottom = Theme.DressWindow(win, FONT_ID, title_color..room_name, "center")

   -- room ID number
   if config.SHOW_ROOM_ID then
      Theme.DrawTextBox(win, FONT_ID,
         (config.WINDOW.width - WindowTextWidth (win, FONT_ID, "ID: "..room_uid)) / 2,   -- left
         bodytop,    -- top
         "ID: "..room_uid, false, false
      )
   end

   -- area name
   if area_name then
      Theme.DrawTextBox(win, FONT_ID,
         (config.WINDOW.width - WindowTextWidth (win, FONT_ID, area_name)) / 2,   -- left
         config.WINDOW.height - 4 - font_height,    -- top
         area_name:gsub("^%l", string.upper), false, false
      )
   end

   -- help button
   if type (show_help) == "function" then
      local x = config.WINDOW.width - WindowTextWidth (win, FONT_ID, "?") - 6
      local y = math.max(2, (bodytop-font_height)/2)
      local text_width = Theme.DrawTextBox(win, FONT_ID,
         x-1,   -- left
         y-2,   -- top
         "?", false, false
      )

      WindowAddHotspot(win, "<help>",
         x-3, y-4, x+text_width+3, y + font_height,   -- rectangle
         "",  -- mouseover
         "",  -- cancelmouseover
         "",  -- mousedown
         "",  -- cancelmousedown
         "mapper.show_help",  -- mouseup
         "Click for help",
         miniwin.cursor_help, 0
      )
   end -- if

   -- configuration
   if draw_configure_box then
      -- dropdown
      draw_configuration ()
   else
      -- button
      WindowShow(config_win, false)
      local x = 2
      local y = math.max(2, (bodytop-font_height)/2)
      local text_width = Theme.DrawTextBox(win, FONT_ID,
         x,   -- left
         y-2,   -- top
         "*", false, false)

      WindowAddHotspot(win, "<configure>",
         x-2, y-4, x+text_width, y + font_height,   -- rectangle
         "",  -- mouseover
         "",  -- cancelmouseover
         "",  -- mousedown
         "",  -- cancelmousedown
         "mapper.mouseup_configure",  -- mouseup
         "Click to configure map",
         miniwin.cursor_plus, 0)
   end
end

local image_data = {}
local loaded_images = {}

local function preload_images()
    local image_files = {
        "inside", "town", "forest", "field", "lightforest", "thickforest", "darkforest",
        "swamp", "sandy", "mountain", "rock", "desert", "tundra", "beach",
        "hills", "ocean", "stream", "ice", "cave", "city", "wasteland", "water",
        "taiga", "road", "ruins", "developed", "lava", "hellfountain", "bank",
        "fountain", "quest", "waypoint", "warriortrainer", "thieftrainer",
        "druidtrainer", "clerictrainer", "magetrainer", "necromancertrainer",
        "rangertrainer", "shop", "priest", "alchemyguild", "gato", "moti",
        "weaponshop", "armorshop", "petshop", "itemshop", "foodshop",
        "lightshop", "inn", "tavern", "dungeon", "crypt", "underground", "underwater", "swim"
    }

    for _, image in ipairs(image_files) do
        local f = assert(io.open("worlds/plugins/images/" .. image .. ".png", "rb"))
        image_data[image] = f:read("*a")  -- read all of it
        f:close()  -- close the file
    end
end

local function load_image_if_needed(win, image_id)
    if not loaded_images[image_id] then
        WindowLoadImageMemory(win, image_id, image_data[image_id])
        loaded_images[image_id] = true
    end
end

local function draw_image(win, image_id, left, top, right, bottom, color)
    load_image_if_needed(win, image_id)
    WindowDrawImage(win, image_id, left, top, right, bottom, miniwin.image_stretch)
    if color then
        WindowCircleOp(win, miniwin.circle_rectangle, left - 2, top - 2, right + 2, bottom + 2, color, miniwin.pen_solid, 1, -1, miniwin.brush_null)
    end
end

preload_images()


function draw(uid)
   if not uid then
       maperror "Cannot draw map right now, I don't know where you are - try: LOOK"
       return
   end -- if

   if current_room and current_room ~= uid then
       changed_room(uid)
   end -- if

   current_room = uid -- remember where we are

   if dont_draw then
       return
   end

   -- timing
   local start_time = utils.timer()

   -- start with initial room
   rooms = { [uid] = get_room(uid) }

   -- lookup current room
   local room = rooms[uid]

   room = room or { name = "<Unknown room>", area = "<Unknown area>" }
   last_visited[uid] = os.time()

   current_area = room.area

   -- update dimensions and position here because the bigmap might have changed them
   windowinfo.window_left = WindowInfo(win, 1) or windowinfo.window_left
   windowinfo.window_top = WindowInfo(win, 2) or windowinfo.window_top
   config.WINDOW.width = WindowInfo(win, 3) or config.WINDOW.width
   config.WINDOW.height = WindowInfo(win, 4) or config.WINDOW.height

   WindowCreate(win,
       windowinfo.window_left,
       windowinfo.window_top,
       config.WINDOW.width,
       config.WINDOW.height,
       windowinfo.window_mode,   -- top right
       windowinfo.window_flags,
       Theme.PRIMARY_BODY)

   -- Handle loading imagetiles and draw them if they are not already loaded
   local terrains = {
       "inside", "town", "forest", "field", "lightforest", "thickforest", "darkforest",
       "swamp", "sandy", "mountain", "rock", "desert", "tundra", "beach",
       "hills", "ocean", "stream", "ice", "cave", "city", "wasteland", "water",
       "taiga", "road", "ruins", "developed", "lava", "hellfountain", "bank",
       "fountain", "quest", "waypoint", "warriortrainer", "thieftrainer",
       "druidtrainer", "clerictrainer", "magetrainer", "necromancertrainer",
       "rangertrainer", "shop", "priest", "alchemyguild", "gato", "moti",
       "weaponshop", "armorshop", "petshop", "itemshop", "foodshop",
       "lightshop", "inn", "tavern", "dungeon", "crypt", "underground", "underwater", "swim"
   }

   for _, terrain in ipairs(terrains) do
       load_image_if_needed(win, terrain)
   end

   -- Handle background texture.
   if room.textimage ~= nil and config.USE_TEXTURES.enabled == true then
       local iwidth = WindowImageInfo(win, room.textimage, 2)
       local iheight = WindowImageInfo(win, room.textimage, 3)
       local x = 0
       local y = 0

       while y < config.WINDOW.height do
           x = 0
           while x < config.WINDOW.width do
               WindowDrawImage(win, room.textimage, x, y, 0, 0, 1)  -- straight copy
               x = x + iwidth
           end
           y = y + iheight
       end
   end

   -- for zooming
   WindowAddHotspot(win,
       "zzz_zoom",
       0, 0, 0, 0,
       "", "", "", "", "mapper.MouseUp",
       "",  -- hint
       miniwin.cursor_arrow, 0)

   WindowScrollwheelHandler(win, "zzz_zoom", "mapper.zoom_map")

   -- set up for initial room, in middle
   drawn, drawn_coords, rooms_to_be_drawn, plan_to_draw, area_exits = {}, {}, {}, {}, {}, {}
   depth = 0

   -- insert initial room
   table.insert(rooms_to_be_drawn, add_another_room(uid, {}, config.WINDOW.width / 2, config.WINDOW.height / 2))

   while #rooms_to_be_drawn > 0 and depth < config.SCAN.depth do
       local old_generation = rooms_to_be_drawn
       rooms_to_be_drawn = {}  -- new generation
       for i, part in ipairs(old_generation) do
           draw_room(part.uid, part.path, part.x, part.y)
       end -- for each existing room
       depth = depth + 1
   end -- while all rooms_to_be_drawn

   for area, zone_exit in pairs(area_exits) do
       draw_zone_exit(zone_exit)
   end -- for

   truncated_room_name = room.name
   local name_width = WindowTextWidth(win, FONT_ID, truncated_room_name)
   local add_dots = false

   -- truncate name if too long
   local available_width = (config.WINDOW.width - 20 - WindowTextWidth(win, FONT_ID, "*?"))
   while name_width > available_width do
       truncated_room_name = truncated_room_name:sub(1, -3)
       name_width = WindowTextWidth(win, FONT_ID, truncated_room_name .. "...")
       add_dots = true
       if truncated_room_name == "" then
           break
       end
   end -- while

   if add_dots then
       truncated_room_name = truncated_room_name .. "..."
   end -- if

   is_pk = false
   if room.info then
       for _, v in ipairs(utils.split(room.info, ",")) do
           if v == "pk" then
               is_pk = true
               break
           end
       end
   end

   title_color = ""
   next_blink_color = 0
   if not is_pk then
       DeleteTimer("blink_title")
   else
       blink_title()
       AddTimer("blink_title", 0, 0, 0.5, "", timer_flag.Enabled + timer_flag.Temporary + timer_flag.Replace, "mapper.blink_title")
   end

   dress_window(truncated_room_name, uid, room.area)

   Theme.AddResizeTag(win, 1, nil, nil, "mapper.resize_mouse_down", "mapper.resize_move_callback", "mapper.resize_release_callback")

   -- make sure window visible
   WindowShow(win, not window_hidden)

   last_drawn = uid  -- last room number we drew (for zooming)

   local end_time = utils.timer()

   -- timing stuff
   if timing then
       local count = 0
       for k in pairs(drawn) do
           count = count + 1
       end
       print(string.format("Time to draw %i rooms = %0.3f seconds, search depth = %i", count, end_time - start_time, depth))

       total_times_drawn = total_times_drawn + 1
       total_time_taken = total_time_taken + end_time - start_time

       print(string.format("Total times map drawn = %i, average time to draw = %0.3f seconds",
           total_times_drawn,
           total_time_taken / total_times_drawn))
   end -- if

   CallPlugin("abc1a0944ae4af7586ce88dc", "BufferedRepaint")
end -- draw

local credits = {
   "MUSHclient mapper",
   string.format ("Version %0.1f", VERSION),
   "Made for Aardwolf by Fiendish",
   "Based on work by Nick Gammon",
   "World: "..WorldName (),
   GetInfo (3),
}

-- call once to initialize the mapper
function init (t)

   -- make copy of colours, sizes etc.
   findpath = t.findpath
   config = t.config
   assert (type (config) == "table", "No 'config' table supplied to mapper.")

   supplied_get_room = t.get_room
   assert (type (supplied_get_room) == "function", "No 'get_room' function supplied to mapper.")

   show_help = t.show_help     -- "help" function
   room_click = t.room_click   -- RH mouse-click function
   timing = t.timing           -- true for timing info
   show_completed = t.show_completed  -- true to show "Speedwalk completed." message
   show_other_areas = t.show_other_areas  -- true to show other areas
   show_up_down = t.show_up_down        -- true to show up or down
   speedwalk_prefix = t.speedwalk_prefix  -- how to speedwalk (prefix)

   -- force some config defaults if not supplied
   for k, v in pairs (default_config) do
      config[k] = config[k] or v
   end -- for

   win = GetPluginID () .. "_mapper"
   config_win = GetPluginID () .. "_z_config_win"

   WindowCreate (win, 0, 0, 0, 0, 0, 0, 0)
   WindowCreate(config_win, 0, 0, 0, 0, 0, 0, 0)

   -- add the fonts
   WindowFont (win, FONT_ID, config.FONT.name, config.FONT.size)
   WindowFont (win, FONT_ID_UL, config.FONT.name, config.FONT.size, false, false, true)
   WindowFont (config_win, CONFIG_FONT_ID, config.FONT.name, config.FONT.size)
   WindowFont (config_win, CONFIG_FONT_ID_UL, config.FONT.name, config.FONT.size, false, false, true)

   -- see how high it is
   font_height = WindowFontInfo (win, FONT_ID, 1)  -- height

   -- find where window was last time
   windowinfo = movewindow.install (win, miniwin.pos_bottom_right, miniwin.create_absolute_location , true, {config_win}, {mouseup=MouseUp, mousedown=LeftClickOnly, dragmove=LeftClickOnly, dragrelease=LeftClickOnly}, {x=default_x, y=default_y})

   -- calculate box sizes, arrows, connecting lines etc.
   build_room_info ()

   WindowCreate (win,
      windowinfo.window_left,
      windowinfo.window_top,
      config.WINDOW.width,
      config.WINDOW.height,
      windowinfo.window_mode,   -- top right
      windowinfo.window_flags,
      Theme.PRIMARY_BODY)

   -- let them move it around
   movewindow.add_drag_handler (win, 0, 0, 0, 0)

   local top = (config.WINDOW.height - #credits * font_height) /2

   for _, v in ipairs (credits) do
      local width = WindowTextWidth (win, FONT_ID, v)
      local left = (config.WINDOW.width - width) / 2
      WindowText (win, FONT_ID, v, left, top, 0, 0, Theme.BODY_TEXT)
      top = top + font_height
   end -- for

   Theme.DrawBorder(win)
   Theme.AddResizeTag(win, 1, nil, nil, "mapper.resize_mouse_down", "mapper.resize_move_callback", "mapper.resize_release_callback")

   WindowShow (win, not window_hidden)
   WindowShow (config_win, false)

end -- init

function MouseUp(flags, hotspot_id, win)
   if bit.band (flags, miniwin.hotspot_got_rh_mouse) ~= 0 then
      right_click_menu()
   end
   return true
end

function LeftClickOnly(flags, hotspot_id, win)
   if bit.band (flags, miniwin.hotspot_got_rh_mouse) ~= 0 then
      return true
   end
   return false
end

function right_click_menu()
   menustring = "Bring To Front|Send To Back"

   rc, a, b, c = CallPlugin("60840c9013c7cc57777ae0ac", "getCurrentState")
   if rc == 0 and a == true then
      if b == 1 then
         menustring = menustring.."|-|Show Continent Bigmap"
      elseif c == 1 then
         menustring = menustring.."|-|Merge Continent Bigmap Into GMCP Mapper"
      end
   end

   result = WindowMenu (win,
      WindowInfo (win, 14),  -- x position
      WindowInfo (win, 15),   -- y position
      menustring) -- content
   if result == "Bring To Front" then
      CallPlugin("462b665ecb569efbf261422f","boostMe", win)
   elseif result == "Send To Back" then
      CallPlugin("462b665ecb569efbf261422f","dropMe", win)
   elseif result == "Show Continent Bigmap" then
      Execute("bigmap on")
   elseif result == "Merge Continent Bigmap Into GMCP Mapper" then
      Execute("bigmap merge")
   end
end

function zoom_in ()
   if last_drawn and ROOM_SIZE < 40 then
      ROOM_SIZE = ROOM_SIZE + 2
    --  DISTANCE_TO_NEXT_ROOM = DISTANCE_TO_NEXT_ROOM + 2
      build_room_info ()
      draw (last_drawn)
      SaveState()
   end -- if
end -- zoom_in


function zoom_out ()
   if last_drawn and ROOM_SIZE > 4 then
      ROOM_SIZE = ROOM_SIZE - 2
  --    DISTANCE_TO_NEXT_ROOM = DISTANCE_TO_NEXT_ROOM - 2
      build_room_info ()
      draw (last_drawn)
      SaveState()
   end -- if
end -- zoom_out

function mapprint (...)
   local old_note_colour = GetNoteColourFore ()
   SetNoteColourFore(MAPPER_NOTE_COLOUR.colour)
   print (...)
   SetNoteColourFore (old_note_colour)
end -- mapprint

function maperror (...)
   local old_note_colour = GetNoteColourFore ()
   SetNoteColourFore(ColourNameToRGB "red")
   print (...)
   SetNoteColourFore (old_note_colour)
end -- maperror

function show()
   WindowShow(win, true)
   hidden = false
end -- show

function hide()
   WindowShow(win, false)
   hidden = true
end -- hide

function save_state ()
   SetVariable("ROOM_SIZE", ROOM_SIZE)
   SetVariable("DISTANCE_TO_NEXT_ROOM", DISTANCE_TO_NEXT_ROOM)
   if WindowInfo(win,1) and WindowInfo(win,5) then
      movewindow.save_state (win)
      config.WINDOW.width = WindowInfo(win, 3)
      config.WINDOW.height = WindowInfo(win, 4)
   end
end -- save_state

function hyperlinkGoto(uid)
   mapper.goto(uid)
   for i,v in ipairs(last_result_list) do
      if uid == v then
         next_result_index = i
         break
      end
   end
end

require "serialize"
function full_find(dests, show_uid, expected_count, walk, fcb, no_portals)
   local start_time = utils.timer()  -- Start the timer
   local paths = {}
   local notfound = {}
   for i,v in ipairs(dests) do
       SetStatus (string.format ("Pathfinding: searching for route to %i/%i discovered destinations", i, #dests))
       CallPlugin("abc1a0944ae4af7586ce88dc", "BufferedRepaint")
       local foundpath = findpath(current_room, v.uid, no_portals, no_portals)
       if not rooms [v.uid] then
           rooms [v.uid] = get_room (v.uid)
       end
       if foundpath ~= nil then
           paths[v.uid] = {path=foundpath, reason=v.reason}
       else
           table.insert(notfound, {uid=v.uid, reason=v.reason})
       end
   end
   SetStatus ("")

   BroadcastPlugin(500, "found_paths = "..string.gsub(serialize.save_simple(paths),"%s+"," "))
   BroadcastPlugin(501, "unfound_paths = "..string.gsub(serialize.save_simple(notfound),"%s+"," "))

   local t = {}
   local found_count = 0
   for k in pairs (paths) do
       table.insert (t, k)
       found_count = found_count + 1
   end -- for

   -- sort so closest ones are first
   table.sort (t, function (a, b) return #paths [a].path < #paths [b].path end )

   if walk and t[1] then
       local uid = t[1]
       local path = paths[uid].path
       mapprint ("Going to:", rooms[uid].name)
       start_speedwalk(path)
       return
   end -- if walking wanted

   utilprint("$x238+------------------------------ $x208START OF SEARCH$x238 -------------------------------+")
   for _, uid in ipairs (t) do
       local room = rooms [uid] -- ought to exist or wouldn't be in table
       assert (room, "Room " .. uid .. " is not in rooms table.")

       local distance = #paths [uid].path .. " room"
       if #paths [uid].path > 1 or #paths[uid].path == 0 then
           distance = distance .. "s"
       end -- if
       distance = distance .. " away"

       local room_name = room.name
       room_name = room_name .. " (" .. room.area .. ")"

       if show_uid then
           room_name = room_name .. " (" .. uid .. ")"
       end -- if

       table.insert(last_result_list, uid)
       local TextColor, BackgroundColor
       if (#last_result_list % 2 == 0) then
           TextColor = "grey"
           BackgroundColor = "#1F170F"
       else
           TextColor = "grey"
           BackgroundColor = "black"
       end

       Hyperlink ("!!" .. GetPluginID () .. ":mapper.hyperlinkGoto(" .. uid .. ")",
           "["..#last_result_list.."] "..room_name, "Click to speedwalk there (" .. distance .. ")", TextColor, BackgroundColor, false, NoUnderline_hyperlinks)
       
       local info = ""
       if type (paths [uid].reason) == "string" and paths [uid].reason ~= "" then
           info = " [" .. paths [uid].reason .. "]"
       end -- if
       mapprint (" - " .. distance .. info) -- new line

       -- callback to display extra stuff (like find context, room description)
       if fcb then
           fcb (uid)
       end -- if callback
   end -- for each room

   if expected_count and found_count < expected_count then
       local diff = expected_count - found_count
       local were, matches = "were", "matches"
       if diff == 1 then
           were, matches = "was", "match"
       end -- if
       utilprint("$x238+------------------------------------------------------------------------------+")
       mapprint ("There", were, diff, matches,
           "which I could not find a path to within",
           config.SCAN.depth, "rooms:")
   end -- if
   for i,v in ipairs(notfound) do
       local nfroom = rooms[v.uid]
       local nfline = nfroom.name
       nfline = nfline .. " (" .. nfroom.area .. ")"

       if show_uid then
           nfline = nfline .. " (" .. v.uid .. ")"
       end -- if
       Tell(nfline)
       if type (v.reason) == "string" and v.reason ~= "" then
           nfinfo = " - [" .. v.reason .. "]"
           mapprint (nfinfo) -- new line
       else
           Note("")
       end -- if
   end

   utilprint("$x238+-------------------------------- $x208END OF SEARCH$x238 -------------------------------+")
   local end_time = utils.timer()  -- End the timer
   print(string.format("Full search took %.3f seconds.", end_time - start_time))
end

function quick_find(dests, show_uid, expected_count, walk, fcb)
   local start_time = utils.timer()  -- Start the timer
   CallPlugin("abc1a0944ae4af7586ce88dc", "BufferedRepaint")
   utilprint("$x238+------------------------------ $x208START OF SEARCH$x238 -------------------------------+")

   local paths = {}
   for i,v in ipairs(dests) do
       local uid = v.uid
       if not rooms[uid] then
           rooms[uid] = get_room(uid)
       end -- if
       local foundpath = findpath(current_room, uid, false, false)
       if foundpath ~= nil then
           paths[uid] = {path=foundpath, reason=v.reason}
       end
   end

   for i,v in ipairs(dests) do
       local uid = v.uid
       local room = rooms[uid] -- ought to exist or wouldn't be in table

       assert(room, "Room " .. v.uid .. " is not in rooms table.")

       local room_name = room.name
       room_name = room_name .. " (" .. room.area .. ")"
       if show_uid then
           room_name = room_name .. " (" .. v.uid .. ")"
       end

       local distance, distColor
       if paths[uid] then
           distance = #paths[uid].path .. " room" .. (#paths[uid].path > 1 and "s" or "") .. " away"
           distColor = "springgreen"
       else
           distance = "Unreachable"
           distColor = "darkorange"
       end

       table.insert(last_result_list, v.uid)
       local TextColor, BackgroundColor
       if (#last_result_list % 2 == 0) then
           TextColor = "grey"
           BackgroundColor = "#1F170F"
       else
           TextColor = "grey"
           BackgroundColor = "black"
       end

       if current_room ~= v.uid then
           Hyperlink("!!" .. GetPluginID () .. ":mapper.hyperlinkGoto(" .. v.uid .. ")",
               "[" .. #last_result_list .. "] " .. room_name, "Click to speedwalk there (" .. distance .. ")", TextColor, BackgroundColor, false, NoUnderline_hyperlinks)
           ColourTell(TextColor, BackgroundColor, " - ")
           ColourTell(distColor, BackgroundColor, distance .. "")
       else
           ColourTell(RGBColourToName(MAPPER_NOTE_COLOUR.colour), "", "[you are here] " .. room_name)
       end

       local info = ""
       if type(v.reason) == "string" and v.reason ~= "" then
           info = " [" .. v.reason .. "]"
           ColourTell(TextColor, BackgroundColor, " - " .. info .. "\n")
       else -- if
           ColourTell(TextColor, BackgroundColor, "\n")
       end

       -- callback to display extra stuff (like find context, room description)
       if fcb then
           fcb(uid)
       end -- if callback

       CallPlugin("abc1a0944ae4af7586ce88dc", "BufferedRepaint")
   end -- for each room

   utilprint("$x238+-------------------------------- $x208END OF SEARCH$x238 -------------------------------+")
   local end_time = utils.timer()  -- End the timer
   print(string.format("Quick search took %.3f seconds.", end_time - start_time))
end


function gotoNextResult(which)
   if tonumber(which) == nil then
      if next_result_index ~= nil then
         next_result_index = next_result_index+1
         if next_result_index <= #last_result_list then
            mapper.goto(last_result_list[next_result_index])
            return
         else
            next_result_index = nil
         end
      end
      ColourNote(RGBColourToName(MAPPER_NOTE_COLOUR.colour),"","NEXT ERROR: No more NEXT results left.")
   else
      next_result_index = tonumber(which)
      if (next_result_index > 0) and (next_result_index <= #last_result_list) then
         mapper.goto(last_result_list[next_result_index])
         return
      else
         ColourNote(RGBColourToName(MAPPER_NOTE_COLOUR.colour),"","NEXT ERROR: There is no NEXT result #"..next_result_index..".")
         next_result_index = nil
      end
   end
end

function goto(uid)
   find (nil,
      {{uid=uid, reason=true}},
      0,
      false,  -- show vnum?
      1,          -- how many to expect
      true        -- just walk there
   )
end

-- generic room finder
-- name is for informational purposes only; it's displayed to the user in the search results
-- dests is a list of room/reason pairs where reason is either true (meaning generic) or a string to find
-- if max_paths <= 0 it's disregarded, otherwise number of dests must be <= max_paths
-- show_uid is true if you want the room uid to be displayed
-- expected_count is the number we expect to find (eg. the number found on a database)
-- if 'walk' is true, we walk to the first match rather than displaying hyperlinks
-- if fcb is a function, it is called back after displaying each line
-- quick_list determines whether we pathfind every destination in advance to be able to sort by distance
function find (name, dests, max_paths, show_uid, expected_count, walk, fcb, quick_list, no_portals)
   if not check_we_can_find () then
      return
   end -- if

   if fcb then
      assert (type (fcb) == "function")
   end -- if

   if max_paths <= 0 then
      max_paths = #dests
   end
   if not walk then
      mapprint ("Found",#dests,"target"..(((#dests ~= 1) and "s") or "")..(((name ~= nil) and (" matching '"..name.."'")) or "")..".")
   end
   if #dests > max_paths then
      mapprint(string.format("Your search returned more than %s results. Choose a more specific pattern.", max_paths))
      return
   end

   if not walk then
      last_result_list = {}
      next_result_index = 0
   end

   if quick_list == true then
      quick_find(dests, show_uid, expected_count, walk, fcb)
   else
      full_find(dests, show_uid, expected_count, walk, fcb, no_portals)
   end
end -- map_find_things

-- build a speedwalk from a path into a string

local function build_speedwalk(path, prefix)
    local stack_char = (GetOption("enable_command_stack") == 1) and GetAlphaOption("command_stack_character") or "\r\n"

    -- Build speedwalk string (collect identical directions)
    local tspeed = {}
    for _, dir in ipairs(path) do
        local n = #tspeed
        if n > 0 and expand_direction[dir.dir] ~= nil and tspeed[n].dir == dir.dir then
            tspeed[n].count = tspeed[n].count + 1
        else
            table.insert(tspeed, { dir = dir.dir, count = 1 })
        end
    end

    if #tspeed == 0 then
        return
    end

    -- Build the speedwalk string
    local s = {}
    local new_command = false
    for _, dir in ipairs(tspeed) do
        if expand_direction[dir.dir] ~= nil then
            if new_command then
                table.insert(s, stack_char .. speedwalk_prefix .. " ")
                new_command = false
            end
            if dir.count > 1 then
                table.insert(s, tostring(dir.count))
            end
            table.insert(s, dir.dir)
        else
            table.insert(s, stack_char .. dir.dir)
            new_command = true
        end
    end

    local result = table.concat(s)
    if prefix ~= nil then
        if result:sub(1, #stack_char) == stack_char then
            result = result:sub(#stack_char + 1)
        else
            result = prefix .. " " .. result
        end
    end

    return result, stack_char
end


-- start a speedwalk to a path

function start_speedwalk (path)

   if not check_connected () then
      return
   end -- if

   if myState == 9 or myState == 11 then
      Send("stand")
   end

   if current_speedwalk and #current_speedwalk > 0 then
      mapprint ("You are already speedwalking! (Ctrl + LH-click on any room to cancel)")
      return
   end -- if

   current_speedwalk = path

   if current_speedwalk then
      if #current_speedwalk > 0 then
         last_speedwalk_uid = current_speedwalk [#current_speedwalk].uid

         -- fast speedwalk: just send # 4s 3e  etc.
         if type (speedwalk_prefix) == "string" and speedwalk_prefix ~= "" then
            local s = speedwalk_prefix .. " "
            local p = build_speedwalk (path)
            if p:sub(1,1) ~= stack_char then
               s = s .. p
            else
               s = p:sub(2)
            end
            ExecuteWithWaits(s:gsub(";","\r\n"))
            current_speedwalk = nil
            return
         end -- if

         local dir = table.remove (current_speedwalk, 1)
         local room = get_room (dir.uid)
         walk_to_room_name = room.name
         SetStatus ("Walking " .. (expand_direction [dir.dir] or dir.dir) ..
            " to " .. walk_to_room_name ..
            ". Speedwalks to go: " .. #current_speedwalk + 1)
         Send (dir.dir)
         expected_room = dir.uid
      else
         cancel_speedwalk ()
      end -- if any left
   end -- if

end -- start_speedwalk

-- cancel the current speedwalk

function cancel_speedwalk ()
   if current_speedwalk and #current_speedwalk > 0 then
      mapprint "Speedwalk cancelled."
   end -- if
   current_speedwalk = nil
   expected_room = nil
   SetStatus ("Ready")
end -- cancel_speedwalk


-- ------------------------------------------------------------------
-- mouse-up handlers (need to be exposed)
-- these are for clicking on the map, or the configuration box
-- ------------------------------------------------------------------

function mouseup_room (flags, hotspot_id)
   local uid = hotspot_id

   if bit.band (flags, miniwin.hotspot_got_rh_mouse) ~= 0 then
      -- RH click
      if type (room_click) == "function" then
         room_click (uid, flags)
      end
      return
   end -- if RH click

   -- here for LH click

   -- Control key down?
   if bit.band (flags, miniwin.hotspot_got_control) ~= 0 then
      cancel_speedwalk ()
      return
   end -- if ctrl-LH click

   -- find desired room
   find (nil,
      {{uid=uid, reason=true}},
      0,
      false,  -- show vnum?
      1,          -- how many to expect
      true        -- just walk there
   )
end -- mouseup_room

function mouseup_configure (flags, hotspot_id)
   draw_configure_box = true
   draw (current_room)
end -- mouseup_configure

function mouseup_close_configure (flags, hotspot_id)
   draw_configure_box = false
   SaveState()
   draw (current_room)
end -- mouseup_player

function mouseup_change_colour (flags, hotspot_id)

   local which = string.match (hotspot_id, "^$colour:([%a%d_]+)$")
   if not which then
      return  -- strange ...
   end -- not found

   local newcolour = PickColour (config [which].colour)

   if newcolour == -1 then
      return
   end -- if dismissed

   config [which].colour = newcolour

   draw (current_room)
end -- mouseup_change_colour

function mouseup_change_font (flags, hotspot_id)

   local newfont =  utils.fontpicker (config.FONT.name, config.FONT.size, ROOM_NAME_TEXT.colour)

   if not newfont then
      return
   end -- if dismissed

   config.FONT.name = newfont.name

   if newfont.size > 12 then
      utils.msgbox ("Maximum allowed font size is 12 points.", "Font too large", "ok", "!", 1)
   else
      config.FONT.size = newfont.size
   end -- if

   ROOM_NAME_TEXT.colour = newfont.colour

   -- reload new font
   WindowFont (win, FONT_ID, config.FONT.name, config.FONT.size)
   WindowFont (win, FONT_ID_UL, config.FONT.name, config.FONT.size, false, false, true)
   WindowFont (config_win, CONFIG_FONT_ID, config.FONT.name, config.FONT.size)
   WindowFont (config_win, CONFIG_FONT_ID_UL, config.FONT.name, config.FONT.size, false, false, true)

   -- see how high it is
   font_height = WindowFontInfo (win, FONT_ID, 1)  -- height

   draw (current_room)
end -- mouseup_change_font

function mouseup_change_depth (flags, hotspot_id)

   local depth = get_number_from_user ("Choose scan depth (3 to 300 rooms)", "Depth", config.SCAN.depth, 3, 300)

   if not depth then
      return
   end -- if dismissed

   config.SCAN.depth = depth
   draw (current_room)
end -- mouseup_change_depth

function mouseup_change_area_textures (flags, hotspot_id)
   if config.USE_TEXTURES.enabled == true then
      config.USE_TEXTURES.enabled = false
   else
      config.USE_TEXTURES.enabled = true
   end
   draw (current_room)
end -- mouseup_change_area_textures

function mouseup_change_show_id (flags, hotspot_id)
   if config.SHOW_ROOM_ID == true then
      config.SHOW_ROOM_ID = false
   else
      config.SHOW_ROOM_ID = true
   end
   draw (current_room)
end -- mouseup_change_area_textures

function mouseup_change_show_area_exits (flags, hotspot_id)
   if config.SHOW_AREA_EXITS == true then
      config.SHOW_AREA_EXITS = false
   else
      config.SHOW_AREA_EXITS = true
   end
   draw (current_room)
end -- mouseup_change_area_textures

function zoom_map (flags, hotspot_id)
   if bit.band (flags, 0x100) ~= 0 then
      zoom_out ()
   else
      zoom_in ()
   end -- if
end -- zoom_map

function resize_mouse_down(flags, hotspot_id)
   startx, starty = WindowInfo (win, 17), WindowInfo (win, 18)
end

function resize_release_callback()
   config.WINDOW.width = WindowInfo(win, 3)
   config.WINDOW.height = WindowInfo(win, 4)
   draw(current_room)
end

function resize_move_callback()
   if GetPluginVariable("c293f9e7f04dde889f65cb90", "lock_down_miniwindows") == "1" then
      return
   end
   local posx, posy = WindowInfo (win, 17), WindowInfo (win, 18)

   local width = WindowInfo(win, 3) + posx - startx
   startx = posx
   if (50 > width) then
      width = 50
      startx = windowinfo.window_left + width
   elseif (windowinfo.window_left + width > GetInfo(281)) then
      width = GetInfo(281) - windowinfo.window_left
      startx = GetInfo(281)
   end

   local height = WindowInfo(win, 4) + posy - starty
   starty = posy
   if (50 > height) then
      height = 50
      starty = windowinfo.window_top + height
   elseif (windowinfo.window_top + height > GetInfo(280)) then
      height = GetInfo(280) - windowinfo.window_top
      starty = GetInfo(280)
   end

   WindowResize(win, width, height, BACKGROUND_COLOUR.colour)
   Theme.DrawBorder(win)
   Theme.AddResizeTag(win, 1, nil, nil, "mapper.resize_mouse_down", "mapper.resize_move_callback", "mapper.resize_release_callback")

   WindowShow(win, true)
end

function utilprint(str, messageType)

	if messageType == "error" then
          AnsiNote(ColoursToANSI("@x238[@RDE@x202MO@x208N P@x214LU@x220G@x228IN @x220MA@x214NA@x208G@x202E@RR@x238]@W:@w"..str))
     elseif messageType == "script" then
          AnsiNote(ColoursToANSI("@x238@x238[@RDE@x202MO@x208N P@x214LU@x220G@x228IN @x220MA@x214NA@x208G@x202E@RR@x238]@c "..str))
     else
		AnsiNote(ColoursToANSI(str))
	end
	
end