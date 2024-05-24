-- Copy this file to create your own custom themes, but please do not modify this file.

-- DARKER CHARCOAL THEME
return {
   LOGO_OPACITY = 0.05,

   PRIMARY_BODY = 0x000000,
   SECONDARY_BODY = 0x000000,
   BODY_TEXT = 0xFFFFFF, 

   -- flat buttons
   CLICKABLE = 0x1d1d1d, -- Button Color
   CLICKABLE_HOVER = 0x000000, -- Button color when hovering over it
   CLICKABLE_HOT = 0x000000, -- Color of current tab
   CLICKABLE_TEXT = 0xc8c8c8,
   CLICKABLE_HOVER_TEXT = 0xdddddd,
   CLICKABLE_HOT_TEXT = 0xcfc5df,

   TITLE_PADDING = 2,

   -- for 3D surfaces
   THREE_D_HIGHLIGHT = 0x1d1d1d, --Main output border

   THREE_D_GRADIENT = false,
   THREE_D_GRADIENT_ONLY_IN_TITLE = true,
   THREE_D_GRADIENT_FIRST = 0x1d1d1d, --Comm Border Color
   THREE_D_GRADIENT_SECOND = 0x000000,

   THREE_D_SOFTSHADOW = 0x222222,
   THREE_D_HARDSHADOW = 0x000000,
   THREE_D_SURFACE_DETAIL = 0xFFFFFF, -- for contrasting details/text drawn on 3D surfaces

   -- for scrollbar background
   SCROLL_TRACK_COLOR1 = 0x000000,
   SCROLL_TRACK_COLOR2 = 0x1d1d1d,
   VERTICAL_TRACK_BRUSH = miniwin.brush_hatch_forwards_diagonal,

   DYNAMIC_BUTTON_PADDING = 20,
   RESIZER_SIZE = 16,

   -- bg_texture_function is optional to override the default behavior.
   -- See Pink_Neon.lua for a "glitter on black" variant.
   -- Just make sure to return the path to a valid png file.
   bg_texture_function = function()
      return GetInfo(66).."worlds/plugins/images/eb_bg.png"
   end
}
