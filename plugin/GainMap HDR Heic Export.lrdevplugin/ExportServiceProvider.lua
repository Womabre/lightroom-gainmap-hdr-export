local LrTasks         = import 'LrTasks'
local LrDialogs       = import 'LrDialogs'
local LrPathUtils     = import 'LrPathUtils'
local LrExportSession = import 'LrExportSession'
local LrFileUtils     = import 'LrFileUtils'
local LrView          = import 'LrView'
local LrBinding       = import 'LrBinding'
local LrProgressScope = import 'LrProgressScope'

local bind = LrView.bind
local exportServiceProvider = {}

-- =========================
-- Presets & helpers
-- =========================
exportServiceProvider.exportPresetFields = {
  { key = 'imageQuality',    default = 70 },
  { key = 'conversionTool',  default = 'toGainMapHDR' },

  -- toGainMapHDR v3.3.2 options
  { key = 'gm_mode',         default = 'apple_cif' },  -- iso|apple_cif|sdr|pq|hlg
  { key = 'sdrRatio',        default = 3.0 },           -- -r (≥1.0; higher = stronger SDR tone-map)
  { key = 'maxHeadroom',     default = 6.0 },           -- -R (max headroom cap)
  { key = 'colorSpace',      default = 'p3' },          -- -c
  { key = 'bitDepth',        default = 10 },            -- -d
  { key = 'container',       default = 'heic' },        -- heic|jpeg  (-j for jpeg)
  { key = 'fileSuffix',      default = '' },            -- -t
  { key = 'halfSizeGainMap', default = false },         -- -H (subsample gain map to half size)
  { key = 'monoGainMap',     default = false },         -- -m (monochrome ISO gain map)

  -- Legacy keys kept for back-compat with old presets (no longer used by CLI)
  { key = 'uiGainMapSize',   default = 1.00 },
  { key = 'gainMapScale',    default = 1.50 },
}

local function clamp(v, lo, hi)
  v = tonumber(v) or lo
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function clampQuality(q)
  return clamp(math.floor((tonumber(q) or 70) + 0.5), 0, 100)
end

-- POSIX shell quoting: values inside single quotes are passed literally.
local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

-- Decimal binding for edit_field; keeps underlying value numeric (rounded)
local function decimalBinding(key, decimals, min, max)
  decimals = decimals or 2
  local fmt    = "%." .. tostring(decimals) .. "f"
  local factor = 10 ^ decimals

  return LrView.bind {
    key = key,
    transform = function(v)
      v = tonumber(v) or 0
      return string.format(fmt, v)
    end,
    reverseTransform = function(s)
      local n = tonumber(s)
      if not n then return nil end
      if min then n = math.max(min, n) end
      if max then n = math.min(max, n) end
      return math.floor(n * factor + 0.5) / factor
    end
  }
end

-- Resolve wrapper: use "toGainMapHDR" in the plugin root
local function resolveWrapper()
  local w = LrPathUtils.child(_PLUGIN.path, "toGainMapHDR")
  if LrFileUtils.exists(w) == 'file' then return w end
  return nil
end

