require "import"
import "android.widget.*"
import "android.view.*"
import "android.app.*"
import "android.media.MediaPlayer"
import "android.os.*"
import "android.content.*"
import "android.graphics.Color"
import "java.io.*"
import "java.net.*"

-- ============ CONTEXT ============
local ctx = nil
pcall(function()
  local a = luajava.bindClass("android.app.ActivityThread").currentActivity()
  if a ~= nil then a.getResources(); ctx = a end
end)
if not ctx then pcall(function()
  if activity ~= nil then activity.getResources(); ctx = activity end
end) end
if not ctx then pcall(function()
  if this ~= nil then this.getResources(); ctx = this end
end) end
if not ctx then pcall(function()
  ctx = luajava.bindClass("android.app.ActivityThread").currentApplication()
end) end

local uiHandler = Handler(Looper.getMainLooper())
local function runUI(fn) pcall(function() uiHandler.post(Runnable({ run = fn })) end) end

-- ============ STORAGE ============
local saveDir = "/storage/emulated/0/blind Tech hub/Google text to speech converter/"
local dataDir = saveDir .. ".data/"

local function canWriteDir(p)
  return pcall(function()
    local f = File(p); f.mkdirs()
    local tf = File(f, ".wt_" .. os.time() .. math.random(1000, 9999))
    local fos = FileOutputStream(tf); fos.write(65); fos.flush(); fos.close()
    tf.delete()
  end)
end

if not canWriteDir(saveDir) then
  if ctx then
    local ok, ext = pcall(function() return ctx.getExternalFilesDir(nil) end)
    if ok and ext then
      saveDir = ext.getAbsolutePath() .. "/Google text to speech converter/"
      dataDir = saveDir .. ".data/"
    end
  end
end
pcall(function() File(saveDir).mkdirs() end)
pcall(function() File(dataDir).mkdirs() end)

-- ============ ABOUT US SOURCE ============
local ABOUT_URL = "https://raw.githubusercontent.com/sajid86665-lgtm/Google-text-to-speech-converter/main/About%20us.lUA"

-- ============ NOTIFICATIONS ============
local notifMgr = nil
local notifIdGen = 7710
local CH_GEN = "tts_gen_channel"

local function initNotifications()
  if not ctx then return end
  pcall(function()
    notifMgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE)
    local Build = luajava.bindClass("android.os.Build")
    if Build.VERSION.SDK_INT >= 26 then
      local NotificationChannel = luajava.bindClass("android.app.NotificationChannel")
      local ch1 = NotificationChannel(CH_GEN, "TTS Generation", 2)
      ch1.setDescription("Audio generation progress")
      notifMgr.createNotificationChannel(ch1)
    end
  end)
end

local function showGenNotif(title, text, progress, maxProgress, ongoing)
  if not notifMgr then return end
  pcall(function()
    local Build = luajava.bindClass("android.os.Build")
    local Notification = luajava.bindClass("android.app.Notification")
    local b
    if Build.VERSION.SDK_INT >= 26 then
      b = Notification.Builder(ctx, CH_GEN)
    else
      b = Notification.Builder(ctx)
    end
    b.setContentTitle(title)
    b.setContentText(text)
    b.setSmallIcon(android.R.drawable.stat_sys_download)
    b.setOnlyAlertOnce(true)
    if progress ~= nil and maxProgress ~= nil and maxProgress > 0 then
      b.setProgress(maxProgress, progress, false)
    end
    if ongoing then b.setOngoing(true) end
    notifMgr.notify(notifIdGen, b.build())
  end)
end

local function cancelGenNotif()
  if not notifMgr then return end
  pcall(function() notifMgr.cancel(notifIdGen) end)
end

