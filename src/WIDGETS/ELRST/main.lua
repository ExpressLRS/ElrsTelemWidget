--196x169 right half
--392x84 top half
--196x56 1 + 3
--196x42 1 + 4

local TH = 18

-- Variables used across all instances
local vcache -- valueId cache
local mod = {} -- module info

local function getV(id)
  -- Return the getValue of ID or nil if it does not exist
  local cid = vcache[id]
  if cid == nil then
    local info = getFieldInfo(id)
    -- use 0 to prevent future lookups
    cid = info and info.id or 0
    vcache[id] = cid
  end
  return cid ~= 0 and getValue(cid) or nil
end

local function create(zone, options)
  local widget = {
    zone = zone,
    cfg = options,
  }

  local _, rv = getVersion()
  widget.DEBUG = string.sub(rv, -5) == "-simu"

  vcache = {}
  return widget
end

local function update(widget, options)
  -- Runs if options are changed from the Widget Settings menu
  widget.cfg = options
end

local function pwrToIdx(powval)
  local POWERS = {10, 25, 50, 100, 250, 500, 1000, 2000}
  for k, v in ipairs(POWERS) do
    if powval == v then return k - 1 end
  end
  return 7 -- 2000
end

local function drawPowerLvl(minp, cfgp, maxp, curp, zw, zh)
  local barW = 12
  local itemH = (zh - 5) / (maxp - minp)
  lcd.drawRectangle(zw - barW - 1, 1, barW, zh - 2)
  --lcd.drawFilledRectangle(zw - barW, 2, barW - 2, itemH * (maxp - cfgp) - 1, COLOR_THEME_DISABLED) -- power beyond cfgpower
  curp = pwrToIdx(curp)
  for pwr = minp + 1, curp do
    --print(pwr, (zh - 2 - (pwr * itemH)))
    lcd.drawFilledRectangle(zw - barW + 1, zh - (pwr * itemH) - 1, barW - 4, itemH - 1, COLOR_THEME_PRIMARY3)
  end
end

local function drawDiverSym(x, y, ant)
  if ant ~= nil then
    lcd.drawFilledRectangle(x+(5*ant), y+6, 4, 10, COLOR_THEME_SECONDARY1)
    lcd.drawFilledRectangle(x+5-(5*ant), y+11, 4, 5, COLOR_THEME_SECONDARY1)
  end
end

local function drawDbms(x, y, rssi1, rssi2, ant)
  -- ant is nil if not diversity, else 0 or 1
  local rssi1Str = tostring(rssi1)
  lcd.drawText(x+32, y, rssi1Str, ((ant ~= 1) and COLOR_THEME_SECONDARY1 or COLOR_THEME_DISABLED) + RIGHT)
  if ant ~= nil then
    drawDiverSym(x+34, y, ant)
    lcd.drawText(x+48, y, tostring(rssi2), (ant == 1) and COLOR_THEME_SECONDARY1 or COLOR_THEME_DISABLED)
  end
end

local function checkCellCount(ctx, v)
  -- once the cellCnt is the same X times in a row, stop updating
  if (ctx.cellCntCnt or 0) > 5 then
    return
  end

  -- try to lock on to the cell count, so as the voltage sags we don't change S
  local cellCnt = math.floor(v / 4.35) + 1
  -- Prevent lock on when no voltage is present
  if (v / cellCnt) < 3.0 then
    return
  end

  if ctx.cellCnt ~= cellCnt then
    ctx.cellCnt = cellCnt
    ctx.cellCntCnt = 0
  else
    -- The value has to change to count as an update
    if ctx.cellLastV == v then
      return
    end
    ctx.cellLastV = v
    ctx.cellCntCnt = ctx.cellCntCnt + 1
  end
end

local function drawVBatt(widget, tlm)
  tlm.vbat = getV("RxBt")
  if tlm.vbat == nil then return end
  lcd.drawText(1, widget.zh - 30, "Battery", SMLSIZE + COLOR_THEME_SECONDARY2 + SHADOWED)
  checkCellCount(widget.ctx, tlm.vbat)

  local str
  if tlm.vbat > 0 then
    local cells = widget.ctx.cellCnt
    if cells then
      -- If fullscreen use the verbose, otherwise just be small to fit current
      if widget.size < 1 then
        str = string.format("%.2fV (%dS %.1fV)", tlm.vbat / cells, cells, tlm.vbat)
      else
        str = string.format("%dS %.2fV", cells, tlm.vbat / cells)
      end
    else
      str = string.format("%.2fV", tlm.vbat)
    end
  else
    str = "  --"
  end
  lcd.drawText(1, widget.zh - 18, str, COLOR_THEME_PRIMARY3)