-- =========================
-- UI
-- =========================
exportServiceProvider.sectionsForTopOfDialog = function(viewFactory, propertyTable)
  local f = viewFactory

  -- Ensure defaults exist BEFORE observers/conditions
  propertyTable.imageQuality   = clampQuality(propertyTable.imageQuality)
  propertyTable.gm_mode        = propertyTable.gm_mode or 'apple_cif'
  propertyTable.colorSpace     = propertyTable.colorSpace or 'p3'
  propertyTable.bitDepth       = tonumber(propertyTable.bitDepth) or 10
  propertyTable.container      = propertyTable.container or 'heic'
  propertyTable.fileSuffix     = propertyTable.fileSuffix or ''

  -- Migrate sdrRatio: old presets used 0..1, v3.2 requires ≥1.0
  do
    local sr = tonumber(propertyTable.sdrRatio)
    if not sr or sr < 1.0 then
      propertyTable.sdrRatio = 3.0
    else
      propertyTable.sdrRatio = clamp(sr, 1.0, 50.0)
    end
  end

  propertyTable.maxHeadroom     = clamp(tonumber(propertyTable.maxHeadroom) or 6.0, 1.0, 100.0)
  propertyTable.halfSizeGainMap = propertyTable.halfSizeGainMap == true
  propertyTable.monoGainMap     = propertyTable.monoGainMap == true

  -- Migrate gm_mode: apple_iso was removed in v3.2
  if propertyTable.gm_mode == 'apple_iso' then
    propertyTable.gm_mode = 'apple_cif'
  end

  -- Auto-tune bitDepth for PQ/HLG
  propertyTable:addObserver('gm_mode', function()
    local m = propertyTable.gm_mode
    if m == 'pq' or m == 'hlg' then propertyTable.bitDepth = 10 end
  end)

  propertyTable:addObserver('imageQuality', function()
    propertyTable.imageQuality = clampQuality(propertyTable.imageQuality)
  end)

  local function isoModeBinding()
    return LrView.bind {
      key = 'gm_mode',
      transform = function(mode) return mode == 'iso' end
    }
  end

  local function bitDepthEnabledBinding()
    return LrView.bind {
      key = 'gm_mode',
      transform = function(mode) return not (mode == 'pq' or mode == 'hlg') end
    }
  end

  return {
    {
      title = "HEIC / HDR Gain Map Export  (toGainMapHDR v3.3.2)",
      synopsis = bind('gm_mode'),

      f:row {
        f:static_text { title = "Mode:", alignment = 'right' },
        f:popup_menu {
          items = {
            { title = 'ISO Gain Map (Adaptive HDR)',  value = 'iso' },
            { title = 'Apple Gain Map (CIFilter)',    value = 'apple_cif' },
            { title = 'SDR only',                    value = 'sdr' },
            { title = 'PQ HEIC (10-bit)',             value = 'pq' },
            { title = 'HLG HEIC (10-bit)',            value = 'hlg' },
          },
          value = bind('gm_mode'),
        },
      },

      f:row {
        f:static_text { title = "Image Quality:", alignment = 'right' },
        f:slider {
          value = bind 'imageQuality',
          min = 20, max = 100, fill_horizontal = 1,
          tooltip = "HEIC/JPEG quality (20-100)",
        },
        f:edit_field { value = bind 'imageQuality', width_in_chars = 3 },
      },

      f:row {
        f:static_text { title = "Tone-map Ratio (-r):", alignment = 'right' },
        f:slider {
          value = bind 'sdrRatio',
          min = 1.0, max = 50.0, precision = 1, fill_horizontal = 1,
          tooltip = "1.0 = keep full highlights; higher = stronger SDR tone-mapping (default 3.0)",
        },
        f:edit_field {
          value = decimalBinding('sdrRatio', 1, 1.0, 50.0),
          width_in_chars = 5,
        },
      },

      f:row {
        f:static_text { title = "Max Headroom (-R):", alignment = 'right' },
        f:slider {
          value = bind 'maxHeadroom',
          min = 1.0, max = 20.0, precision = 1, fill_horizontal = 1,
          tooltip = "Cap on highlight headroom used for tone-mapping (default 6.0)",
        },
        f:edit_field {
          value = decimalBinding('maxHeadroom', 1, 1.0, 100.0),
          width_in_chars = 5,
        },
      },

      f:row {
        f:static_text { title = "Color Space:", alignment = 'right' },
        f:popup_menu {
          items = {
            { title = 'sRGB / Rec.709', value = 'srgb' },
            { title = 'Display-P3',     value = 'p3' },
            { title = 'Rec.2020',       value = 'rec2020' },
          },
          value = bind('colorSpace'),
        },

        f:static_text { title = "Bit Depth:", alignment = 'right' },
        f:popup_menu {
          items = { { title = '8-bit', value = 8 }, { title = '10-bit', value = 10 } },
          value = bind('bitDepth'),
          enabled = bitDepthEnabledBinding(),
        },
      },

      f:row {
        f:static_text { title = "Container:", alignment = 'right' },
        f:popup_menu {
          items = { { title = 'HEIC', value = 'heic' }, { title = 'JPEG', value = 'jpeg' } },
          value = bind('container'),
        },
        f:static_text { title = "Filename suffix:", alignment = 'right' },
        f:edit_field { value = bind 'fileSuffix', width_in_chars = 16 },
      },

      f:row {
        f:checkbox {
          title   = "Subsample gain map to ½ size  (-H)",
          value   = bind 'halfSizeGainMap',
          tooltip = "Reduces gain-map resolution to half width/height, saving space",
        },
        f:checkbox {
          title   = "Monochrome gain map  (-m)",
          value   = bind 'monoGainMap',
          enabled = isoModeBinding(),
          tooltip = "ISO gain map as luminance channel only (ISO mode only)",
        },
      },
    },
  }
end