-- ============ LANGUAGES ============
local languages = {
  {"English (US)", "en"}, {"English (UK)", "en-GB"}, {"English (Australia)", "en-AU"},
  {"Hindi", "hi"}, {"Urdu", "ur"}, {"Bengali", "bn"},
  {"Tamil", "ta"}, {"Telugu", "te"}, {"Marathi", "mr"},
  {"Gujarati", "gu"}, {"Kannada", "kn"}, {"Malayalam", "ml"},
  {"Punjabi", "pa"}, {"Nepali", "ne"}, {"Sinhala", "si"},
  {"Arabic", "ar"}, {"Persian", "fa"}, {"Hebrew", "he"},
  {"Turkish", "tr"}, {"Greek", "el"}, {"Russian", "ru"},
  {"Ukrainian", "uk"}, {"Polish", "pl"}, {"Romanian", "ro"},
  {"Czech", "cs"}, {"Hungarian", "hu"}, {"Swedish", "sv"},
  {"Norwegian", "no"}, {"Danish", "da"}, {"Finnish", "fi"},
  {"French", "fr"}, {"Spanish", "es"}, {"German", "de"},
  {"Italian", "it"}, {"Portuguese", "pt"}, {"Dutch", "nl"},
  {"Japanese", "ja"}, {"Korean", "ko"},
  {"Chinese (Simplified)", "zh-CN"}, {"Chinese (Traditional)", "zh-TW"},
  {"Vietnamese", "vi"}, {"Thai", "th"}, {"Indonesian", "id"},
  {"Filipino", "fil"}, {"Swahili", "sw"}, {"Afrikaans", "af"},
}
local langNames = {}
for i = 1, #languages do langNames[i] = languages[i][1] end

-- ============ HELPERS ============
local function fmtTime(ms)
  if not ms or ms < 0 then return "0:00" end
  local s = math.floor(ms / 1000)
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function splitText(text)
  local chunks = {}
  local maxLen = 180
  text = text:gsub("[\r\n]+", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  while #text > maxLen do
    local cut = text:sub(1, maxLen)
    local pos = cut:match("^.*()%s")
    if not pos or pos < math.floor(maxLen / 2) then pos = maxLen + 1 end
    local chunk = text:sub(1, pos - 1):gsub("%s+$", "")
    if #chunk > 0 then table.insert(chunks, chunk) end
    text = text:sub(pos):gsub("^%s+", "")
  end
  if #text > 0 then table.insert(chunks, text) end
  return chunks
end

local function urlEncode(text)
  local enc = luajava.bindClass("java.net.URLEncoder").encode(text, "UTF-8")
  return enc:gsub("%+", "%%20")
end

local function sanitizeFilename(name)
  if not name or name:match("^%s*$") then return "TTS_" .. os.time() end
  name = name:gsub("[/\\:*?\"<>|]", "_"):gsub("^%s+", ""):gsub("%s+$", "")
  if not name:lower():match("%.mp3$") then name = name .. ".mp3" end
  return name
end

-- Resolve unique filename in saveDir (append _1, _2 if exists)
local function uniquePath(fname)
  local destPath = saveDir .. fname
  local counter = 1
  while File(destPath).exists() and counter < 1000 do
    local base = fname:gsub("%.mp3$", "")
    destPath = saveDir .. base .. "_" .. counter .. ".mp3"
    counter = counter + 1
  end
  return destPath
end

local function jbytesToLuaString(jbytes)
  if not jbytes then return "" end
  local len = jbytes.length
  if not len or len <= 0 then return "" end
  local parts = {}
  for i = 0, len - 1 do
    local b = jbytes[i]
    if b < 0 then b = b + 256 end
    parts[i + 1] = string.char(b)
  end
  return table.concat(parts)
end

local function luaStringToJbytes(s)
  local len = #s
  if len == 0 then return byte[0] end
  local arr = byte[len]
  for i = 1, len do
    local b = s:byte(i)
    if b > 127 then b = b - 256 end
    arr[i - 1] = b
  end
  return arr
end

local function writeFileText(path, text)
  if type(text) ~= "string" then
    pcall(function() text = tostring(text) end)
  end
  if type(text) ~= "string" then return false end

  local ok = pcall(function()
    local arr = luaStringToJbytes(text)
    local fos = FileOutputStream(path)
    if #text > 0 then fos.write(arr, 0, #text) end
    fos.close()
  end)
  if not ok then return false end
  local verify = File(path)
  return verify.exists() and verify.length() > 0
end

-- ============ DOWNLOAD AUDIO CHUNK ============
local function downloadChunk(encodedText, lang, outFile, append, callback)
  local url = "https://translate.googleapis.com/translate_tts?ie=UTF-8&q="
    .. encodedText .. "&tl=" .. lang .. "&client=gtx&ttsspeed=1"
  local TH = luajava.bindClass("java.lang.Thread")
  local RU = luajava.createProxy("java.lang.Runnable", { run = function()
    local success, errorMsg, bytesRead = false, nil, 0
    local ok, perr = pcall(function()
      local conn = URL(url).openConnection()
      conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 10)")
      conn.setRequestProperty("Referer", "https://translate.google.com/")
      conn.setRequestProperty("Accept-Encoding", "identity")
      conn.setConnectTimeout(30000)
      conn.setReadTimeout(30000)
      local code = conn.getResponseCode()
      if code ~= 200 then errorMsg = "HTTP " .. tostring(code); return end
      local is = conn.getInputStream()
      local fos = FileOutputStream(outFile, append)
      local buf = byte[8192]
      while true do
        local n = is.read(buf)
        if n == nil or n <= 0 then break end
        fos.write(buf, 0, n)
        bytesRead = bytesRead + n
      end
      fos.flush(); fos.close(); is.close()
      if bytesRead == 0 then errorMsg = "Empty response"; return end
      success = true
    end)
    if not ok then errorMsg = tostring(perr) end
    if errorMsg then success = false end
    runUI(function() callback(success, errorMsg, bytesRead) end)
  end })
  TH(RU).start()