end

local function drawCurrent(widget, tlm)
  tlm.curr = getV("Curr")
  if tlm.curr == nil then return end
  lcd.drawText(widget.zw / 2 - 6, widget.zh - 30, "Current", SMLSIZE + COLOR_THEME_SECONDARY2 + SHADOWED + CENTER)

  local str
  if tlm.curr > 0 then
    str = string.format("%.2fA", tlm.curr)
  else
    str = "--"
  end
  lcd.drawText(widget.zw / 2 - 6, widget.zh - 18, str, COLOR_THEME_PRIMARY3 + CENTER)
end

local function drawGps(widget, tlm, Y)
  tlm.sats = getV("Sats")
  if tlm.sats == nil then return end
  -- Number of sats
  lcd.drawText(widget.zw - 13, Y, tostring(tlm.sats) .. " sats", COLOR_THEME_SECONDARY1 + RIGHT)

  Y = Y + TH
  tlm.gspd = getV("GSpd")
  if tlm.gspd ~= nil then
    lcd.drawText(1, Y, string.format("Speed %.1f", tlm.gspd), COLOR_THEME_SECONDARY1)
  end
  tlm.alt = getV("Alt")
  if tlm.alt ~= nil then
    lcd.drawText(widget.zw - 13, Y, "Alt " .. tostring(tlm.alt), COLOR_THEME_SECONDARY1 + RIGHT)
  end
end

local function drawFcTelem(widget, tlm, Y)
  drawVBatt(widget, tlm)
  drawCurrent(widget, tlm)
  if widget.size == 0 then
    drawGps(widget, tlm, Y)
  end
end

local function drawRange(widget, tlm, Y)
  -- returns size of range bar drawn (0 if range pie)
  local rssi = (tlm.ant == 1) and tlm.rssi2 or tlm.rssi1
  local minrssi = (mod.RFRSSI and mod.RFRSSI[tlm.rfmd+1]) or -128
  if rssi > -50 then rssi = -50 end
  local rangePct = 100 * (rssi + 50) / (minrssi + 50)
  local rangePctStr = string.format("%d%%", rangePct)
  local rangeClr = (rangePct > 80) and COLOR_THEME_WARNING or (rangePct > 40) and COLOR_THEME_SECONDARY2 or COLOR_THEME_SECONDARY1

  -- Range Bar (for anyting except full height)
  if widget.size > 1 then
    lcd.drawGauge(1, Y, widget.zw - 15, 15, rangePct, 100, COLOR_THEME_SECONDARY1)
    lcd.drawText(widget.zw / 2 - 6, Y - 2, "Range " .. rangePctStr, SMLSIZE + CENTER + rangeClr)
    return Y + 14
  end

  -- Range Pie (for full height only)
  local cx, cy, cr = widget.zw / 2 - 6, widget.zh / 2 + 10, widget.zw / 6
  local firstH = (rangePct >= 50) and 180 or rangePct * 180 / 50
  lcd.drawPie(cx, cy, cr, 180, 180 + firstH, COLOR_THEME_SECONDARY1)
  if rangePct > 50 then
    local secondH = (rangePct - 50) * 180 / 50
    lcd.drawPie(cx, cy, cr, 0, secondH, COLOR_THEME_SECONDARY1)
  end

  lcd.drawText(cx + (cr * -0.70), cy + cr - 15, "Range", SMLSIZE + RIGHT + rangeClr + SHADOWED)
  lcd.drawText(cx + (cr * 0.85), cy + cr - 15, rangePctStr, SMLSIZE + rangeClr + SHADOWED)
  lcd.drawCircle(cx, cy, cr, COLOR_THEME_PRIMARY3)

  return Y
end

local function updateWidgetSize(widget, event)
  if event ~= nil then
    widget.size = 0 -- fullscreen
    widget.zw = LCD_W
    widget.zh = LCD_H
    return
  end

  widget.zw = widget.zone.w
  widget.zh = widget.zone.h
  if widget.zh >= 169 then
    widget.size = 1 -- 1x widget
  elseif widget.zh >= 84 then
    widget.size = 2 -- 2x widget
  elseif widget.zh >= 56 then
    widget.size = 3 -- 3x widget
  else -- 42
    widget.size = 4 -- 4x widget
  end
end

