require "string_split"

local BLACK = 1
local RED = 2
local GREEN = 3
local YELLOW = 4
local BLUE = 5
local MAGENTA = 6
local CYAN = 7
local WHITE = 8

CODE_PREFIX = "$"
PREFIX_ESCAPE = "$$"

XTERM_CHAR = "x"

BLACK_CHAR = "k"
RED_CHAR = "r"
GREEN_CHAR = "g"
YELLOW_CHAR = "y"
BLUE_CHAR = "b"
MAGENTA_CHAR = "m"
CYAN_CHAR = "c"
WHITE_CHAR = "w"

BOLD_BLACK_CHAR = "d"
BOLD_RED_CHAR = "R"
BOLD_GREEN_CHAR = "G"
BOLD_YELLOW_CHAR = "Y"
BOLD_BLUE_CHAR = "B"
BOLD_MAGENTA_CHAR = "M"
BOLD_CYAN_CHAR = "C"
BOLD_WHITE_CHAR = "W"

NORMAL_CHARS = RED_CHAR .. GREEN_CHAR .. YELLOW_CHAR .. BLUE_CHAR .. MAGENTA_CHAR .. CYAN_CHAR .. WHITE_CHAR
BOLD_CHARS = BOLD_BLACK_CHAR ..
    BOLD_RED_CHAR .. BOLD_GREEN_CHAR .. BOLD_YELLOW_CHAR ..
    BOLD_BLUE_CHAR .. BOLD_MAGENTA_CHAR .. BOLD_CYAN_CHAR .. BOLD_WHITE_CHAR
ALL_CHARS = XTERM_CHAR .. NORMAL_CHARS .. BOLD_CHARS

XTERM_CODE = CODE_PREFIX .. XTERM_CHAR

BLACK_CODE = CODE_PREFIX .. BLACK_CHAR
RED_CODE = CODE_PREFIX .. RED_CHAR
GREEN_CODE = CODE_PREFIX .. GREEN_CHAR
YELLOW_CODE = CODE_PREFIX .. YELLOW_CHAR
BLUE_CODE = CODE_PREFIX .. BLUE_CHAR
MAGENTA_CODE = CODE_PREFIX .. MAGENTA_CHAR
CYAN_CODE = CODE_PREFIX .. CYAN_CHAR
WHITE_CODE = CODE_PREFIX .. WHITE_CHAR

BOLD_BLACK_CODE = CODE_PREFIX .. BOLD_BLACK_CHAR
BOLD_RED_CODE = CODE_PREFIX .. BOLD_RED_CHAR
BOLD_GREEN_CODE = CODE_PREFIX .. BOLD_GREEN_CHAR
BOLD_YELLOW_CODE = CODE_PREFIX .. BOLD_YELLOW_CHAR
BOLD_BLUE_CODE = CODE_PREFIX .. BOLD_BLUE_CHAR
BOLD_MAGENTA_CODE = CODE_PREFIX .. BOLD_MAGENTA_CHAR
BOLD_CYAN_CODE = CODE_PREFIX .. BOLD_CYAN_CHAR
BOLD_WHITE_CODE = CODE_PREFIX .. BOLD_WHITE_CHAR

TILDE_PATTERN = CODE_PREFIX .. "%-"
X_NONNUMERIC_PATTERN = XTERM_CODE .. "([^%d])"
X_THREEHUNDRED_PATTERN = XTERM_CODE .. "[3-9]%d%d"
X_TWOSIXTY_PATTERN = XTERM_CODE .. "2[6-9]%d"
X_TWOFIFTYSIX_PATTERN = XTERM_CODE .. "25[6-9]"
X_DIGITS_CAPTURE_PATTERN = XTERM_CODE .. "(%d%d?%d?)"
X_ANY_DIGITS_PATTERN = XTERM_CODE .. "%d?%d?%d?"

ALL_CODES_PATTERN = CODE_PREFIX .. "."
HIDDEN_GARBAGE_PATTERN = CODE_PREFIX .. "[^" .. ALL_CHARS .. "]"
BOLD_CODES_CAPTURE_PATTERN = "(" .. CODE_PREFIX .. "[" .. BOLD_CHARS .. "])"
NORMAL_CODES_CAPTURE_PATTERN = "(" .. CODE_PREFIX .. "[" .. NORMAL_CHARS .. "])"
NONX_CODES_CAPTURE_PATTERN = "(" .. CODE_PREFIX .. "[^" .. XTERM_CHAR .. "])"
CODE_REST_CAPTURE_PATTERN = "(" .. CODE_PREFIX .. "%a)([^" .. CODE_PREFIX .. "]*)"
HEX6_FG_PATTERN = CODE_PREFIX .. "X([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])"
HEX6_BG_PATTERN = CODE_PREFIX .. "1X([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])"


X3DIGIT_FORMAT = XTERM_CODE .. "%03d"
X2DIGIT_FORMAT = XTERM_CODE .. "%02d"
X1DIGIT_FORMAT = XTERM_CODE .. "%d"


local code_to_ansi_digit = {
   [RED_CODE] = 31,
   [GREEN_CODE] = 32,
   [YELLOW_CODE] = 33,
   [BLUE_CODE] = 34,
   [MAGENTA_CODE] = 35,
   [CYAN_CODE] = 36,
   [WHITE_CODE] = 37,
   [BOLD_BLACK_CODE] = 30,
   [BOLD_RED_CODE] = 31,
   [BOLD_GREEN_CODE] = 32,
   [BOLD_YELLOW_CODE] = 33,
   [BOLD_BLUE_CODE] = 34,
   [BOLD_MAGENTA_CODE] = 35,
   [BOLD_CYAN_CODE] = 36,
   [BOLD_WHITE_CODE] = 37
}