end

-- ============ FETCH ABOUT US ============
local function fetchAboutUs(callback)
  local cachePath = dataDir .. "about_us.txt"

  local TH = luajava.bindClass("java.lang.Thread")
  local RU = luajava.createProxy("java.lang.Runnable", { run = function()
    local text = nil

    pcall(function()
      local conn = URL(ABOUT_URL).openConnection()
      conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 10)")
      conn.setRequestProperty("Cache-Control", "no-cache")
      conn.setConnectTimeout(15000)
      conn.setReadTimeout(15000)
      if conn.getResponseCode() == 200 then
        local is = conn.getInputStream()
        local bos = luajava.newInstance("java.io.ByteArrayOutputStream")
        local buf = byte[4096]
        while true do
          local n = is.read(buf)
          if n == nil or n <= 0 then break end
          bos.write(buf, 0, n)
        end
        is.close()
        text = jbytesToLuaString(bos.toByteArray())
        pcall(function() writeFileText(cachePath, text) end)
      end
    end)

    if not text then
      pcall(function()
        if File(cachePath).exists() then
          local ins = FileInputStream(cachePath)
          local bos = luajava.newInstance("java.io.ByteArrayOutputStream")
          local buf = byte[4096]
          while true do
            local n = ins.read(buf)
            if n == nil or n <= 0 then break end
            bos.write(buf, 0, n)
          end
          ins.close()
          text = jbytesToLuaString(bos.toByteArray())
        end
      end)
    end

    if text and type(text) ~= "string" then
      pcall(function() text = tostring(text) end)
    end

    runUI(function() callback(text) end)
  end })
  TH(RU).start()
end