local function drawRfModeText(widget, tlm, Y)
  local modestr = (mod.RFMOD and mod.RFMOD[tlm.rfmd+1]) or ("RFMD" .. tostring(tlm.rfmd))
  if widget.size < 3 then tlm.fmode = getV("FM") or 0 end

  -- For 3up/4up widgets, condense the LQ into the modestr
  if widget.size > 2 then
    modestr = string.format("%s LQ %d%%", modestr, tlm.rqly)
  else
    local fmodestr
    -- For 2up, flight mode goes in the Rf mode if available
    if widget.size == 2 and tlm.fmode ~= 0 then
      fmodestr = " " .. tlm.fmode .. " Mode"
    end
    modestr = modestr .. (fmodestr or " Connected")
  end
  lcd.drawText(widget.zw / 2 - 6, Y, modestr, COLOR_THEME_PRIMARY1 + CENTER)

  return Y + TH
end

local function drawRssiLq(widget, tlm, Y)
  local rssi = (tlm.ant == 1) and tlm.rssi2 or tlm.rssi1
  if widget.size > 3 then
    lcd.drawText(1, widget.zh - 15, tostring(rssi) .. "dBm", SMLSIZE + COLOR_THEME_PRIMARY3)
  elseif widget.size > 2 then
    lcd.drawText(1, widget.zh - 30, "RSSI", SMLSIZE + COLOR_THEME_SECONDARY2 + SHADOWED)
    lcd.drawText(1, widget.zh - 18, tostring(rssi) .. "dBm", COLOR_THEME_PRIMARY3)
  elseif widget.size > 1 then
    lcd.drawText(1, Y, "LQ " .. tostring(tlm.rqly) .. "%", COLOR_THEME_SECONDARY1)
    drawDiverSym(73, Y, widget.ctx.isDiversity and tlm.ant)
    lcd.drawText(83, Y, "Signal " .. tostring(rssi), COLOR_THEME_SECONDARY1)
    lcd.drawText(widget.zw - 13, Y+3, "dBm", SMLSIZE + COLOR_THEME_SECONDARY1 + RIGHT)
  else
    lcd.drawText(1, Y, "Signal", COLOR_THEME_SECONDARY1)
    lcd.drawText(44, Y+2, "(dBm)", SMLSIZE + COLOR_THEME_SECONDARY1)
    drawDbms(82, Y, tlm.rssi1, tlm.rssi2, widget.ctx.isDiversity and tlm.ant)
    Y = Y + TH
    -- LQ on separate line
    lcd.drawText(1, Y + 1, "LQ " .. tostring(tlm.rqly) .. "%", COLOR_THEME_SECONDARY1)
    -- FMode
    if tlm.fmode then
      -- 1up on the right, fullscreen in the center
      if widget.size == 1 then
        lcd.drawText(widget.zw - 13, Y + 1, tlm.fmode, COLOR_THEME_SECONDARY1 + RIGHT)
      else
        lcd.drawText(widget.zw / 2, Y + 1, tlm.fmode .. " Mode", COLOR_THEME_SECONDARY1 + CENTER)
      end
    end -- if fmode
  end

  return Y
end

local function drawGps(widget, Y)
  lcd.drawText(1, Y, "Lat", COLOR_THEME_DISABLED)
  lcd.drawText(widget.zw - 32, Y, "N/S", COLOR_THEME_DISABLED)
  lcd.drawText(widget.zw / 2, Y, tostring(widget.gps.lat), COLOR_THEME_SECONDARY1 + CENTER)

  lcd.drawText(1, Y+TH, "Lon", COLOR_THEME_DISABLED)
  lcd.drawText(widget.zw - 32, Y+TH, "E/W", COLOR_THEME_DISABLED)
  lcd.drawText(widget.zw / 2, Y+TH, tostring(widget.gps.lon), COLOR_THEME_SECONDARY1 + CENTER)
end

local function updateGps(widget)
  -- Save the GPS to be able to display it if connection is lost
  -- Also called as "background"
  local gps = getV("GPS")
  if gps and gps ~= 0 then
    widget.gps = gps
  end
end

local function fieldGetString(data, off)
  local startOff = off
  while data[off] ~= 0 do
    data[off] = string.char(data[off])
    off = off + 1
  end

  return table.concat(data, nil, startOff, off - 1), off + 1
end