local ansi_digit_to_dim_code = {
   [31] = RED_CODE,
   [32] = GREEN_CODE,
   [33] = YELLOW_CODE,
   [34] = BLUE_CODE,
   [35] = MAGENTA_CODE,
   [36] = CYAN_CODE,
   [37] = WHITE_CODE
}

local ansi_digit_to_bold_code = {
   [30] = BOLD_BLACK_CODE,
   [31] = BOLD_RED_CODE,
   [32] = BOLD_GREEN_CODE,
   [33] = BOLD_YELLOW_CODE,
   [34] = BOLD_BLUE_CODE,
   [35] = BOLD_MAGENTA_CODE,
   [36] = BOLD_CYAN_CODE,
   [37] = BOLD_WHITE_CODE
}

local first_15_to_code = {}
local code_to_xterm = {}
for k, v in pairs(ansi_digit_to_dim_code) do
   first_15_to_code[k - 30] = v -- 1...7
end
for k, v in pairs(ansi_digit_to_bold_code) do
   first_15_to_code[k - 22] = v -- 8...15
end
for k, v in pairs(first_15_to_code) do
   code_to_xterm[v] = string.format(X3DIGIT_FORMAT, k)
end

local is_bold_code = {
   [BOLD_BLACK_CODE] = true,
   [BOLD_RED_CODE] = true,
   [BOLD_GREEN_CODE] = true,
   [BOLD_YELLOW_CODE] = true,
   [BOLD_BLUE_CODE] = true,
   [BOLD_MAGENTA_CODE] = true,
   [BOLD_CYAN_CODE] = true,
   [BOLD_WHITE_CODE] = true
}
for i = 9, 15 do
   is_bold_code[string.format(X3DIGIT_FORMAT, i)] = true
   is_bold_code[string.format(X2DIGIT_FORMAT, i)] = true
   is_bold_code[string.format(X1DIGIT_FORMAT, i)] = true
end


local code_to_client_color = {}
local client_color_to_dim_code = {}
local client_color_to_bold_code = {}

local function init_basic_to_color()
   default_black = GetNormalColour(BLACK)

   code_to_client_color = {
      [RED_CODE] = GetNormalColour(RED),
      [GREEN_CODE] = GetNormalColour(GREEN),
      [YELLOW_CODE] = GetNormalColour(YELLOW),
      [BLUE_CODE] = GetNormalColour(BLUE),
      [MAGENTA_CODE] = GetNormalColour(MAGENTA),
      [CYAN_CODE] = GetNormalColour(CYAN),
      [WHITE_CODE] = GetNormalColour(WHITE),
      [BOLD_BLACK_CODE] = GetBoldColour(BLACK),
      [BOLD_RED_CODE] = GetBoldColour(RED),
      [BOLD_GREEN_CODE] = GetBoldColour(GREEN),
      [BOLD_YELLOW_CODE] = GetBoldColour(YELLOW),
      [BOLD_BLUE_CODE] = GetBoldColour(BLUE),
      [BOLD_MAGENTA_CODE] = GetBoldColour(MAGENTA),
      [BOLD_CYAN_CODE] = GetBoldColour(CYAN),
      [BOLD_WHITE_CODE] = GetBoldColour(WHITE)
   }
end

local function init_color_to_basic()
   client_color_to_dim_code = {
      [code_to_client_color[RED_CODE]] = RED_CODE,
      [code_to_client_color[GREEN_CODE]] = GREEN_CODE,
      [code_to_client_color[YELLOW_CODE]] = YELLOW_CODE,
      [code_to_client_color[BLUE_CODE]] = BLUE_CODE,
      [code_to_client_color[MAGENTA_CODE]] = MAGENTA_CODE,
      [code_to_client_color[CYAN_CODE]] = CYAN_CODE,
      [code_to_client_color[WHITE_CODE]] = WHITE_CODE
   }

   client_color_to_bold_code = {
      [code_to_client_color[BOLD_BLACK_CODE]] = BOLD_BLACK_CODE,
      [code_to_client_color[BOLD_RED_CODE]] = BOLD_RED_CODE,
      [code_to_client_color[BOLD_GREEN_CODE]] = BOLD_GREEN_CODE,
      [code_to_client_color[BOLD_YELLOW_CODE]] = BOLD_YELLOW_CODE,
      [code_to_client_color[BOLD_BLUE_CODE]] = BOLD_BLUE_CODE,
      [code_to_client_color[BOLD_MAGENTA_CODE]] = BOLD_MAGENTA_CODE,
      [code_to_client_color[BOLD_CYAN_CODE]] = BOLD_CYAN_CODE,
      [code_to_client_color[BOLD_WHITE_CODE]] = BOLD_WHITE_CODE
   }
end

local function init_basic_colors()
   init_basic_to_color()
   init_color_to_basic()
end


local xterm_number_to_client_color = extended_colours
local client_color_to_xterm_number = {}
local client_color_to_xterm_code = {}
local x_to_client_color = {}
local x_not_too_dark = {}
local function init_xterm_colors()
   for i = 0, 255 do
      local color = xterm_number_to_client_color[i]
      x_not_too_dark[i] = i
      x_to_client_color[string.format(X3DIGIT_FORMAT, i)] = color
      x_to_client_color[string.format(X2DIGIT_FORMAT, i)] = color
      x_to_client_color[string.format(X1DIGIT_FORMAT, i)] = color

      client_color_to_xterm_number[color] = i
      client_color_to_xterm_code[color] = string.format(X3DIGIT_FORMAT, i)
   end

   -- Aardwolf bumps a few very dark xterm colors to brighter values to improve
   -- visibility. This seems like a good idea.
   local function override_dark_color(replace_what, with_what)
      local new_color = xterm_number_to_client_color[with_what]
      x_not_too_dark[replace_what] = with_what
      x_to_client_color[string.format(X3DIGIT_FORMAT, replace_what)] = new_color
      x_to_client_color[string.format(X2DIGIT_FORMAT, replace_what)] = new_color
      x_to_client_color[string.format(X1DIGIT_FORMAT, replace_what)] = new_color
   end

   override_dark_color(0, 7)
   override_dark_color(16, 7)
   override_dark_color(17, 19)
   override_dark_color(18, 19)
   for i = 232, 237 do
      override_dark_color(i, 238)
   end
