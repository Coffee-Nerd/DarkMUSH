-- Copy this file to create your own custom themes, but please do not modify this file.

-- ZOOT'S AARDWOLF THEME
return {
   LOGO_OPACITY = 0.03,

   PRIMARY_BODY = 0x000000,
   SECONDARY_BODY = 0x000000,
   BODY_TEXT = 0xFFFFFF,

   -- flat buttons
   CLICKABLE = 0x220022,
   CLICKABLE_HOVER = ColourNameToRGB("indigo"),
   CLICKABLE_HOT = 0x301160,
   CLICKABLE_TEXT = 0xFFFFFF,
   CLICKABLE_HOVER_TEXT = 0xFFFFFF,
   CLICKABLE_HOT_TEXT = 0xFFFFFF,

   TITLE_PADDING = 2,

   -- for 3D surfaces
   THREE_D_HIGHLIGHT = ColourNameToRGB("indigo"), --FOR MAIN OUTLINE OF WINDOWS

   THREE_D_GRADIENT = miniwin.gradient_vertical,
   THREE_D_GRADIENT_FIRST = 0x000000,
   THREE_D_GRADIENT_SECOND = 0x301030,
   THREE_D_GRADIENT_ONLY_IN_TITLE = false,

   THREE_D_SOFTSHADOW = 0x080825, -- Bluish
   THREE_D_HARDSHADOW = 0x040412, -- Black
   THREE_D_SURFACE_DETAIL = 0x8CE6F0, -- for contrasting details/text drawn on 3D surfaces

   -- for scrollbar background
   SCROLL_TRACK_COLOR1 = 0x000000,
   SCROLL_TRACK_COLOR2 = ColourNameToRGB("indigo"),
   VERTICAL_TRACK_BRUSH = miniwin.brush_hatch_forwards_diagonal,

   DYNAMIC_BUTTON_PADDING = 20,
   RESIZER_SIZE = 16,

   -- bg_texture_function is optional to override the default behavior.
   -- See Charcoal.lua for a "do nothing" variant.
   -- Just make sure to return the path to a valid png file.
   bg_texture_function = function()
      imgpath = GetInfo(66).."worlds/plugins/images/forest2.png"

      WindowCreate("WiLl_It_BlEnD", 0, 0, 0, 0, 0, 0, 0)
      WindowLoadImage("WiLl_It_BlEnD", "tExTuRe", imgpath)
      local tw = WindowImageInfo("WiLl_It_BlEnD", "tExTuRe", 2)
      local th = WindowImageInfo("WiLl_It_BlEnD", "tExTuRe", 3)
      WindowResize("WiLl_It_BlEnD", tw, th, Theme.THREE_D_HIGHLIGHT)
      WindowImageFromWindow("WiLl_It_BlEnD", "cOlOr", "WiLl_It_BlEnD")
      WindowDrawImage("WiLl_It_BlEnD", "tExTuRe", 0, 0, 0, 0, 1)
      WindowFilter("WiLl_It_BlEnD", 0, 0, 0, 0, 7, 100)
      WindowFilter("WiLl_It_BlEnD", 0, 0, 0, 0, 9, 4)
      WindowBlendImage("WiLl_It_BlEnD", "cOlOr", 0, 0, 0, 0, 5, 0.8)
      
      imgpath = GetInfo(66).."worlds/plugins/images/temp_theme_blend.png"
      WindowWrite("WiLl_It_BlEnD", imgpath)
      return imgpath
   end
}