local function parseDeviceInfo(data)
  if data[2] ~= 0xEE then return end -- only interested in TX info
  local name, off = fieldGetString(data, 3)
  mod.name = name
  -- off = serNo ('ELRS') off+4 = hwVer off+8 = swVer
  mod.vMaj = data[off+9]
  mod.vMin = data[off+10]
  mod.vRev = data[off+11]
  mod.vStr = string.format("%s (%d.%d.%d)",
    mod.name, mod.vMaj, mod.vMin, mod.vRev)
  if mod.vMaj == 3 then
    mod.RFMOD = {"", "25Hz", "50Hz", "100Hz", "100HzFull", "150Hz", "200Hz", "250Hz", "333HzFull", "500Hz", "D250", "D500", "F500", "F1000" }
   -- Note: Always use 2.4 limits
    mod.RFRSSI = {-128, -123, -115, -117, -112, -112, -112, -108, -105, -105, -104, -104, -104, -104}
  else
    mod.RFMOD = {"", "25Hz", "50Hz", "100Hz", "150Hz", "200Hz", "250Hz", "500Hz"}
    mod.RFRSSI = {-128, -123, -115, -117, -112, -112, -108, -105}
  end
  return true
end

local function updateElrsVer()
  local command, data = crossfireTelemetryPop()
  if command == 0x29 then
    if parseDeviceInfo(data) then
      -- Get rid of all the functions, only update once
      parseDeviceInfo = nil
      fieldGetString = nil
      updateElrsVer = nil
      mod.lastUpd = nil
    end
    return
  end

  local now = getTime()
  -- Poll the module every second
  if (mod.lastUpd or 0) + 100 < now then
    crossfireTelemetryPush(0x28, {0x00, 0xEA})
    mod.lastUpd = now
  end
end

local function refresh(widget, event, touchState)
  -- Runs periodically only when widget instance is visible
  -- If full screen, then event is 0 or event value, otherwise nil
  --print(tostring(widget.zone.w) .. "x" .. tostring(widget.zone.h))
  if updateElrsVer then updateElrsVer() end
  updateWidgetSize(widget, event)
  lcd.drawFilledRectangle(0, 0, widget.zw, widget.zh, COLOR_THEME_PRIMARY2, 3 * widget.cfg.Transparency)
  local Y = 1

  local tlm = { tpwr = getV("TPWR") }
  if not widget.DEBUG and (tlm.tpwr == nil or tlm.tpwr == 0) then
    lcd.drawText(widget.zw / 2, Y, "No RX Connected", COLOR_THEME_PRIMARY1 + CENTER)
    Y = Y + TH
    if widget.gps == nil then
      local txName = mod.vStr or "or sensors discovered"
      lcd.drawText(widget.zw / 2, Y, txName, COLOR_THEME_SECONDARY1 + CENTER)
    else
      if widget.size < 3 then
        Y = Y + TH/2
        lcd.drawText(widget.zw / 2, Y, "Last GPS position", COLOR_THEME_PRIMARY1 + CENTER + SMLSIZE)
        Y = Y + TH
      end
      drawGps(widget, Y)
    end
    widget.ctx = nil
    return
  else
    updateGps(widget)
  end

  if widget.DEBUG then
    tlm.rfmd = 7 tlm.rssi1 = -87 tlm.rssi2 = -93 tlm.rqly = 99 tlm.ant = 1 tlm.tpwr = 50
  else
    tlm.rfmd = getV("RFMD") tlm.rssi1 = getV("1RSS") tlm.rssi2 = getV("2RSS") tlm.rqly = getV("RQly") tlm.ant = getV("ANT")
  end
  if widget.ctx == nil then
    widget.ctx = {}
  end
  if tlm.ant ~= 0 then
    widget.ctx.isDiversity = true
  end

  -- Range
  Y = drawRange(widget, tlm, Y)
  -- Rf Mode + FMode
  Y = drawRfModeText(widget, tlm, Y)
  -- RSSI / LQ + FMode
  Y = drawRssiLq(widget, tlm, Y)

  -- TX Power
  if widget.size < 4 then
    lcd.drawText(widget.zw - 13, widget.zh - 30, "Power", SMLSIZE + RIGHT + COLOR_THEME_SECONDARY2 + SHADOWED)
    lcd.drawText(widget.zw - 13, widget.zh - 18, tostring(tlm.tpwr) .. "mW", RIGHT + COLOR_THEME_PRIMARY3)
  else
    lcd.drawText(widget.zw - 13, widget.zh - 15, tostring(tlm.tpwr) .. "mW", SMLSIZE + RIGHT + COLOR_THEME_PRIMARY3)
  end
  drawPowerLvl(0, 6, 6, tlm.tpwr, widget.zw, widget.zh) -- uses 1W as max

  -- Extended FC Telemetry
  if widget.size < 3 then
    drawFcTelem(widget, tlm, Y)
  end
end

return {
  name = "ELRS Telem",
  options = {},
  create = create,
  update = update,
  refresh = refresh,
  background = updateGps,
  options = {
    { "Transparency", VALUE, 2, 0, 5 },
  }
}