end



init_xterm_colors()
init_basic_colors()


---------------------------------------------------------------------------
--  Helpers
---------------------------------------------------------------------------

-- 24-bit #RRGGBB  ➜  numeric BGR that MUSHclient wants (0xBBGGRR)
local function hex6_to_bgr (hex)
  local r = tonumber (hex:sub (1,2), 16)
  local g = tonumber (hex:sub (3,4), 16)
  local b = tonumber (hex:sub (5,6), 16)
  return b * 0x10000 + g * 0x100 + r
end

-- x-term 0–255  ➜  numeric BGR
local function xterm_to_bgr (idx)
  idx = tonumber (idx)
  if not idx or idx < 0 or idx > 255 then
    return code_to_client_color [WHITE_CODE]   -- fallback
  end
  -- 0–15  are the normal/bright ANSI colours (use the table we already have)
  if idx <= 15 then
    return code_to_client_color [ first_15_to_code [idx] ]
  end
  -- 16–231  6×6×6 colour cube
  if idx <= 231 then
    local i  = idx - 16
    local r6 = math.floor (i / 36)
    local g6 = math.floor ((i % 36) / 6)
    local b6 = i % 6
    local cube = { 0, 95, 135, 175, 215, 255 }
    local r, g, b = cube[r6+1], cube[g6+1], cube[b6+1]
    return b * 0x10000 + g * 0x100 + r
  end
  -- 232–255  grayscale ramp
  local v = 8 + (idx - 232) * 10
  return v * 0x010101            -- R = G = B so RGB == BGR
end

------------------------------------------------------------------------
--  True-colour helper  –  RRGGBB  ➔  BGR integer (0xBBGGRR)
------------------------------------------------------------------------
local function hex6_to_bgr (hex)
  local r = tonumber (hex:sub ( 1, 2 ), 16)
  local g = tonumber (hex:sub ( 3, 4 ), 16)
  local b = tonumber (hex:sub ( 5, 6 ), 16)
  -- B * 65536  +  G * 256  +  R
  return b * 0x10000 + g * 0x100 + r
end