-- ============ ABOUT PARSER ============
local FALLBACK_ABOUT = {
  { kind = "text", text = "Developed by mezab ali" },
  { kind = "text", text = "This is a useful utility only for Jieshuo screen reader users." },
  { kind = "link", label = "Discussion Group", url = "https://t.me/blindtechhubp2s" },
  { kind = "link", label = "Blind Tech Hub", url = "https://t.me/blindtechhubq7c" },
  { kind = "link", label = "SP Tech Hub", url = "https://t.me/S_P_Tech_Hub" },
  { kind = "link", label = "Audio Tutorials", url = "https://t.me/+1Aazfn0FJ9oxZWE1" },
  { kind = "link", label = "Music Channel", url = "https://t.me/Noncopyrightbackgrounmusic" },
  { kind = "link", label = "World of VI Community", url = "https://chat.whatsapp.com/Kb3QOapabwZGOgzzO8FZof" },
  { kind = "link", label = "Blind Tech Hub Channel", url = "https://whatsapp.com/channel/0029VbAVDj23AzNYccK2KR3T" },
  { kind = "link", label = "YouTube Channel", url = "https://youtube.com/@blindtechhub-p2s" },
  { kind = "link", label = "Official Website", url = "https://blind-tech-hub.vercel.app/" },
  { kind = "link", label = "Official File Store", url = "https://drive.google.com/drive/folders/1gELqt9suCksO8SWvEZshmgbs_hrZLZHY" },
}

local function parseAboutUs(src)
  local items = {}
  if not src or type(src) ~= "string" then return items end
  for typ, body in src:gmatch('{%s*type%s*=%s*"([^"]+)"([^}]*)}') do
    if typ == "textview" then
      local txt = body:match('text%s*=%s*"([^"]*)"')
      if txt then table.insert(items, { kind = "text", text = txt:gsub("\\n", "\n") }) end
    elseif typ == "linkbutton" then
      local label = body:match('label%s*=%s*"([^"]*)"')
      local url = body:match('url%s*=%s*"([^"]*)"')
      if label and url then table.insert(items, { kind = "link", label = label, url = url }) end
    end
  end
  return items
end

-- ============ ABOUT DIALOG ============
local function buildAboutDialog(items)
  local layout = { ScrollView; { LinearLayout; orientation = "vertical"; padding = "20dp"; } }
  local root = loadlayout(layout)
  local box = root.getChildAt(0)
  local white = Color.parseColor("#FFFFFF")
  pcall(function() box.setBackgroundColor(Color.parseColor("#121212")) end)

  local title = TextView(ctx)
  title.setText("About Us"); title.setTextSize(20); title.setTextColor(white)
  title.setPadding(20, 20, 20, 20)
  title.setFocusable(true); title.setFocusableInTouchMode(true)
  box.addView(title)

  for _, it in ipairs(items) do
    if it.kind == "text" then
      local tv = TextView(ctx)
      tv.setText(it.text); tv.setTextSize(14); tv.setTextColor(white)
      tv.setPadding(10, 10, 10, 10)
      box.addView(tv)
    else
      local b = Button(ctx)
      b.setText(it.label); b.setTextSize(15)
      b.setOnClickListener({ onClick = function(v)
        pcall(function()
          local Intent = luajava.bindClass("android.content.Intent")
          local Uri = luajava.bindClass("android.net.Uri")
          local i = Intent(Intent.ACTION_VIEW, Uri.parse(it.url))
          i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
          ctx.startActivity(i)
        end)
      end })
      box.addView(b)
    end
  end

  local back = Button(ctx)
  back.setText("Back"); back.setTextSize(15)
  box.addView(back)

  local dlg = LuaDialog()
  dlg.setTitle("About Us")
  dlg.setView(root)
  dlg.show()

  back.setOnClickListener({ onClick = function(v) dlg.dismiss() end })
  runUI(function() pcall(function() title.requestFocus() end) end)
end

local function showAboutUs()
  fetchAboutUs(function(text)
    local items = parseAboutUs(text)
    if not items or #items < 3 then items = FALLBACK_ABOUT end
    buildAboutDialog(items)
  end)
end

-- ============ PLAYER ============
local activePlayerDlg = nil
local activeMP = nil

local function closePlayerOnly()
  if activeMP then
    pcall(function() if activeMP.isPlaying() then activeMP.stop() end end)
    pcall(function() activeMP.release() end)
    activeMP = nil
  end
  if activePlayerDlg then
    pcall(function() activePlayerDlg.dismiss() end)
    activePlayerDlg = nil
  end