-- =========================
-- Processing
-- =========================
exportServiceProvider.processRenderedPhotos = function(functionContext, exportContext)
  local exportSession = exportContext.exportSession
  local nPhotos = exportSession:countRenditions()
  local progress = LrProgressScope({
    title = 'Exporting (Gain Map HDR)',
    functionContext = functionContext
  })

  local props         = exportContext.propertyTable
  local imageQuality  = clampQuality(props.imageQuality)
  local gm_mode       = props.gm_mode or 'apple_cif'
  local colorSpace    = props.colorSpace or 'p3'
  local bitDepth      = tonumber(props.bitDepth) or 10
  local container     = props.container or 'heic'
  local fileSuffix    = props.fileSuffix or ''

  -- Migrate/clamp sdrRatio: v3.2 requires ≥1.0
  local sdrRatio = tonumber(props.sdrRatio) or 3.0
  if sdrRatio < 1.0 then sdrRatio = 3.0 end
  sdrRatio = clamp(sdrRatio, 1.0, 50.0)

  local maxHeadroom = clamp(tonumber(props.maxHeadroom) or 6.0, 1.0, 100.0)
  local halfSize    = props.halfSizeGainMap == true
  local monoGainMap = props.monoGainMap == true

  -- Enforce 10-bit for PQ
  if gm_mode == 'pq' then bitDepth = 10 end

  if container == 'jpeg' and (gm_mode == 'pq' or gm_mode == 'hlg') then
    LrDialogs.showError("JPEG does not support the PQ or HLG export modes. Choose HEIC or a gain-map/SDR mode.")
    progress:done()
    return
  end

  -- Coerce JPEG to 8-bit
  if container == 'jpeg' and bitDepth ~= 8 then
    LrDialogs.message(
      "JPEG is 8-bit",
      "Switching bit depth to 8-bit because JPEG does not support 10-bit.",
      "info"
    )
    bitDepth = 8
  end

  local wrapper = resolveWrapper()
  if not wrapper then
    LrDialogs.showError("Could not find 'toGainMapHDR' in the plugin folder. Build the plugin with `make` or install a packaged release.")
    return
  end

  local failures = 0

  for i, rendition in exportSession:renditions() do
    progress:setPortionComplete(i - 1, nPhotos)

    local ok, pathOrMessage = rendition:waitForRender()
    if ok then
      local srcPath = pathOrMessage
      local destFolder = rendition.destinationPath and LrPathUtils.parent(rendition.destinationPath)
                        or LrPathUtils.parent(srcPath)
      if not destFolder or LrFileUtils.exists(destFolder) ~= 'directory' then
        destFolder = LrPathUtils.parent(srcPath)
      end

      -- toGainMapHDR v3.3.2: <binary> <input> <outputFolder> [options]
      local args = {
        q(wrapper),
        q(srcPath),
        q(destFolder),
        "-q", string.format("%.2f", imageQuality / 100),
      }

      -- Mode flags
      if gm_mode == 'apple_cif' then
        table.insert(args, "-g")
      elseif gm_mode == 'sdr' then
        table.insert(args, "-s")
      elseif gm_mode == 'pq' then
        table.insert(args, "-p")
      elseif gm_mode == 'hlg' then
        table.insert(args, "-h")
      -- 'iso' is the default (no extra flag)
      end

      -- Tone-map ratio and headroom (not applicable for PQ/HLG)
      if gm_mode ~= 'pq' and gm_mode ~= 'hlg' then
        table.insert(args, "-r"); table.insert(args, string.format("%.1f", sdrRatio))
        table.insert(args, "-R"); table.insert(args, string.format("%.1f", maxHeadroom))
      end

      -- Half-size gain map (boolean flag, no argument)
      if halfSize then table.insert(args, "-H") end

      -- Monochrome gain map (ISO mode only)
      if monoGainMap and gm_mode == 'iso' then table.insert(args, "-m") end

      -- Common params
      table.insert(args, "-c"); table.insert(args, colorSpace)
      table.insert(args, "-d"); table.insert(args, tostring(bitDepth))
      if container == 'jpeg' then table.insert(args, "-j") end
      if fileSuffix ~= '' then table.insert(args, "-t"); table.insert(args, fileSuffix) end

      local cmd = table.concat(args, " ")
      local rc, output = LrTasks.execute(cmd, {captureStdout = true})

      if rc ~= 0 then
        failures = failures + 1
        local errorMsg = "Gain Map export failed (exit " .. tostring(rc) .. ")"
        if output and output ~= "" then
          errorMsg = errorMsg .. "\n\nOutput: " .. output
        end
        errorMsg = errorMsg .. "\n\nCommand:\n" .. cmd
        LrDialogs.showError(errorMsg)
      else
        if LrFileUtils.exists(srcPath) == 'file' then
          LrFileUtils.delete(srcPath)
        end
      end
    else
      failures = failures + 1
      LrDialogs.showError("Error rendering photo: " .. tostring(pathOrMessage))
    end

    progress:setPortionComplete(i, nPhotos)
    if progress:isCanceled() then break end
  end

  progress:done()

  if failures > 0 then
    LrDialogs.message("Export completed with errors", tostring(failures) .. " rendition(s) failed.", "warning")
  end
end

return exportServiceProvider