---------------------------------------------------------------------------
--  True-colour / 256-colour / legacy parser
---------------------------------------------------------------------------
local function TrueColorStyles(s, default_fg, default_bg, multiline, dollarC)
  local fg   = default_fg or code_to_client_color[WHITE_CODE]
  local bg   = default_bg or 0
  local bold = false

  local buf, styles = {}, {}
  -- this holds the last code we parsed, for the next flush()
  local current_fromx = nil
  

  local function flush()
    if #buf > 0 then
      table.insert(styles, {
        fromx       = current_fromx,         -- the exact code we saw
        text        = table.concat(buf),
        length      = #buf,
        textcolour  = fg,
        backcolour  = (bg ~= 0) and bg or nil,
        bold        = bold,
      })
      buf = {}
    end
  end

  local i, n = 1, #s
  while i <= n do
    if s:sub(i,i) ~= "$" then
      buf[#buf+1] = s:sub(i,i)
      i = i + 1

    else
      -- literal "$$"
      if s:sub(i+1,i+1) == "$" then
        buf[#buf+1] = "$"
        i = i + 2
        goto cont
      end

      flush()
      i = i + 1

      -- background flag?
      local isBg = false
      if s:sub(i,i) == "1" then
        isBg, i = true, i + 1
      end

      local c = s:sub(i,i)
      -- reset code
      if c == "0" or c == "n" or c == "N" then
        fg, bg, bold     = default_fg or code_to_client_color[WHITE_CODE],
                           default_bg or 0,
                           false
        current_fromx    = "$" .. c
        i = i + 1

      -- 24-bit true-colour
      elseif c == "X" then
        -- Extract exactly 6 characters and validate them all as hex
        if i + 6 <= n then
          local hex = s:sub(i+1, i+6)
          -- Check that all 6 characters are valid hex digits
          if hex:match("^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then
            -- Valid 6-digit hex color
            local r = tonumber(hex:sub(1,2),16)
            local g = tonumber(hex:sub(3,4),16)
            local b = tonumber(hex:sub(5,6),16)
            local col = b * 0x10000 + g * 0x100 + r

            if isBg then bg = col else fg = col end
            current_fromx = (isBg and "$1X" or "$X") .. hex:lower()
            i = i + 7  -- Skip past X + 6 hex digits
          else
            -- Invalid hex sequence - skip just the X
            i = i + 1
          end
        else
          -- Not enough characters remaining - skip just the X
          i = i + 1
        end

      -- 256-colour
      elseif c == "x" then
        local num = s:match("^(%d%d?%d?)", i+1)
        if num and tonumber(num) then
          local idx = tonumber(num)
          -- compute BGR same as your existing code
          local col
          if idx <= 15 then
            col = code_to_client_color[first_15_to_code[idx]]
          elseif idx <= 231 then
            local v  = idx - 16
            local r6 = math.floor(v/36)
            local g6 = math.floor((v%36)/6)
            local b6 = v%6
            local cube = {0,95,135,175,215,255}
            local r,g,b = cube[r6+1], cube[g6+1], cube[b6+1]
            col = b*0x10000 + g*0x100 + r
          else
            local gray = 8 + (idx-232)*10
            col = gray*0x010101
          end

          if isBg then bg = col else fg = col end
          -- remember exactly what we parsed:
          current_fromx = (isBg and "$1x" or "$x") .. num
          i = i + 1 + #num
        else
          i = i + 1
        end

      -- “reset to last” passthrough
      elseif c == "C" and dollarC then
        current_fromx = "$C"
        i = i + 1

      -- legacy single-letter
      else
        local LEG = {
          r=RED_CODE,   R=BOLD_RED_CODE,
          g=GREEN_CODE, G=BOLD_GREEN_CODE,
          y=YELLOW_CODE,Y=BOLD_YELLOW_CODE,
          b=BLUE_CODE,  B=BOLD_BLUE_CODE,
          m=MAGENTA_CODE,M=BOLD_MAGENTA_CODE,
          c=CYAN_CODE,  C=BOLD_CYAN_CODE,
          w=WHITE_CODE, W=BOLD_WHITE_CODE,
          k=BLACK_CODE, D=BOLD_BLACK_CODE,
        }
        local code = LEG[c]
        if code then
          if isBg then
            bg   = code_to_client_color[code]
          else
            fg   = code_to_client_color[code]
            bold = (c == c:upper())
          end
        end
        current_fromx = "$" .. c
        i = i + 1
      end
    end
    ::cont::
  end

  flush()
  if multiline then
    return split_boundaries(styles, "\n")
  else
    return styles
  end
end
--- Hijack ColoursToStyles so *every* code—$r, $xNNN, $Xrrggbb, $1Xrrggbb, etc.—
--- is parsed by TrueColorStyles (which sets style.fromx), ensuring StylesToColours
--- will re-emit the exact original escape.
function ColoursToStyles(input, default_fg, default_bg, multiline, dollarC_resets)
   return TrueColorStyles(
      input,
      default_fg,
      default_bg,
      multiline,
      dollarC_resets
   )
end

      
------------------------------------------------------------------------
--  BGR numeric color to $Xrrggbb or $1Xrrggbb string
------------------------------------------------------------------------
local function bgr_to_hex6_code(bgr_number, is_background)
  if bgr_number == nil then return nil end

  -- MUSHclient stores colors as BGR: 0xBBGGRR
  -- We need to extract R, G, B components
  local r = bit.band(bgr_number, 0xFF)
  local g = bit.band(bit.rshift(bgr_number, 8), 0xFF)
  local b = bit.band(bit.rshift(bgr_number, 16), 0xFF)

  local hex_code = string.format("%02x%02x%02x", r, g, b)

  if is_background then
    return CODE_PREFIX .. "1X" .. hex_code
  else
    return CODE_PREFIX .. "X" .. hex_code
  end
end



      
function StylesToColours(styles, dollarC_resets)
   init_basic_colors() -- Ensures lookup tables are fresh
   local last_fg_code = "" -- Keep track of last foreground code
   local last_bg_code = "" -- Keep track of last background code

   -- convert to multiline if needed
   local style_lines = styles
   if styles[1] and not styles[1][1] then
      style_lines = { styles }
   end

   local line_texts = {}
   for _, line in ipairs(style_lines) do
      local line_parts = {}
      for _, style in ipairs(line) do
         local bold = style.bold or (style.style and ((style.style % 2) == 1))
         local text = string.gsub(style.text, CODE_PREFIX .. "(%W)", PREFIX_ESCAPE .. "%1")
         local textcolor = style.textcolour
         local backcolour = style.backcolour

         local current_fg_code = nil
         local current_bg_code = nil

         -- Determine Foreground Code
         if style.fromx then
             -- If fromx contains a background code, it might be $1X... or $1x...
             -- If fromx is just a foreground code like $X... or $x... or $r
             -- We need to be careful here. 'fromx' stores the *entire original code sequence*
             -- that led to this style. It could be "$r", "$x123", "$Xaabbcc", "$1x000", "$1Xddeeff", or even "$1r$G".
             -- The original logic assumes `style.fromx` is a single, applicable code.

             -- A simple approach: if fromx starts with $1, it's a background-inclusive code.
             -- Otherwise, it's treated as foreground.
             if style.fromx:sub(1,2) == CODE_PREFIX .. "1" then
                 -- If fromx is like "$1Xaabbcc" or "$1x123" (background only or bg+fg bundled by some MUDs)
                 -- Or if fromx is like "$1r$G" (complex)
                 -- For simplicity now, if fromx defines a background, we assume it also covers foreground
                 -- or that a subsequent style.fromx will set the foreground.
                 -- This part is tricky if fromx is a composite code.
                 -- Let's assume for now that if style.fromx is present, it's the dominant code.
                 current_fg_code = style.fromx -- This might be a BG code, or a FG code.
                                             -- The original code just used `style.fromx` as the single `code`.
             else
                 current_fg_code = style.fromx
             end
         elseif textcolor then
            current_fg_code = (
               (bold and client_color_to_bold_code[textcolor])
               or client_color_to_dim_code[textcolor]
               or client_color_to_xterm_code[textcolor]
               -- MODIFICATION: Prefer $Xrrggbb for true colors over xterm approximation
               or bgr_to_hex6_code(textcolor, false) -- false = foreground
               -- The original fallback to bgr_number_to_nearest_x256 is now effectively replaced
               -- by bgr_to_hex6_code for any color not matching the above.
            )
         end

         -- Determine Background Code (only if not covered by style.fromx explicitly setting a $1...)
         -- This part is an enhancement, as original StylesToColours didn't explicitly reconstruct $1... codes
         -- unless they were in style.fromx.
         if style.fromx and style.fromx:sub(1,2) == CODE_PREFIX .. "1" then
             current_bg_code = style.fromx -- Assume fromx handles it if it's a $1 code
             if current_fg_code == current_bg_code then
                -- If style.fromx was purely a background code e.g. "$1Xrrggbb",
                -- we still need to determine the foreground code based on textcolor
                if textcolor then
                    current_fg_code = (
                       (bold and client_color_to_bold_code[textcolor])
                       or client_color_to_dim_code[textcolor]
                       or client_color_to_xterm_code[textcolor]
                       or bgr_to_hex6_code(textcolor, false)
                    )
                else
                    current_fg_code = nil -- No textcolor to derive fg from
                end
             end
         elseif backcolour and backcolour ~= 0 then -- 0 is often default_bg
            -- Only generate a background code if it's not black (or your MUSHclient default bg)
            -- and if it wasn't already handled by style.fromx
            local default_bg_mush = GetInfo(24) -- MUSHclient default background color
            if backcolour ~= default_bg_mush then
                 current_bg_code = (
                    -- Try to find a legacy $1L code first
                    client_color_to_bold_code[backcolour] and (CODE_PREFIX .. "1" .. client_color_to_bold_code[backcolour]:sub(2))
                    or client_color_to_dim_code[backcolour] and (CODE_PREFIX .. "1" .. client_color_to_dim_code[backcolour]:sub(2))
                    -- Then an exact xterm $1xNNN code
                    or client_color_to_xterm_code[backcolour] and (CODE_PREFIX .. "1" .. client_color_to_xterm_code[backcolour]:sub(2))
                    -- Then $1Xrrggbb
                    or bgr_to_hex6_code(backcolour, true) -- true = background
                 )
            end
         end


         -- Emit codes if they changed
         -- Background code first, then foreground
         if current_bg_code and (last_bg_code ~= current_bg_code or (current_fg_code and last_fg_code ~= current_fg_code) ) then
            -- If BG changed OR (BG is same but FG changed, and BG is not nil)
            -- we might need to re-emit BG if FG also changes, to ensure correct layering if FG reset BG
            -- A simpler rule: if BG code is new, emit it.
            if last_bg_code ~= current_bg_code then
                table.insert(line_parts, current_bg_code)
                last_bg_code = current_bg_code
                -- If we set a background, the foreground might need to be reset if it wasn't explicitly set
                last_fg_code = "" -- Force fg to be re-emitted if it exists
            end
         elseif not current_bg_code and last_bg_code ~= "" then
             -- Background was removed, need to reset to default ($0 might do this, or rely on fg code)
             -- For DarkMUSH, often a new foreground code implicitly resets background.
             -- Or, if the game expects explicit background reset: table.insert(line_parts, "$10") ? (Not standard)
             -- Let's assume setting a new FG code will handle it, or rely on $0.
             last_bg_code = ""
         end

         if current_fg_code and (last_fg_code ~= current_fg_code) then
            -- If style.fromx was a $1 code that also implies FG (e.g. some MUDs send $1r for red text on red bg)
            -- and current_fg_code was set to that, it might be redundant here.
            -- The logic is: if fromx handled everything, fg_code might be that fromx.
            if current_fg_code ~= current_bg_code then -- Avoid re-emitting if fromx was a combined BG/FG code already emitted as BG
                table.insert(line_parts, current_fg_code)
            end
            last_fg_code = current_fg_code
         elseif not current_fg_code and last_fg_code ~= "" and not current_bg_code then
             -- If only foreground is cleared, and no background is being set,
             -- we might need a reset like $0 if the intention is default color.
             -- However, if text follows, and it has no color, it implies default.
             -- If current_bg_code is also nil, then we are resetting to default.
             -- $0 is the general reset.
             -- If textcolor is nil, and backcolor is nil/default, it's a reset.
             if not textcolor and (not backcolour or backcolour == 0 or backcolour == GetInfo(24)) then
                 if last_fg_code ~= (CODE_PREFIX .. "0") and last_bg_code ~= (CODE_PREFIX .. "0") then
                    table.insert(line_parts, CODE_PREFIX .. "0")
                    last_fg_code = CODE_PREFIX .. "0"
                    last_bg_code = CODE_PREFIX .. "0"
                 end
             else
                last_fg_code = ""
             end
         end

         if dollarC_resets then
            -- $C should reset to the last *foreground* color
            local effective_last_fg = last_fg_code
            if effective_last_fg == "" or effective_last_fg == (CODE_PREFIX .. "0") then
                -- If last fg code was reset or empty, use white as fallback for $C
                effective_last_fg = WHITE_CODE
            end
            text = text:gsub("%$C", effective_last_fg)
         end
         table.insert(line_parts, text)
      end
      table.insert(line_texts, table.concat(line_parts))
   end

   return table.concat(line_texts, "\n")
end

require "copytable"
function TruncateStyles(styles, startcol, endcol)
   if (styles == nil) or (styles[1] == nil) then
      return styles
   end

   local startcol = startcol or 1
   local endcol = endcol or 99999 -- 99999 is assumed to be long enough to cover ANY style run

   -- negative column indices are used to measure back from the end
   if (startcol < 0) or (endcol < 0) then
      local total_chars = 0
      for k, v in ipairs(styles) do
         total_chars = total_chars + v.length
      end
      if startcol < 0 then
         startcol = total_chars + startcol + 1
      end
      if endcol < 0 then
         endcol = total_chars + endcol + 1
      end
   end

   -- start/end order does not matter
   if startcol > endcol then
      startcol, endcol = endcol, startcol
   end

   -- Trim to start and end positions in styles
   local found_first = false
   local col_counter = 0
   local new_styles = {}
   local break_after = false
   for k, v in ipairs(styles) do
      local new_style = copytable.shallow(v)
      col_counter = col_counter + new_style.length
      if endcol <= col_counter then
         local marker = endcol - (col_counter - v.length)
         new_style.text = new_style.text:sub(1, marker)
         new_style.length = marker
         break_after = true
      end
      if startcol <= col_counter then
         if not found_first then
            local marker = startcol - (col_counter - v.length)
            found_first = true
            new_style.text = new_style.text:sub(marker)
            new_style.length = new_style.length - marker + 1
         end
         table.insert(new_styles, new_style)
      end
      if break_after then break end
   end

   return new_styles
end

function StylesWidth(win, plain_font, bold_font, styles, show_bold, utf8)
   local width = 0
   for i, v in ipairs(styles) do
      local font = plain_font
      if show_bold and v.bold and bold_font then
         font = bold_font
      end
      width = width + WindowTextWidth(win, font, v.text, utf8)
   end
   return width
end

function ToMultilineStyles(message, default_foreground_color, background_color, multiline, dollarC_resets)
   function err()
      assert(false,
         "Function '" ..
         (debug.getinfo(3, "n").name or debug.getinfo(2, "n").name) ..
         "' cannot convert message to multiline styles if it isn't a color coded string, table of styles, or table of tables (multiple lines) of styles.")
   end

   if type(message) == "string" then
      message = ColoursToStyles(message, default_foreground_color, background_color, multiline, dollarC_resets)
   end

   if type(message) ~= "table" then
      err()
   end

   if message.text then
      message = { { message } }
   elseif (type(message[1]) == "table") and message[1].text then
      message = { message }
   end

   if (type(message[1]) ~= "table") or (type(message[1][1]) ~= "table") or not message[1][1].text then
      err()
   end

   local default_black = GetNormalColour(BLACK)
   for _, line in ipairs(message) do
      for _, style in ipairs(line) do
         if style.length == nil then
            style.length = #(style.text)
         end
         if style.backcolour == default_black then
            style.backcolour = nil
         end
      end
   end

   return message
end

-- Partitions a line of styles at some separator pattern (default is "%s+" for blank space)
-- returns {{nonspace styles},{space styles},{nonspace styles},...}
function partition_boundaries(styles, separator_pattern)
   separator_pattern = separator_pattern or "%s+"
   local partitions = {}
   local last_text = nil
   local cur_partition = {}
   for _, style in ipairs(styles) do
      local style_tokens = style.text:split(separator_pattern, true)
      for _, text in ipairs(style_tokens) do
         if last_text then
            local last_endswith = last_text:match(separator_pattern .. "$")
            local this_startswith = text:match("^" .. separator_pattern)
            if last_endswith ~= this_startswith then
               if #cur_partition == 0 then
                  cur_partition = { {
                     text = "",
                     length = 0
                  } }
               end
               table.insert(partitions, cur_partition)
               cur_partition = {}
            end
         end
         local length = #text
         if length > 0 then
            table.insert(cur_partition,
               {
                  text = text,
                  length = length,
                  bold = style.bold,
                  backcolour = style.backcolour,
                  textcolour = style
                      .textcolour
               })
         end
         last_text = text
      end
   end
   if #cur_partition == 0 then
      cur_partition = { {
         text = "",
         length = 0
      } }
   end
   table.insert(partitions, cur_partition)
   return partitions
end

-- Splits a line of styles at some separator pattern (default is "%s+" for blank space)
-- returns {{nonspace styles},{nonspace styles},...}
function split_boundaries(styles, separator)
   local partitioned_styles = partition_boundaries(styles, separator)
   local style_lines = {}
   for i = 1, #partitioned_styles, 2 do
      table.insert(style_lines, partitioned_styles[i])
   end
   return style_lines
end

------------------------------------------------------------------------
--  strip_colours  –  understands $Xrrggbb  /  $1Xrrggbb
------------------------------------------------------------------------
function strip_colours (s)
  s = s:gsub (PREFIX_ESCAPE, "\0")
       :gsub (TILDE_PATTERN, "~")
       :gsub (X_ANY_DIGITS_PATTERN, "")
       :gsub (CODE_PREFIX .. "1?X%x%x%x%x%x%x", "")  -- strip 24-bit
       :gsub (ALL_CODES_PATTERN, "")
       :gsub ("%z", CODE_PREFIX)
  return s
end

------------------------------------------------------------------------
--  canonicalize_colours
--  • makes every legacy/xterm code canonical
--      - $r → $x001     ($xNNN always 3-digit)
--      - $x7 → $x007
--  • optionally folds the old 16-colour letters into x-codes
--      when keep_original == false        (unchanged behaviour)
--  • **leaves true-colour codes alone**,
--      merely lower-casing the hex so there’s exactly one spelling
--      for any given colour.
------------------------------------------------------------------------
function canonicalize_colours(s, keep_original)
  if not s:find(CODE_PREFIX, 1, true) then
    return s
  end

  -- 1) normalize any $Xrrggbb / $1Xrrggbb → lowercase hex
  s = s
    :gsub(CODE_PREFIX .. "1?X(%x%x%x%x%x%x)",
          function(hex) return CODE_PREFIX .. "X" .. hex:lower() end)

  -- 2) pad any $xN or $xNN → $xNNN
  s = s:gsub(X_DIGITS_CAPTURE_PATTERN, function(digits)
    local n = tonumber(digits)
    if n and n <= 255 then
      return string.format(X3DIGIT_FORMAT, n)
    end
    return ""  -- invalid → strip
  end)

  -- 2.5) convert every $xNNN / $1xNNN → true-colour hex
  --     using the client’s xterm→BGR table (extended_colours)
  s = s:gsub("%$(1?)x(%d%d%d)", function(bg_flag, num)
    local idx = tonumber(num)
    if not idx or idx > 255 then
      return ""  -- invalid
    end
    -- look up BGR numeric and split into R,G,B
    local bgr = xterm_number_to_client_color[idx]
    if not bgr then
      return ""  -- fallback
    end
    local b = math.floor(bgr / 0x10000) % 0x100
    local g = math.floor(bgr / 0x100)    % 0x100
    local r = bgr                         % 0x100
    local hex = string.format("%02x%02x%02x", r, g, b)
    if bg_flag == "1" then
      return CODE_PREFIX .. "1X" .. hex
    else
      return CODE_PREFIX .. "X"  .. hex
    end
  end)

  -- 3) fold legacy single-letter codes into $xNNN if desired
  if not keep_original then
    s = s:gsub(NONX_CODES_CAPTURE_PATTERN, function(letter_code)
      return code_to_xterm[letter_code] or letter_code
    end)
  end

  return s
