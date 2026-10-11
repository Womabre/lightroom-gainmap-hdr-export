local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrExportSession = import 'LrExportSession'
local LrFileUtils = import 'LrFileUtils'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrProgressScope = import 'LrProgressScope'

local exportServiceProvider = {}

-- Presets
exportServiceProvider.exportPresetFields = {
    { key = 'imageQuality', default = 70 },
    { key = 'conversionTool', default = 'ghdr' }, -- keep for UI parity

    -- toGainMapHDR options
    { key = 'gm_mode', default = 'apple_cif' },   -- iso|apple_cif|apple_iso|sdr|pq|hlg
    { key = 'sdrRatio', default = 0.20 },         -- -r
    { key = 'gainMapScale', default = 1.5 },      -- -H
    { key = 'colorSpace', default = 'p3' },       -- -c
    { key = 'bitDepth', default = 10 },           -- -d
    { key = 'container', default = 'heic' },      -- heic|jpeg  (-j for jpeg)
    { key = 'fileSuffix', default = '' },         -- -t
    -- { key = 'baseImage', default = '' },          -- -b
}

-- safer helper
local function clampQuality(q)
    q = tonumber(q) or 70
    q = math.floor(q + 0.5)
    if q < 0 then q = 0 end
    if q > 100 then q = 100 end
    return q
end

-- Helper: 2-decimal binding for edit_field, keeps the underlying prop numeric
local function decimalBinding(key, decimals, min, max)
  decimals = decimals or 2
  local fmt = "%." .. tostring(decimals) .. "f"
  local factor = 10 ^ decimals

  return LrView.bind {
    key = key,
    transform = function(v)               -- number -> "0.00"
      if type(v) ~= 'number' then v = tonumber(v) or 0 end
      return string.format(fmt, v)
    end,
    reverseTransform = function(s)        -- "0.00" -> number (rounded & clamped)
      local n = tonumber(s)
      if not n then return nil end
      if min and n < min then n = min end
      if max and n > max then n = max end
      return math.floor(n * factor + 0.5) / factor
    end
  }
end

exportServiceProvider.sectionsForTopOfDialog = function(viewFactory, propertyTable)
    local f = viewFactory
    
    -- ensure defaults exist BEFORE observer math
    propertyTable.imageQuality = clampQuality(propertyTable.imageQuality)
    propertyTable.gm_mode      = propertyTable.gm_mode      or 'apple_cif'
    propertyTable.sdrRatio     = propertyTable.sdrRatio     or 0.20
    propertyTable.gainMapScale = propertyTable.gainMapScale or 1.0
    propertyTable.colorSpace   = propertyTable.colorSpace   or 'p3'
    propertyTable.bitDepth     = propertyTable.bitDepth     or 10
    propertyTable.container    = propertyTable.container    or 'heic'
    propertyTable.fileSuffix   = propertyTable.fileSuffix   or ''
    -- propertyTable.baseImage    = propertyTable.baseImage    or ''

    -- robust observer
    propertyTable:addObserver('imageQuality', function()
        propertyTable.imageQuality = clampQuality(propertyTable.imageQuality)
    end)

    return {
        {
            title = "HEIC / HDR Gain Map Export",
            f:row {
                f:static_text { title = "Mode:", alignment = 'right' },
                f:popup_menu {
                    items = {
                        { title = 'ISO Gain Map (Adaptive HDR)', value = 'iso' },
                        { title = 'Apple Gain Map (CIFilter)',   value = 'apple_cif' },
                        { title = 'Apple Gain Map (from ISO)',   value = 'apple_iso' },
                        { title = 'SDR only',                    value = 'sdr' },
                        { title = 'PQ HEIC (10-bit)',            value = 'pq' },
                        { title = 'HLG HEIC (10-bit)',           value = 'hlg' },
                    },
                    value = LrView.bind 'gm_mode',
                },
            },
            f:row {
                f:static_text { title = "Image Quality:", alignment = 'right' },
                f:slider { value = LrView.bind 'imageQuality', min = 20, max = 100, fill_horizontal = 1 },
                f:edit_field { value = LrView.bind 'imageQuality', width_in_chars = 3, tooltip = "Enter image quality (20-100)" },
            },
            f:row {
                f:static_text { title = "SDR Tone-map Ratio:", alignment = 'right' },
                f:slider {
                    value = LrView.bind 'sdrRatio',
                    min = 0.0,
                    max = 1.0,
                    precision = 2,          -- two decimals
                    fill_horizontal = 1,
                },
                f:edit_field {
                    value = decimalBinding('sdrRatio', 2, 0.0, 1.0), 
                    width_in_chars = 5,     -- widen to fit 0.00
                    precision = 2,          -- two decimals
                },
            },
            f:row {
                f:static_text { title = "Gain-map Scale:", alignment = 'right' },
                f:slider {
                    value = LrView.bind 'gainMapScale',
                    min = 1.0,
                    max = 2.0,
                    precision = 2,          -- two decimals
                },
                f:edit_field {
                    value = decimalBinding('gainMapScale', 2, 1.0, 2.0),
                    width_in_chars = 5,
                    precision = 2,          -- two decimals
                },
                f:static_text { title = " (Apple modes only)" },
            },
            f:row {
                f:static_text { title = "Color Space:", alignment = 'right' },
                f:popup_menu {
                    items = {
                        { title = 'sRGB / Rec.709', value = 'srgb' },
                        { title = 'Display-P3',     value = 'p3' },
                        { title = 'Rec.2020',       value = 'rec2020' },
                    },
                    value = LrView.bind 'colorSpace',
                },
                f:static_text { title = "Bit Depth:", alignment = 'right' },
                f:popup_menu {
                    items = { { title = '8-bit', value = 8 }, { title = '10-bit', value = 10 } },
                    value = LrView.bind 'bitDepth',
                },
            },
            f:row {
                f:static_text { title = "Container:", alignment = 'right' },
                f:popup_menu {
                    items = { { title = 'HEIC', value = 'heic' }, { title = 'JPEG', value = 'jpeg' } },
                    value = LrView.bind 'container',
                },
                f:static_text { title = "Filename suffix:", alignment = 'right' },
                f:edit_field { value = LrView.bind 'fileSuffix', width_in_chars = 16 },
            },
            -- f:row {
            --     f:static_text { title = "Base image (-b, optional):", alignment = 'right' },
            --     f:edit_field { value = LrView.bind 'baseImage', width_in_chars = 48 },
            -- },
        },
    }