end

local showMainDialog = nil
local showPlayerError = nil

local function showPlayerDialog(filePath, savedName)
  closePlayerOnly()

  local mp = MediaPlayer()
  local ok = pcall(function() mp.setDataSource(filePath); mp.prepare() end)
  if not ok then
    pcall(function() mp.release() end)
    showPlayerError("Could not load audio file")
    return
  end
  activeMP = mp
  local duration = mp.getDuration()

  -- Player: heading, "Saved as:", time, Play, Back (no Download, no seekbar)
  local playerLayout = {
    ScrollView;
    {
      LinearLayout; orientation = "vertical"; padding = "20dp";
      { TextView; text = "Audio Generated Successfully";
        textSize = "20sp"; textColor = "#000000"; padding = "8dp";
        focusable = "true"; focusableInTouchMode = "true"; };
      { TextView; text = "Saved as: " .. savedName;
        textSize = "14sp"; textColor = "#006600"; padding = "4dp"; };
      { TextView; text = "Location: " .. saveDir;
        textSize = "12sp"; textColor = "#555555"; padding = "4dp"; };
      { TextView; text = "0:00 / " .. fmtTime(duration);
        textSize = "14sp"; textColor = "#555555"; padding = "6dp"; };
      { Button; text = "Play"; textSize = "16sp"; };
      { Button; text = "Back"; textSize = "16sp"; };
    }
  }

  local pRoot = loadlayout(playerLayout)
  local pContent    = pRoot.getChildAt(0)
  local heading     = pContent.getChildAt(0)
  local savedLabel  = pContent.getChildAt(1)
  local pathLabel   = pContent.getChildAt(2)
  local timeText    = pContent.getChildAt(3)
  local btnPlay     = pContent.getChildAt(4)
  local btnBack     = pContent.getChildAt(5)

  local isPlaying = false
  local progressRunnable = nil

  local function stopProgress()
    if progressRunnable then
      pcall(function() uiHandler.removeCallbacks(progressRunnable) end)
      progressRunnable = nil
    end
  end
  local function startProgress()
    stopProgress()
    progressRunnable = Runnable({ run = function()
      pcall(function()
        local pos = mp.getCurrentPosition()
        timeText.setText(fmtTime(pos) .. " / " .. fmtTime(duration))
      end)
      uiHandler.postDelayed(progressRunnable, 300)
    end })
    uiHandler.post(progressRunnable)
  end

  btnPlay.setOnClickListener({ onClick = function(v)
    if isPlaying then
      pcall(function() mp.pause() end)
      isPlaying = false; btnPlay.setText("Play"); stopProgress()
    else
      local ok2 = pcall(function() mp.start() end)
      if ok2 then
        isPlaying = true; btnPlay.setText("Pause"); startProgress()
      end
    end
  end })

  mp.setOnCompletionListener(MediaPlayer.OnCompletionListener({
    onCompletion = function(m)
      isPlaying = false
      btnPlay.setText("Play")
      timeText.setText(fmtTime(duration) .. " / " .. fmtTime(duration))
      stopProgress()
    end
  }))

  -- Back: close player, reopen main. File stays saved permanently.
  btnBack.setOnClickListener({ onClick = function(v)
    closePlayerOnly()
    if showMainDialog then showMainDialog() end
  end })

  local playerDlg = LuaDialog()
  playerDlg.setTitle("Player")
  playerDlg.setView(pRoot)
  playerDlg.show()
  activePlayerDlg = playerDlg

  pcall(function()
    playerDlg.setOnDismissListener(LuaDialog.OnDismissListener({
      onDismiss = function()
        if activePlayerDlg == playerDlg then closePlayerOnly() end
      end
    }))
  end)

  runUI(function()
    pcall(function()
      pRoot.scrollTo(0, 0)
      heading.requestFocus()
      heading.announceForAccessibility("Audio generated and saved as " .. savedName .. ". Play button available.")
    end)
  end)