end


-- Strip all color codes from a table of styles
function strip_colours_from_styles(styles)
   -- convert to multiline if needed
   local style_lines = styles
   if styles[1] and not styles[1][1] then
      style_lines = { styles }
   end

   local line_texts = {}
   for _, line in ipairs(style_lines) do
      local line_parts = {}
      for _, v in ipairs(line) do
         table.insert(line_parts, v.text)
      end
      table.insert(line_texts, table.concat(line_parts))
   end

   return table.concat(line_texts, "\n")
end

-- Returns a string with embedded ansi codes.
-- This can get confused if the player has redefined their color chart.
function stylesToANSI(styles, dollarC_resets)
   local line = {}
   local lastcode = ""
   local needs_reset = false
   init_basic_colors()
   for _, v in ipairs(styles) do
      local code = ""
      local textcolor = v.textcolour
      local backcolor = v.backcolour
      if textcolor then
         local isbold = (v.bold or (v.style and ((v.style % 2) == 1)))
         if v.fromx then
            code = ANSI(isbold and 1 or 0, 38, 5, v.fromx:sub(3))
         else
            code = colorNumberToAnsi(textcolor, isbold, false)
         end
         if backcolor then
            code = code .. colorNumberToAnsi(backcolor, false, true)
            needs_reset = true
         elseif needs_reset then
            code = ANSI(0) .. code
            needs_reset = false
         end
      end
      if code ~= "" then
         lastcode = code
      end
      if dollarC_resets then
         v.text = v.text:gsub("%$C", lastcode)
      end
      table.insert(line, code .. v.text)
   end
   return table.concat(line)