end

-- quote for shell
local function q(s) return string.format('"%s"', tostring(s):gsub('"','\\"')) end

-- pick a wrapper name that exists (lrgainmap preferred, fallback ghdr)
local function resolveWrapper()
    local binDir = LrPathUtils.child(_PLUGIN.path, "bin")
    local w1 = LrPathUtils.child(binDir, "lrgainmap")
    local w2 = LrPathUtils.child(binDir, "ghdr")
    if LrFileUtils.exists(w1) == 'file' then return w1 end
    if LrFileUtils.exists(w2) == 'file' then return w2 end
    return nil
end

exportServiceProvider.processRenderedPhotos = function(functionContext, exportContext)
    local exportSession = exportContext.exportSession
    local nPhotos = exportSession:countRenditions()
    local progressScope = LrProgressScope({ title = 'Exporting (Gain Map HDR)', functionContext = functionContext })

    local props = exportContext.propertyTable
    local imageQuality = clampQuality(props.imageQuality)
    local gm_mode      = props.gm_mode or 'apple_cif'
    local sdrRatio     = tonumber(props.sdrRatio) or 0.20
    local gainMapScale = tonumber(props.gainMapScale) or 1.5
    local colorSpace   = props.colorSpace or 'p3'
    local bitDepth     = tonumber(props.bitDepth) or 10
    local container    = props.container or 'heic'
    local fileSuffix   = props.fileSuffix or ''
    -- local baseImage    = props.baseImage or ''

    local wrapper = resolveWrapper()
    if not wrapper then
        LrDialogs.showError("Could not find wrapper in plugin/bin. Expected 'lrgainmap' or 'ghdr'.")
        return
    end

    for i, rendition in exportSession:renditions() do
        progressScope:setPortionComplete(i-1, nPhotos)

        local ok, pathOrMessage = rendition:waitForRender()
        if ok then
            local destPath   = rendition.destinationPath or pathOrMessage
            local destFolder = LrPathUtils.parent(destPath)
            local outExt     = (container == 'jpeg') and "jpg" or "heic"
            local outPath    = LrPathUtils.replaceExtension(destPath, outExt)

            local args = { q(wrapper), q(pathOrMessage), q(destFolder),
                           "-q", string.format("%.2f", math.max(0.20, math.min(1.00, imageQuality / 100))) }

            -- Modes
            if gm_mode == 'apple_cif' then table.insert(args, "-g")
            elseif gm_mode == 'apple_iso' then table.insert(args, "-a")
            elseif gm_mode == 'sdr' then table.insert(args, "-s")
            elseif gm_mode == 'pq' then table.insert(args, "-p")
            elseif gm_mode == 'hlg' then table.insert(args, "-h")
            end

            -- -r
            table.insert(args, "-r"); table.insert(args, string.format("%.3f", sdrRatio))
            -- -H (Apple modes only)
            if gm_mode == 'apple_cif' or gm_mode == 'apple_iso' then
                table.insert(args, "-H"); table.insert(args, string.format("%.2f", gainMapScale))
            end
            -- -c
            table.insert(args, "-c"); table.insert(args, colorSpace)
            -- -d
            table.insert(args, "-d"); table.insert(args, tostring(bitDepth))
            -- -j
            if container == 'jpeg' then table.insert(args, "-j") end
            -- -t
            if fileSuffix ~= '' then table.insert(args, "-t"); table.insert(args, fileSuffix) end
            -- -b
            -- if baseImage ~= '' then table.insert(args, "-b"); table.insert(args, baseImage) end

            local cmd = table.concat(args, " ")
            local rc  = LrTasks.execute(cmd)
            if rc ~= 0 then
                LrDialogs.showError("Gain Map export failed (exit ".. tostring(rc) ..")\n\nCommand:\n".. cmd)
            else
                if LrFileUtils.exists(pathOrMessage) == 'file' then
                    LrFileUtils.delete(pathOrMessage)
                end
            end
        else
            LrDialogs.showError("Error rendering photo: " .. tostring(pathOrMessage))
        end

        progressScope:setPortionComplete(i, nPhotos)
        if progressScope:isCanceled() then break end
    end
    progressScope:done()
end

return exportServiceProvider
