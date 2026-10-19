require "import"
import "android.widget.*"
import "android.view.*"
import "android.graphics.Color"
import "android.content.DialogInterface"
import "android.content.Intent"
import "android.net.Uri"

local windows = {}
local dlg = nil
local navStack = {}

windows[1] = {
  title = "about us",
  elements = {
    { type = "title" },
    { type = "textview", text = "Developed by  mezab ali" },
    { type = "textview", text = "This is a useful utility  only for Jieshuo screen reader ️ users .\n" },
    { type = "textview", text = "Join  the platforms mentioned above if you want essential  extensions, useful tools,, and Useful apps ." },
    
    -- Telegram Section
    { type = "textview", text = "--- Telegram ---" },
    { type = "linkbutton", label = "Discussion Group", url = "https://t.me/blindtechhubp2s" },
    { type = "linkbutton", label = "Blind Tech Hub", url = "https://t.me/blindtechhubq7c" },
    { type = "linkbutton", label = "SP Tech Hub", url = "https://t.me/S_P_Tech_Hub" },
    { type = "linkbutton", label = "Audio Tutorials", url = "https://t.me/+1Aazfn0FJ9oxZWE1" },
    { type = "linkbutton", label = "Music Channel", url = "https://t.me/Noncopyrightbackgrounmusic" },

    -- WhatsApp Section
    { type = "textview", text = "--- WhatsApp ---" },
    { type = "linkbutton", label = "World of VI Community", url = "https://chat.whatsapp.com/Kb3QOapabwZGOgzzO8FZof" },
    { type = "linkbutton", label = "Blind Tech Hub Channel", url = "https://whatsapp.com/channel/0029VbAVDj23AzNYccK2KR3T" },

    -- Resources Section
    { type = "textview", text = "--- Resources ---" },
    { type = "linkbutton", label = "YouTube Channel", url = "https://youtube.com/@blindtechhub-p2s" },
    { type = "linkbutton", label = "Official Website", url = "https://blind-tech-hub.vercel.app/" },
    { type = "linkbutton", label = "Official File Store", url = "https://drive.google.com/drive/folders/1gELqt9suCksO8SWvEZshmgbs_hrZLZHY" },

    { type = "button", label = "Back", targetId = 0 },
  }
}

local showScreen
showScreen = function(id, isBack)
  local winData = windows[id]
  if not winData then return end
  if not isBack then
    table.insert(navStack, id)
  end
  local layout = {
    LinearLayout,
    orientation = "vertical",
    layout_width = "fill",
    layout_height = "fill",
    backgroundColor = Color.parseColor("#121212"),
    padding = "16dp",
    {
      ScrollView,
      layout_width = "fill",
      layout_height = "fill",
      fillViewport = true,
      {
        LinearLayout,
        id = "container",
        orientation = "vertical",
        layout_width = "fill",
        layout_height = "wrap",
      }
    }
  }
  if dlg then dlg.dismiss() end
  dlg = LuaDialog(service)
  dlg.View = loadlayout(layout)
  for _, elem in ipairs(winData.elements) do
    if elem.type == "title" then
      local t = TextView(service)
      t.setText(winData.title)
      t.setTextSize(20)
      t.setTextColor(Color.WHITE)
      t.setPadding(10, 10, 10, 10)
      container.addView(t)
    elseif elem.type == "button" then
      local b = Button(service)
      b.setText(elem.label)
      b.setOnClickListener(function()
        if elem.targetId == 0 then
          if #navStack > 1 then
            table.remove(navStack)
            local prevId = navStack[#navStack]
            table.remove(navStack)
            showScreen(prevId, false)
          else
            if dlg then dlg.dismiss() end
          end
        elseif elem.targetId and windows[elem.targetId] then
          showScreen(elem.targetId, false)
        end
      end)
      container.addView(b)
    elseif elem.type == "clickable" then
      local l = LinearLayout(service)
      l.setOrientation(LinearLayout.VERTICAL)
      l.setPadding(20, 20, 20, 20)
      l.setClickable(true)
      l.setFocusable(true)
      local t = TextView(service)
      t.setText(elem.label)
      t.setTextColor(Color.WHITE)
      l.addView(t)
      l.setOnClickListener(function()
        if elem.targetId == 0 then
          if #navStack > 1 then
            table.remove(navStack)
            local prevId = navStack[#navStack]
            table.remove(navStack)
            showScreen(prevId, false)
          else
            if dlg then dlg.dismiss() end
          end
        elseif elem.targetId and windows[elem.targetId] then
          showScreen(elem.targetId, false)
        end
      end)
      container.addView(l)
    elseif elem.type == "edittext" then
      local e = EditText(service)
      if elem.hint and elem.hint ~= "" then
        e.setHint(elem.hint)
      end
      e.setTextColor(Color.WHITE)
      container.addView(e)
    elseif elem.type == "checkbox" then
      local c = CheckBox(service)
      c.setText(elem.label)
      c.setTextColor(Color.WHITE)
      container.addView(c)
    elseif elem.type == "textview" then
      local t = TextView(service)
      t.setText(elem.text)
      t.setTextColor(Color.WHITE)
      container.addView(t)
    elseif elem.type == "slider" then
      if elem.label and elem.label ~= "" then
        local t = TextView(service)
        t.setText(elem.label)
        t.setTextColor(Color.WHITE)
        container.addView(t)
      end
      local s = SeekBar(service)
      s.setMax(100)
      container.addView(s)
    elseif elem.type == "linkbutton" then
      local b = Button(service)
      b.setText(elem.label)
      b.setOnClickListener(function()
        if dlg then dlg.dismiss() end
        pcall(function()
          local intent = Intent(Intent.ACTION_VIEW, Uri.parse(elem.url))
          intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
          service.startActivity(intent)
        end)
      end)
      container.addView(b)
    elseif elem.type == "combobox" then
      if elem.label and elem.label ~= "" then
        local t = TextView(service)
        t.setText(elem.label)
        t.setTextColor(Color.WHITE)
        container.addView(t)
      end
      local s = Spinner(service)
      local opts = {}
      for opt in string.gmatch(elem.options or "", "[^,]+") do
        local trimmed = opt:match("^%s*(.-)%s*$")
        if trimmed ~= "" then table.insert(opts, trimmed) end
      end
      if #opts == 0 then table.insert(opts, "Option 1") end
      local adapter = ArrayAdapter(service, android.R.layout.simple_spinner_item, opts)
      adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
      s.setAdapter(adapter)
      container.addView(s)
    elseif elem.type == "togglebutton" then
      local b = Button(service)
      local opts = {}
      for opt in string.gmatch(elem.options or "", "[^,]+") do
        local trimmed = opt:match("^%s*(.-)%s*$")
        if trimmed ~= "" then table.insert(opts, trimmed) end
      end
      if #opts == 0 then table.insert(opts, "Option 1") end
      local idx = 1
      b.setText(opts[idx])
      b.setOnClickListener(function()
        idx = (idx % #opts) + 1
        b.setText(opts[idx])
      end)
      container.addView(b)
    end
  end
  dlg.setOnKeyListener(DialogInterface.OnKeyListener{
    onKey = function(dialog, keyCode, event)
      if keyCode == KeyEvent.KEYCODE_BACK and event.getAction() == KeyEvent.ACTION_UP then
        if #navStack > 1 then
          table.remove(navStack)
          local prevId = navStack[#navStack]
          table.remove(navStack)
          showScreen(prevId, false)
        else
          if dlg then dlg.dismiss() end
        end
        return true
      end
      return false
    end
  })
  dlg.show()
end

showScreen(1, false)