end

-- For mushclient numbers, like 10040166 or ColourNameToRGB("rebeccapurple")
function colorNumberToAnsi(color_number, foreground_is_bold, is_background)
   if is_background then
      return ANSI(48, 5, bgr_number_to_nearest_x256(color_number))
   else
      if foreground_is_bold then
         local boldcode = client_color_to_bold_code[color_number]
         if boldcode then
            local code = ANSI(1, code_to_ansi_digit[boldcode])
            if code then
               return code
            end
         end
      else
         local dimcode = client_color_to_dim_code[color_number]
         if dimcode then
            local code = ANSI(0, code_to_ansi_digit[dimcode])
            if code then
               return code
            end
         end
      end
      return ANSI(foreground_is_bold and 1 or 0, 38, 5, bgr_number_to_nearest_x256(color_number))
   end
end

function bgr_number_to_nearest_x256(bgr_number)
   -- https://stackoverflow.com/a/38055734
   local index = client_color_to_xterm_number[color_number]
   if index then return index end

   local abs, min, max, floor = math.abs, math.min, math.max, math.floor

   local function color_split_rgb(bgr_number)
      local band, rshift = bit.band, bit.rshift
      local b = band(rshift(bgr_number, 16), 0xFF)
      local g = band(rshift(bgr_number, 8), 0xFF)
      local r = band(bgr_number, 0xFF)
      return r, g, b
   end

   local r, g, b = color_split_rgb(bgr_number)

   local levels = { [0] = 0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff }

   local function index_0_5(value)
      return floor(max((value - 35) / 40, value / 58))
   end

   local function nearest_16_231(r, g, b)
      r, g, b = index_0_5(r), index_0_5(g), index_0_5(b)
      return 16 + 36 * r + 6 * g + b, levels[r], levels[g], levels[b]
   end

   local function nearest_232_255(r, g, b)
      local index = min(23, max(0, floor((((3 * r + 10 * g + b) / 14) - 3) / 10)))
      local gray = 8 + index * 10
      return 232 + index, gray, gray, gray
   end

   local function color_distance(r1, g1, b1, r2, g2, b2)
      return abs(r1 - r2) + abs(g1 - g2) + abs(b1 - b2)
   end

   local idx1, r1, g1, b1 = nearest_16_231(r, g, b)
   local idx2, r2, g2, b2 = nearest_232_255(r, g, b)
   local dist1 = color_distance(r, g, b, r1, g1, b1)
   local dist2 = color_distance(r, g, b, r2, g2, b2)
   return (dist1 < dist2) and idx1 or idx2
