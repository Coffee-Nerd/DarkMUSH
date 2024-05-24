-- Copy this file to create your own custom themes, but please do not modify this file.

-- Kaze THEME
return {
   LOGO_OPACITY = 0.06,

   PRIMARY_BODY = 0x000000,
   SECONDARY_BODY = 0x000000,
   BODY_TEXT = 0xFFFFFF,

   -- flat buttons
   CLICKABLE = 0x101010,
   --0x220022,
   CLICKABLE_HOVER = ColourNameToRGB("green"), -- Color when hovering over the tab with mouse
   CLICKABLE_HOT = ColourNameToRGB("red"),     -- Color when you have an unread message
   CLICKABLE_TEXT = 0xFFFFFF,
   CLICKABLE_HOVER_TEXT = 0xFFFFFF,
   CLICKABLE_HOT_TEXT = 0xFFFFFF,

   TITLE_PADDING = 2,

   -- for 3D surfaces
   THREE_D_HIGHLIGHT = ColourNameToRGB("green"), -- For main outline of windows

   THREE_D_GRADIENT = false,
   THREE_D_GRADIENT_FIRST = 0x000000,
--   THREE_D_GRADIENT_SECOND = 0x301030,
--   THREE_D_GRADIENT_ONLY_IN_TITLE = false,

   THREE_D_SOFTSHADOW = ColourNameToRGB("green"), --use opposite colors:  One of Two of the border colors for windows, usually title border
   THREE_D_HARDSHADOW = 0x000000,
   THREE_D_SURFACE_DETAIL = 0xFFFFFF, -- for contrasting details/text drawn on 3D surfaces

   -- for scrollbar background
   SCROLL_TRACK_COLOR1 = 0x000000,
   SCROLL_TRACK_COLOR2 = ColourNameToRGB("green"),
   VERTICAL_TRACK_BRUSH = miniwin.brush_hatch_forwards_diagonal,

   DYNAMIC_BUTTON_PADDING = 20,
   RESIZER_SIZE = 16,

   -- bg_texture_function is optional to override the default behavior.
   -- See Pink_Neon.lua for a "glitter on black" variant.
   -- Just make sure to return the path to a valid png file.
   bg_texture_function = function()
      return GetInfo(66).."worlds/plugins/images/bg1.png" -- This is the background image under the miniwindows
   end
}