end

-- ============ ERROR DIALOG ============
showPlayerError = function(errMsg)
  local layout = {
    ScrollView;
    { LinearLayout; orientation = "vertical"; padding = "20dp";
      { TextView; text = "Generation Failed";
        textSize = "20sp"; textColor = "#FF0000"; padding = "8dp";
        focusable = "true"; focusableInTouchMode = "true"; };
      { TextView; text = "Error: " .. tostring(errMsg);
        textSize = "14sp"; textColor = "#333333"; padding = "8dp"; };
      { Button; text = "Back"; textSize = "16sp"; };
    };
  }
  local root = loadlayout(layout)
  local c = root.getChildAt(0)
  local heading = c.getChildAt(0)
  local btnBack = c.getChildAt(2)

  btnBack.setOnClickListener({ onClick = function(v)
    closePlayerOnly()
    if showMainDialog then showMainDialog() end
  end })

  local dlg = LuaDialog()
  dlg.setTitle("Error")
  dlg.setView(root)
  dlg.show()
  activePlayerDlg = dlg

  pcall(function()
    dlg.setOnDismissListener(LuaDialog.OnDismissListener({
      onDismiss = function()
        if activePlayerDlg == dlg then closePlayerOnly() end
      end
    }))
  end)

  runUI(function()
    pcall(function()
      heading.requestFocus()
      heading.announceForAccessibility("Generation failed. " .. tostring(errMsg))
    end)
  end)
end

-- ============ SILENT GENERATION (DIRECT TO saveDir) ============
local function generateSilently(text, langCode, rawFilename, onComplete)
  -- Resolve unique final path in saveDir (no .tmp folder)
  local fname = sanitizeFilename(rawFilename)
  local destPath = uniquePath(fname)
  local finalName = File(destPath).getName()

  local chunks = splitText(text)
  local total = #chunks
  local idx = 1
  local failedErr = nil

  initNotifications()
  showGenNotif("Generating audio...", "0 / " .. total .. " chunks", 0, total, true)

  local function finishSuccess()
    local fsize = 0
    pcall(function() fsize = File(destPath).length() end)
    if fsize == 0 then
      pcall(function() File(destPath).delete() end)
      showGenNotif("Generation failed", "File empty", nil, nil, false)
      onComplete(nil, "File empty")
      return
    end
    pcall(function()
      local MSC = luajava.bindClass("android.media.MediaScannerConnection")
      MSC.scanFile(ctx, {destPath}, {"audio/mpeg"}, nil)
    end)
    showGenNotif("Audio ready", "Saved: " .. finalName, nil, nil, false)
    onComplete(destPath, nil, finalName)
  end

  local function nextOne()
    if failedErr then
      -- Delete partial file on failure
      pcall(function() File(destPath).delete() end)
      showGenNotif("Generation failed", tostring(failedErr), nil, nil, false)
      onComplete(nil, failedErr)
      return
    end
    if idx > total then
      finishSuccess()
      return
    end
    local encoded = urlEncode(chunks[idx])
    downloadChunk(encoded, langCode, destPath, idx > 1, function(ok2, err)
      if ok2 then
        idx = idx + 1
        showGenNotif("Generating audio...", idx .. " / " .. total .. " chunks", idx, total, true)
        nextOne()
      else
        failedErr = tostring(err)
        nextOne()
      end
    end)
  end
  nextOne()
end