end

-- Tries to convert ANSI sequences to Aardwolf color codes
function AnsiToColours(ansi, default_foreground_code)
   if not default_foreground_code then
      default_foreground_code = WHITE_CODE
   elseif default_foreground_code:sub(1, 1) ~= CODE_PREFIX then
      default_foreground_code = CODE_PREFIX .. default_foreground_code
   end

   local ansi_capture = "\027%[([%d;]+)m"

   -- this stuff goes outside because ANSI is a state machine (lolsigh)
   local bold = false
   local color = ""
   local xstage = 0

   ansi = ansi:gsub(CODE_PREFIX, PREFIX_ESCAPE):gsub(ansi_capture, function(a)
      for c in a:gmatch("%d+") do
         local nc = tonumber(c)
         if nc == 38 then
            xstage = 1
         elseif nc == 5 and xstage == 1 then
            xstage = 2
         elseif xstage == 2 then -- xterm 256 color
            if bold and ansi_digit_to_bold_code[nc + 30] then
               color = ansi_digit_to_bold_code[nc + 30]
            else
               color = string.format(X3DIGIT_FORMAT, nc)
            end
            xstage = 0
         elseif nc == 1 then
            bold = true
            xstage = 0
         elseif nc == 0 then
            bold = is_bold_code[default_foreground_code] or false
            -- not actually sure if we should set color here or not
            color = default_foreground_code
         elseif nc <= 37 and nc >= 30 then -- regular color
            if bold then
               color = ansi_digit_to_bold_code[nc]
            else
               color = ansi_digit_to_dim_code[nc]
            end
            xstage = 0
         end
      end
      return color
   end)

   return ansi