-- ============ MAIN DIALOG ============
showMainDialog = function()
  local defaultName = "My_Audio_" .. os.time()

  local mainLayout = {
    ScrollView;
    {
      LinearLayout; orientation = "vertical"; padding = "16dp";

      { TextView; text = "Google Text to Speech Converter";
        textSize = "20sp"; textColor = "#000000";
        padding = "10dp"; focusable = "true"; focusableInTouchMode = "true"; };

      { TextView; text = "Text:";
        textSize = "14sp"; textColor = "#333333"; padding = "4dp"; };
      { EditText; hint = "Enter or paste your text here...";
        textSize = "16sp"; minLines = 4; gravity = "top|left";
        padding = "8dp"; };

      { TextView; text = "Language:";
        textSize = "14sp"; textColor = "#333333"; padding = "4dp"; };
      { Spinner; };

      { TextView; text = "File name:";
        textSize = "14sp"; textColor = "#333333"; padding = "4dp"; };
      { EditText; text = defaultName;
        textSize = "15sp"; minLines = 1; padding = "8dp"; };

      { Button; text = "Generate Audio"; textSize = "16sp"; };

      { TextView; text = "Status: Ready";
        textSize = "14sp"; textColor = "#FFFFFF";
        background = "#263238"; padding = "12dp";
        focusable = "true"; focusableInTouchMode = "true"; };

      { Button; text = "About Us"; textSize = "15sp"; };
      { Button; text = "Exit"; textSize = "15sp"; };
    }
  }

  local mainRoot     = loadlayout(mainLayout)
  local mainContent  = mainRoot.getChildAt(0)
  local heading      = mainContent.getChildAt(0)
  local inputText    = mainContent.getChildAt(2)
  local spinner      = mainContent.getChildAt(4)
  local filenameEdit = mainContent.getChildAt(6)
  local btnGen       = mainContent.getChildAt(7)
  local statusBar    = mainContent.getChildAt(8)
  local btnAboutUs   = mainContent.getChildAt(9)
  local btnExit      = mainContent.getChildAt(10)

  if ctx then
    pcall(function()
      local a = ArrayAdapter(ctx, android.R.layout.simple_spinner_item, langNames)
      a.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
      spinner.setAdapter(a); spinner.setSelection(3)
    end)
  end

  pcall(function()
    heading.setContentDescription("Google Text to Speech Converter heading")
    statusBar.setContentDescription("Status: Ready")
  end)

  pcall(function()
    mainRoot.setFocusable(true)
    mainRoot.setFocusableInTouchMode(true)
    mainRoot.setDescendantFocusability(android.view.ViewGroup.FOCUS_AFTER_DESCENDANTS)
  end)

  local dlgMain = LuaDialog()
  dlgMain.setTitle("Google Text to Speech Converter")
  dlgMain.setView(mainRoot)
  dlgMain.show()

  runUI(function()
    pcall(function()
      mainRoot.scrollTo(0, 0)
      heading.requestFocus()
      inputText.clearFocus()
    end)
  end)

  local function setStatus(text, color)
    runUI(function()
      pcall(function()
        statusBar.setText(text)
        if color then statusBar.setTextColor(color) end
      end)
    end)
  end

  btnAboutUs.setOnClickListener({ onClick = function(v) showAboutUs() end })

  btnExit.setOnClickListener({ onClick = function(v)
    closePlayerOnly()
    cancelGenNotif()
    dlgMain.dismiss()
  end })

  btnGen.setOnClickListener({ onClick = function(v)
    local txt = inputText.getText().toString() or ""
    if txt:match("^%s*$") then
      setStatus("Error: Text is empty - please enter text first", 0xFFFFCDD2)
      return
    end

    local langPos = 1
    pcall(function()
      local p = spinner.getSelectedItemPosition()
      if p >= 0 then langPos = p + 1 end
    end)
    if langPos > #languages then langPos = 1 end
    local langCode = languages[langPos][2]

    local rawName = ""
    pcall(function() rawName = filenameEdit.getText().toString() end)
    if not rawName or rawName:match("^%s*$") then
      rawName = "My_Audio_" .. os.time()
    end

    local capTxt = txt
    local capLang = langCode
    local capName = rawName

    dlgMain.dismiss()

    generateSilently(capTxt, capLang, capName, function(filePath, errMsg, savedName)
      if filePath then
        showPlayerDialog(filePath, savedName or "audio.mp3")
      else
        showPlayerError(tostring(errMsg))
      end
    end)
  end })

  return dlgMain
end

-- ============ START ============
initNotifications()
showMainDialog()