end

function ColoursToANSI(text)
   -- return stylesToANSI(ColoursToStyles(text))
   if text:find(CODE_PREFIX, nil, true) then
      text = text:gsub(PREFIX_ESCAPE, "\0")        -- change @@ to 0x00
      text = text:gsub(TILDE_PATTERN, "~")         -- fix tildes (historical)
      text = text:gsub(X_NONNUMERIC_PATTERN, "%1") -- strip invalid xterm codes (non-number)
      text = text:gsub(X_THREEHUNDRED_PATTERN, "") -- strip invalid xterm codes (300+)
      text = text:gsub(X_TWOSIXTY_PATTERN, "")     -- strip invalid xterm codes (260+)
      text = text:gsub(X_TWOFIFTYSIX_PATTERN, "")  -- strip invalid xterm codes (256+)
      text = text:gsub(HIDDEN_GARBAGE_PATTERN, "") -- strip hidden garbage

      text = text:gsub(X_DIGITS_CAPTURE_PATTERN, function(a)
         local num_a = tonumber(a)
         -- Aardwolf treats x1...x15 as normal ANSI codes
         if num_a >= 1 and num_a <= 15 then
            if num_a >= 9 then
               return ANSI(1, num_a + 22)
            else
               return ANSI(0, num_a + 30)
            end
         else
            return ANSI(0, 38, 5, x_not_too_dark[num_a])
         end
      end)
      text = text:gsub(BOLD_CODES_CAPTURE_PATTERN, function(a)
         return ANSI(1, code_to_ansi_digit[a])
      end)
      text = text:gsub(NORMAL_CODES_CAPTURE_PATTERN, function(a)
         return ANSI(0, code_to_ansi_digit[a])
      end)

      text = text:gsub("%z", CODE_PREFIX)
   end
   return text
end

-- EVERYTHING BELOW HERE IS DEPRECATED. DO NOT USE. --

-- Historical function without purpose. Use StylesToColours.
-- Use TruncateStyles if you must, but that seems to be rather uncommon.
--
-- Convert a partial line of style runs into color codes.
-- Yes the "OneLine" part of the function name is meaningless. It stays that way for historical compatibility.
-- Think of it instead as TruncatedStylesToColours
-- The caller may optionally choose to start and stop at arbitrary character indices.
-- Negative indices are measured backward from the end.
-- The order of start and end columns does not matter, since the start will always be lower than the end.
function StylesToColoursOneLine(styles, startcol, endcol)
   if startcol or endcol then
      return StylesToColours(TruncateStyles(styles, startcol, endcol))
   else
      return StylesToColours(styles)
   end
end -- StylesToColoursOneLine

-- should have been marked local to prevent external use
colour_conversion = {
   [BLACK_CHAR] = GetNormalColour(BLACK),        -- 0x000000
   [RED_CHAR] = GetNormalColour(RED),            -- 0x000080
   [GREEN_CHAR] = GetNormalColour(GREEN),        -- 0x008000
   [YELLOW_CHAR] = GetNormalColour(YELLOW),      -- 0x008080
   [BLUE_CHAR] = GetNormalColour(BLUE),          -- 0x800000
   [MAGENTA_CHAR] = GetNormalColour(MAGENTA),    -- 0x800080
   [CYAN_CHAR] = GetNormalColour(CYAN),          -- 0x808000
   [WHITE_CHAR] = GetNormalColour(WHITE),        -- 0xC0C0C0
   [BOLD_BLACK_CHAR] = GetBoldColour(BLACK),     -- 0x808080
   [BOLD_RED_CHAR] = GetBoldColour(RED),         -- 0x0000FF
   [BOLD_GREEN_CHAR] = GetBoldColour(GREEN),     -- 0x00FF00
   [BOLD_YELLOW_CHAR] = GetBoldColour(YELLOW),   -- 0x00FFFF
   [BOLD_BLUE_CHAR] = GetBoldColour(BLUE),       -- 0xFF0000
   [BOLD_MAGENTA_CHAR] = GetBoldColour(MAGENTA), -- 0xFF00FF
   [BOLD_CYAN_CHAR] = GetBoldColour(CYAN),       -- 0xFFFF00
   [BOLD_WHITE_CHAR] = GetBoldColour(WHITE),     -- 0xFFFFFF
}                                                -- end conversion table

atletter_to_color_value =
    colour_conversion -- lol. https://github.com/endavis/bastmush/commit/6f8aec07449a55a65ccece05c1ab3a0139d70e54