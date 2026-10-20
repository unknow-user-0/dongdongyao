;=====================================================================
; 洞洞妖 · 中文增强版
; 基于 窗口洞洞波 0.2（AutoHotkey v1.1）重写
; 中文界面 / 设置页（外观 · 快捷键 · 白名单）/ 五种形状 / 描边
;=====================================================================
#NoEnv
#SingleInstance, Force
#InstallKeybdHook
#UseHook
#Persistent
#MaxThreadsPerHotkey, 1
SetBatchLines, -1
SetWinDelay, -1
SetKeyDelay, -1
SetMouseDelay, -1
CoordMode, Mouse, Screen
ListLines, Off
DetectHiddenWindows, Off
SetTitleMatchMode, 2
Menu, Tray, Tip, 洞洞妖

CFG := {}
WL := []
STATE := {}
REG := []
REGU := []
INI_PATH := A_ScriptDir . "\setting.ini"
MY_PID := DllCall("GetCurrentProcessId")
PI := 3.14159265358979
TEST_HWND := 0
DBG := ""
MPX := -1
MPY := -1
MX := 0
MY := 0

Init()
if (A_Args[1] = "--selftest")
    Selftest()
else if (A_Args[1] = "--test")
    RunTest()
else if (A_Args[1] = "--gui")
    RunGui()
else if (A_Args[1] = "--grab")
    RunGrab()
return

;=====================================================================
; 初始化
;=====================================================================
Init() {
    global CFG, STATE
    STATE := {}
    STATE.holeOpen := 0
    STATE.target := 0
    STATE.paused := 0
    STATE.holes := []
    STATE.minimized := []
    STATE.guiOpen := 0
    STATE.guiHwnd := 0
    STATE.shapeVersion := 0
    STATE.secHole := 0
    STATE.secOn := 0
    STATE.aotAdded := 0
    STATE.ov1 := 0
    STATE.ov2 := 0
    STATE.polyBuf := 0
    STATE.outerBuf := 0
    STATE.polyN := 0
    STATE.maxr := 100
    STATE.borderHalf := 120

    LoadConfig()
    BuildShape()
    CreateBorder(1)
    CreateBorder(2)
    RegisterHotkeys()
    SetupTray()
    SaveConfig()
    OnExit("ExitHandler")
}

SetupTray() {
    global STATE
    Menu, Tray, NoStandard
    Menu, Tray, Add, 设置(&S)..., ShowSettings
    Menu, Tray, Add, 暂停快捷键(&P), TogglePause
    Menu, Tray, Add
    Menu, Tray, Add, 重新加载(&R), ReloadApp
    Menu, Tray, Add, 退出(&X), QuitApp
    Menu, Tray, Default, 设置(&S)...
    if (A_IsCompiled)
        Menu, Tray, Icon, %A_ScriptFullPath%, 1
    if (STATE.paused)
        Menu, Tray, Check, 暂停快捷键(&P)
    else
        Menu, Tray, Uncheck, 暂停快捷键(&P)
}

;=====================================================================
; 配置读写
;=====================================================================
LoadConfig() {
    global CFG, WL, INI_PATH
    CFG := {}
    CFG.radius := 300
    CFG.rate := 16
    CFG.shape := "circle"
    CFG.ellipse := 0
    CFG.ratio := "1:1"
    CFG.outline := 1
    CFG.outw := 2
    CFG.outcolor := "000000"
    CFG.hkHole := "``"
    CFG.hkSecond := "1"
    CFG.hkPause := "F9"

    WL := ["explorer.exe"]
    if !FileExist(INI_PATH)
        return
    txt := ReadFileUTF8(INI_PATH)
    if (txt = "")
        return

    section := ""
    wlNew := []
    wlSeen := 0
    Loop, Parse, txt, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        if (SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "#")
            continue
        if (SubStr(line, 1, 1) = "[") {
            p := InStr(line, "]")
            if p
                section := Trim(SubStr(line, 2, p - 2))
            else
                section := Trim(SubStr(line, 2))
            continue
        }
        eq := InStr(line, "=")
        if (eq) {
            key := Trim(SubStr(line, 1, eq - 1))
            val := Trim(SubStr(line, eq + 1))
        } else {
            key := ""
            val := line
        }
        if (section = "radius") {
            if (key = "radius")
                CFG.radius := Clamp(val + 0, 40, 700)
        } else if (section = "options") {
            if (key = "rate")
                CFG.rate := Clamp(val + 0, 5, 100)
            else if (key = "shape")
                CFG.shape := NormalizeShape(val)
            else if (key = "ellipse")
                CFG.ellipse := (val = "1" || val = "true") ? 1 : 0
            else if (key = "ratio")
                CFG.ratio := NormalizeRatio(val)
            else if (key = "outline")
                CFG.outline := (val = "1" || val = "true") ? 1 : 0
            else if (key = "outw")
                CFG.outw := Clamp(val + 0, 1, 10)
            else if (key = "outcolor")
                CFG.outcolor := NormalizeColor(val)
        } else if (section = "hotkeys") {
            if (key = "hole")
                CFG.hkHole := NormHk(val)
            else if (key = "second")
                CFG.hkSecond := NormHk(val)
            else if (key = "pause")
                CFG.hkPause := NormHk(val)
        } else if (section = "winlist") {
            wlSeen := 1
            if (val != "")
                wlNew.Push(val)
        }
    }
    if (wlSeen)
        WL := wlNew
}

SaveConfig() {
    global CFG, WL, INI_PATH
    txt := "[radius]`nradius=" . CFG.radius . "`n`n[options]`n"
    txt .= "rate=" . CFG.rate . "`n"
    txt .= "shape=" . CFG.shape . "`n"
    txt .= "ellipse=" . CFG.ellipse . "`n"
    txt .= "ratio=" . CFG.ratio . "`n"
    txt .= "outline=" . CFG.outline . "`n"
    txt .= "outw=" . CFG.outw . "`n"
    txt .= "outcolor=" . CFG.outcolor . "`n`n[hotkeys]`n"
    txt .= "hole=" . CFG.hkHole . "`n"
    txt .= "second=" . CFG.hkSecond . "`n"
    txt .= "pause=" . CFG.hkPause . "`n`n[winlist]`n"
    for i, v in WL
        txt .= v . "`n"
    WriteFileUTF8(INI_PATH, txt)
}

ReadFileUTF8(path) {
    if !FileExist(path)
        return ""
    FileEncoding, UTF-8
    txt := ""
    FileRead, txt, %path%
    return txt
}

WriteFileUTF8(path, txt) {
    f := FileOpen(path, "w", "UTF-8")
    if !f
        return 0
    f.Write(txt)
    f.Close()
    return 1
}

;=====================================================================
; 快捷键注册
;=====================================================================
RegisterHotkeys() {
    global CFG, REG, REGU
    for i, k in REGU {
        if (k != "")
            Hotkey, % k . " up",, Off
    }
    REGU := []
    for i, k in REG {
        if (k != "")
            Hotkey, %k%,, Off
    }
    REG := []
    STATE.secOn := 0
    if (CFG.hkHole != "") {
        Hotkey, % CFG.hkHole, HoleDown, UseErrorLevel
        if !ErrorLevel {
            Hotkey, % CFG.hkHole . " up", HoleUp, UseErrorLevel
            REG.Push(CFG.hkHole)
            REGU.Push(CFG.hkHole)
        }
    }
    if (CFG.hkPause != "" && CFG.hkPause != CFG.hkHole) {
        Hotkey, % CFG.hkPause, PauseDown, UseErrorLevel
        if !ErrorLevel
            REG.Push(CFG.hkPause)
    }
}

RegisterSecondKey(on) {
    global CFG
    if (CFG.hkSecond = "" || CFG.hkSecond = CFG.hkHole)
        return
    if (on) {
        Hotkey, % CFG.hkSecond, SecondDown, UseErrorLevel
        if ErrorLevel
            return
        Hotkey, % CFG.hkSecond . " up", SecondUp, UseErrorLevel
        STATE.secOn := (ErrorLevel = 0) ? 1 : 0
    } else {
        if !STATE.secOn
            return
        Hotkey, % CFG.hkSecond,, Off
        Hotkey, % CFG.hkSecond . " up",, Off
        STATE.secOn := 0
    }
}

;=====================================================================
; 热键处理
;=====================================================================
HoleDown:
    if (STATE.paused || STATE.holeOpen)
        return
    OpenHole()
return

HoleUp:
    if (STATE.holeOpen)
        CloseHole()
return

PauseDown:
    TogglePause()
return

SecondDown:
    if (STATE.paused || !STATE.holeOpen || STATE.secHole)
        return
    hw := GetRootWindow(ReadMouseHwnd())
    if (!hw || IsShellWindow(hw))
        return
    firstHw := 0
    if (STATE.holes.Length() > 0)
        firstHw := STATE.holes[1].hwnd
    if (hw + 0 = firstHw + 0)
        return
    STATE.holes.Push({hwnd: hw, border: 2, dx: -999999, dy: -999999, ww: 0, wh: 0, ver: -1})
    STATE.secHole := 1
    ReadMouse()
    ApplyHolePos(STATE.holes[STATE.holes.Length()], MX, MY)
return

SecondUp:
    if (!STATE.holeOpen || !STATE.secHole)
        return
    h := STATE.holes.Pop()
    ReleaseHole(h)
    HideBorder(2)
    STATE.secHole := 0
return

HoleTick:
    Tick()
return

;=====================================================================
; 开洞 / 收洞
;=====================================================================
OpenHole() {
    global STATE, CFG, MX, MY
    ReadMouse()
    mx := MX
    my := MY
    hw := GetRootWindow(ReadMouseHwnd())
    if !hw
        return
    if IsShellWindow(hw)
        return
    STATE.target := hw
    STATE.aotAdded := 0
    WinGet, ex, ExStyle, ahk_id %hw%
    if !(ex & 0x8) {
        WinSet, AlwaysOnTop, On, ahk_id %hw%
        STATE.aotAdded := 1
    }
    MinimizeOthers(hw)
    STATE.holes := []
    STATE.holes.Push({hwnd: hw, border: 1, dx: -999999, dy: -999999, ww: 0, wh: 0, ver: -1})
    STATE.secHole := 0
    STATE.holeOpen := 1
    SetTimer, HoleTick, % CFG.rate
    ApplyHolePos(STATE.holes[1], mx, my)
    RegisterSecondKey(1)
}

CloseHole() {
    global STATE, CFG
    SetTimer, HoleTick, Off
    if (IsObject(STATE.holes)) {
        for i, h in STATE.holes
            ReleaseHole(h)
    }
    STATE.holes := []
    HideBorder(1)
    HideBorder(2)
    STATE.holeOpen := 0
    STATE.secHole := 0
    if (IsObject(STATE.minimized)) {
        for i, w in STATE.minimized {
            if (w != "")
                DllCall("ShowWindow", "ptr", w, "int", 9)
        }
    }
    STATE.minimized := []
    tgt := STATE.target
    if (tgt && WinExist("ahk_id " . tgt)) {
        if (STATE.aotAdded)
            WinSet, AlwaysOnTop, Off, ahk_id %tgt%
        WinActivate, ahk_id %tgt%
    }
    STATE.aotAdded := 0
    RegisterSecondKey(0)
}

ReleaseHole(h) {
    if (!h || !h.hwnd)
        return
    DllCall("SetWindowRgn", "ptr", h.hwnd, "ptr", 0, "int", 1)
}

Tick() {
    global STATE, MX, MY
    if (!STATE.holeOpen)
        return
    ReadMouse()
    mx := MX
    my := MY
    for i, h in STATE.holes {
        if (h.hwnd)
            ApplyHolePos(h, mx, my)
    }
}

ApplyHolePos(h, mx, my) {
    global STATE, CFG
    if (!h || !h.hwnd)
        return
    if !WinExist("ahk_id " . h.hwnd)
        return
    WinGetPos, wx, wy, ww, wh, % "ahk_id " . h.hwnd
    if (wx = "" || ww = "" || ww < 2 || wh < 2)
        return
    dx := mx - wx
    dy := my - wy
    if !(h.dx = dx && h.dy = dy && h.ww = ww && h.wh = wh && h.ver = STATE.shapeVersion) {
        h.dx := dx
        h.dy := dy
        h.ww := ww
        h.wh := wh
        h.ver := STATE.shapeVersion
        SetHoleRegion(h.hwnd, dx, dy, ww, wh)
    }
    if (CFG.outline) {
        SetBorderRegion(h, mx, my, wx, wy, ww, wh)
    } else {
        HideBorder(h.border)
    }
}

SetHoleRegion(hwnd, dx, dy, ww, wh) {
    global STATE, CFG
    if !STATE.polyBuf
        return
    shape := DllCall("gdi32\CreatePolygonRgn", "ptr", STATE.polyBuf, "int", STATE.polyN, "int", 1, "ptr")
    if !shape
        return
    DllCall("gdi32\OffsetRgn", "ptr", shape, "int", dx, "int", dy)
    rect := DllCall("gdi32\CreateRectRgn", "int", 0, "int", 0, "int", ww, "int", wh, "ptr")
    dst := DllCall("gdi32\CreateRectRgn", "int", 0, "int", 0, "int", 0, "int", 0, "ptr")
    DllCall("gdi32\CombineRgn", "ptr", dst, "ptr", rect, "ptr", shape, "int", 4)
    DllCall("gdi32\DeleteObject", "ptr", rect)
    DllCall("gdi32\DeleteObject", "ptr", shape)
    DllCall("SetWindowRgn", "ptr", hwnd, "ptr", dst, "int", 1)
}

;=====================================================================
; 描边：独立覆盖窗 + 环形窗口区域
;=====================================================================
SetBorderRegion(h, mx, my, wx, wy, ww, wh) {
    global STATE
    if !STATE.polyBuf
        return
    half := STATE.borderHalf
    sz := half * 2
    ox := mx - half
    oy := my - half
    hwnd := (h.border = 1) ? STATE.ov1 : STATE.ov2
    if !hwnd
        return
    hOut := DllCall("gdi32\CreatePolygonRgn", "ptr", STATE.outerBuf, "int", STATE.polyN, "int", 1, "ptr")
    hIn := DllCall("gdi32\CreatePolygonRgn", "ptr", STATE.polyBuf, "int", STATE.polyN, "int", 1, "ptr")
    if (!hOut || !hIn)
        return
    DllCall("gdi32\OffsetRgn", "ptr", hOut, "int", half, "int", half)
    DllCall("gdi32\OffsetRgn", "ptr", hIn, "int", half, "int", half)
    ring := DllCall("gdi32\CreateRectRgn", "int", 0, "int", 0, "int", 0, "int", 0, "ptr")
    DllCall("gdi32\CombineRgn", "ptr", ring, "ptr", hOut, "ptr", hIn, "int", 4)
    l := wx - ox
    t := wy - oy
    clip := DllCall("gdi32\CreateRectRgn", "int", l, "int", t, "int", l + ww, "int", t + wh, "ptr")
    clipd := DllCall("gdi32\CreateRectRgn", "int", 0, "int", 0, "int", 0, "int", 0, "ptr")
    DllCall("gdi32\CombineRgn", "ptr", clipd, "ptr", ring, "ptr", clip, "int", 1)
    DllCall("gdi32\DeleteObject", "ptr", hOut)
    DllCall("gdi32\DeleteObject", "ptr", hIn)
    DllCall("gdi32\DeleteObject", "ptr", ring)
    DllCall("gdi32\DeleteObject", "ptr", clip)
    DllCall("SetWindowRgn", "ptr", hwnd, "ptr", clipd, "int", 1)
    MoveBorder(h.border, ox, oy, sz)
}

CreateBorder(which) {
    global CFG, STATE
    if (which = 1) {
        Gui, HB1: New, +AlwaysOnTop -Caption +ToolWindow +E0x08000000
        Gui, HB1: Color, % RgbToBgrHex(CFG.outcolor)
        Gui, HB1: Show, x-4000 y-4000 w10 h10 NoActivate
        Gui, HB1: +LastFound
        STATE.ov1 := WinExist()
    } else {
        Gui, HB2: New, +AlwaysOnTop -Caption +ToolWindow +E0x08000000
        Gui, HB2: Color, % RgbToBgrHex(CFG.outcolor)
        Gui, HB2: Show, x-4000 y-4000 w10 h10 NoActivate
        Gui, HB2: +LastFound
        STATE.ov2 := WinExist()
    }
}

MoveBorder(which, ox, oy, sz) {
    global STATE
    hwnd := (which = 1) ? STATE.ov1 : STATE.ov2
    if !hwnd
        return
    if (sz < 2)
        sz := 2
    if !DllCall("IsWindowVisible", "ptr", hwnd)
        DllCall("ShowWindow", "ptr", hwnd, "int", 4)
    DllCall("SetWindowPos", "ptr", hwnd, "ptr", -1, "int", ox, "int", oy, "int", sz, "int", sz, "uint", 0x0010)
}

HideBorder(which) {
    global STATE
    if (which = 1) {
        if (STATE.ov1)
            Gui, HB1: Hide
    } else {
        if (STATE.ov2)
            Gui, HB2: Hide
    }
}

ApplyBorderColor() {
    global CFG, STATE
    if (STATE.ov1)
        Gui, HB1: Color, % RgbToBgrHex(CFG.outcolor)
    if (STATE.ov2)
        Gui, HB2: Color, % RgbToBgrHex(CFG.outcolor)
}

;=====================================================================
; 形状生成
;=====================================================================
BuildShape() {
    global CFG, STATE
    pts := GetShapePoints()
    n := pts.Length()
    if (n < 3)
        return
    if (STATE.polyBuf)
        DllCall("GlobalFree", "ptr", STATE.polyBuf)
    if (STATE.outerBuf)
        DllCall("GlobalFree", "ptr", STATE.outerBuf)
    STATE.polyBuf := DllCall("GlobalAlloc", "uint", 0x40, "ptr", n * 8, "ptr")
    STATE.outerBuf := DllCall("GlobalAlloc", "uint", 0x40, "ptr", n * 8, "ptr")
    if (!STATE.polyBuf || !STATE.outerBuf)
        return
    STATE.polyN := n
    maxr := 1
    for i, p in pts {
        d := Sqrt(p.x * p.x + p.y * p.y)
        if (d > maxr)
            maxr := d
    }
    STATE.maxr := maxr
    k := (maxr + CFG.outw) / maxr
    for i, p in pts {
        off := (i - 1) * 8
        NumPut(p.x, STATE.polyBuf, off, "int")
        NumPut(p.y, STATE.polyBuf, off + 4, "int")
        NumPut(Round(p.x * k), STATE.outerBuf, off, "int")
        NumPut(Round(p.y * k), STATE.outerBuf, off + 4, "int")
    }
    STATE.borderHalf := Ceil(maxr + CFG.outw + 1)
    STATE.shapeVersion := STATE.shapeVersion + 1
}

GetShapePoints() {
    global CFG, PI
    pts := []
    shape := CFG.shape
    r := CFG.radius
    if (shape = "circle") {
        rx := r
        ry := r
        if (CFG.ellipse) {
            ParseRatio(CFG.ratio, ra, rb)
            if (ra = rb)
                ra := 4, rb := 3
            sc := r / Max(ra, rb)
            rx := ra * sc
            ry := rb * sc
        }
        n := Round(2 * PI * Max(rx, ry) / 4)
        n := Clamp(n, 72, 540)
        Loop, %n%
        {
            t := 2 * PI * (A_Index - 1) / n
            pts.Push({x: Round(rx * Cos(t)), y: Round(ry * Sin(t))})
        }
        return pts
    }
    if (shape = "square") {
        ParseRatio(CFG.ratio, ra, rb)
        sc := r / Sqrt(ra * ra + rb * rb)
        hw := ra * sc
        hh := rb * sc
        pts.Push({x: -hw, y: -hh}, {x: hw, y: -hh}, {x: hw, y: hh}, {x: -hw, y: hh})
        return pts
    }
    if (shape = "heart") {
        n := 90
        Loop, %n%
        {
            x := -2 + 4 * (A_Index - 1) / (n - 1)
            y := -Sqrt(1 - (Abs(x) - 1) ** 2)
            pts.Push({x: x, y: y})
        }
        Loop, %n%
        {
            x := 2 - 4 * (A_Index - 1) / (n - 1)
            y := 3 * Sqrt(1 - Sqrt(Abs(x / 2)))
            pts.Push({x: x, y: y})
        }
        return FitCircle(pts, r)
    }
    if (shape = "star") {
        Loop, 10
        {
            a := -PI / 2 + (A_Index - 1) * PI / 5
            rr := (Mod(A_Index, 2) = 1) ? 1.0 : 0.42
            pts.Push({x: rr * Cos(a), y: rr * Sin(a)})
        }
        return FitCircle(pts, r)
    }
    if (shape = "triangle") {
        Loop, 3
        {
            a := -PI / 2 + (A_Index - 1) * 2 * PI / 3
            pts.Push({x: Cos(a), y: Sin(a)})
        }
        return FitCircle(pts, r)
    }
    return pts
}

FitCircle(pts, r) {
    minx := 1.0e18
    maxx := -1.0e18
    miny := 1.0e18
    maxy := -1.0e18
    for i, p in pts {
        if (p.x < minx)
            minx := p.x
        if (p.x > maxx)
            maxx := p.x
        if (p.y < miny)
            miny := p.y
        if (p.y > maxy)
            maxy := p.y
    }
    cx := (minx + maxx) / 2
    cy := (miny + maxy) / 2
    maxd := 0.0001
    for i, p in pts {
        d := Sqrt((p.x - cx) ** 2 + (p.y - cy) ** 2)
        if (d > maxd)
            maxd := d
    }
    sc := r / maxd
    out := []
    for i, p in pts
        out.Push({x: Round((p.x - cx) * sc), y: Round((p.y - cy) * sc)})
    return out
}

FitBox(pts, bw, bh) {
    minx := 1.0e18
    maxx := -1.0e18
    miny := 1.0e18
    maxy := -1.0e18
    for i, p in pts {
        if (p.x < minx)
            minx := p.x
        if (p.x > maxx)
            maxx := p.x
        if (p.y < miny)
            miny := p.y
        if (p.y > maxy)
            maxy := p.y
    }
    dw := maxx - minx
    dh := maxy - miny
    sx := (dw > 0) ? bw / dw : 1
    sy := (dh > 0) ? bh / dh : 1
    s := Min(sx, sy)
    cx := (minx + maxx) / 2
    cy := (miny + maxy) / 2
    out := []
    for i, p in pts
        out.Push({x: Round((p.x - cx) * s), y: Round((p.y - cy) * s)})
    return out
}

;=====================================================================
; 最小化其他窗口
;=====================================================================
MinimizeOthers(target) {
    global WL, STATE, MY_PID
    STATE.minimized := []
    WinGet, tpid, PID, ahk_id %target%
    troot := DllCall("GetAncestor", "ptr", target, "uint", 4, "ptr")
    WinGet, list, List
    Loop, %list%
    {
        w := list%A_Index%
        if (w + 0 = target + 0)
            continue
        root := DllCall("GetAncestor", "ptr", w, "uint", 4, "ptr")
        if (root + 0 = target + 0 || root + 0 = troot + 0)
            continue
        WinGet, wpid, PID, ahk_id %w%
        if (wpid = MY_PID || wpid = tpid)
            continue
        if !IsAltTabWindow(w)
            continue
        WinGet, pname, ProcessName, ahk_id %w%
        if (pname = "")
            continue
        if IsWhitelisted(pname)
            continue
        WinGet, mm, MinMax, ahk_id %w%
        if (mm = -1)
            continue
        DllCall("ShowWindow", "ptr", w, "int", 6)
        STATE.minimized.Push(w)
    }
}

IsWhitelisted(name) {
    global WL
    for i, v in WL {
        if (v != "" && v = name)
            return 1
    }
    return 0
}

GetRootWindow(h) {
    if !h
        return 0
    return DllCall("GetAncestor", "ptr", h, "uint", 2, "ptr")
}

IsShellWindow(h) {
    WinGetClass, c, ahk_id %h%
    if (c = "Progman" || c = "WorkerW" || c = "Shell_TrayWnd" || c = "NotifyIconOverflowWindow")
        return 1
    return 0
}

;=====================================================================
; 暂停 / 退出
;=====================================================================
TogglePause() {
    global STATE
    STATE.paused := !STATE.paused
    if (STATE.paused) {
        if (STATE.holeOpen)
            CloseHole()
        Menu, Tray, Check, 暂停快捷键(&P)
        TrayTip, 洞洞妖, 快捷键已暂停。点托盘菜单「暂停快捷键」可恢复。, 2
    } else {
        Menu, Tray, Uncheck, 暂停快捷键(&P)
        TrayTip, 洞洞妖, 快捷键已恢复。, 2
    }
}

ReloadApp:
    SaveConfig()
    Reload
return

QuitApp:
    SaveConfig()
    if (STATE.holeOpen)
        CloseHole()
    ExitApp
return

ExitHandler() {
    global STATE
    if (STATE.holeOpen)
        CloseHole()
    return 0
}

;=====================================================================
; 设置窗口
;=====================================================================
ShowSettings() {
    global CFG, WL, STATE
    global Tab, SldRadius, TxtRadius, RadCircle, RadSquare, RadHeart, RadStar, RadTri
    global ChkEllipse, ChkOutline, SldOutW, TxtOutW, DdlRatio
    global SldRate, TxtRate, HkHole, HkSecond, HkPause, LvWL, EdNewWL
    if (STATE.guiOpen) {
        Gui, Settings: Show
        WinActivate, % "ahk_id " . STATE.guiHwnd
        return
    }
    if (STATE.holeOpen)
        CloseHole()
    STATE.guiOpen := 1

    hr := CFG.radius
    hop := CFG.rate
    how := CFG.outw
    hk1 := CFG.hkHole
    hk2 := CFG.hkSecond
    hk3 := CFG.hkPause

    cCircle := (CFG.shape = "circle") ? "Checked" : ""
    cSquare := (CFG.shape = "square") ? "Checked" : ""
    cHeart := (CFG.shape = "heart") ? "Checked" : ""
    cStar := (CFG.shape = "star") ? "Checked" : ""
    cTri := (CFG.shape = "triangle") ? "Checked" : ""
    cEll := CFG.ellipse ? "Checked" : ""
    cOut := CFG.outline ? "Checked" : ""

    Gui, Settings: New, +AlwaysOnTop, 洞洞妖 · 设置
    Gui, Settings: Default
    Gui, Settings: Font, s10, Microsoft YaHei
    Gui, Settings: Add, Tab3, x12 y12 w616 h420 vTab, 外观|快捷键|白名单

    ; ---------------- 外观 ----------------
    Gui, Settings: Tab, 外观
    Gui, Settings: Add, Text, x34 y58 w54, 半径
    Gui, Settings: Add, Slider, x88 y52 w340 Range40-700 TickInterval 100 ToolTip gOnRadius vSldRadius, %hr%
    Gui, Settings: Add, Text, x438 y58 w80 vTxtRadius, %hr% px

    Gui, Settings: Add, Text, x34 y98 w54, 形状
    Gui, Settings: Add, Radio, x90 y98 w70 vRadCircle gOnShape %cCircle%, 圆形
    Gui, Settings: Add, Radio, x164 y98 w70 vRadSquare gOnShape %cSquare%, 方形
    Gui, Settings: Add, Radio, x238 y98 w70 vRadHeart gOnShape %cHeart%, 心形
    Gui, Settings: Add, Radio, x312 y98 w80 vRadStar gOnShape %cStar%, 五星形
    Gui, Settings: Add, Radio, x396 y98 w70 vRadTri gOnShape %cTri%, 三角形

    Gui, Settings: Add, CheckBox, x90 y130 w230 vChkEllipse gOnEllipse %cEll%, 圆形时改用椭圆

    Gui, Settings: Add, Text, x34 y166 w56, 比例
    Gui, Settings: Add, DropDownList, x92 y162 w150 vDdlRatio gOnRatio, 1:1|1:2|2:1|3:4|4:3|9:16|16:9

    Gui, Settings: Add, CheckBox, x90 y200 w70 vChkOutline gOnOutline %cOut%, 描边
    Gui, Settings: Add, Button, x166 y195 w96 h26 gPickColor, 描边颜色
    Gui, Settings: Add, Text, x274 y200 w40, 粗细
    Gui, Settings: Add, Slider, x318 y194 w150 Range1-8 ToolTip gOnOutW vSldOutW, %how%
    Gui, Settings: Add, Text, x474 y200 w50 vTxtOutW, %how% px

    Gui, Settings: Add, Text, x34 y240 w80, 刷新间隔
    Gui, Settings: Add, Slider, x118 y234 w220 Range5-100 ToolTip gOnRate vSldRate, %hop%
    Gui, Settings: Add, Text, x346 y240 w110 vTxtRate, %hop% 毫秒

    Gui, Settings: Font, s9 cGray
    tip1 := "提示：按住挖洞键出洞、松开即收；洞内消失、外围保留。`n"
    tip1 .= "按住第二层键可在下面的窗口上再挖一个洞。"
    Gui, Settings: Add, Text, x34 y372 w566, %tip1%
    Gui, Settings: Font, s10 cBlack

    ; ---------------- 快捷键 ----------------
    Gui, Settings: Tab, 快捷键
    Gui, Settings: Add, Text, x34 y62 w110, 挖洞键
    Gui, Settings: Add, Hotkey, x150 y56 w240 vHkHole, %hk1%
    Gui, Settings: Add, Text, x34 y108 w110, 第二层键
    Gui, Settings: Add, Hotkey, x150 y102 w240 vHkSecond, %hk2%
    Gui, Settings: Add, Text, x34 y154 w110, 暂停 / 恢复键
    Gui, Settings: Add, Hotkey, x150 y148 w240 vHkPause, %hk3%

    Gui, Settings: Font, s9 cGray
    tip2 := "点一下输入框，再按想用的组合键即可。`n"
    tip2 .= "第二层键只在洞打开期间生效，所以设成 1、2 这类普通按键也不会影响平时打字。`n"
    tip2 .= "暂停键用于临时关掉挖洞功能，与托盘菜单里的「暂停快捷键」是同一个开关。"
    Gui, Settings: Add, Text, x34 y200 w570, %tip2%
    Gui, Settings: Font, s10 cBlack
    Gui, Settings: Add, Button, x34 y300 w130 h30 gResetHotkeys, 恢复默认按键

    ; ---------------- 白名单 ----------------
    Gui, Settings: Tab, 白名单
    Gui, Settings: Font, s9 cGray
    Gui, Settings: Add, Text, x34 y52 w560, 名单里的程序在挖洞时不会被最小化。
    Gui, Settings: Font, s10 cBlack
    Gui, Settings: Add, ListView, x34 y78 w566 h220 vLvWL, 程序名
    Gui, Settings: Add, Edit, x34 y312 w220 vEdNewWL
    Gui, Settings: Add, Button, x266 y307 w84 h30 gAddWL, 添加
    Gui, Settings: Add, Button, x360 y307 w176 h30 gGrabWL, 抓取运行中的程序
    Gui, Settings: Add, Button, x34 y352 w130 h30 gDelWL, 移除所选

    ; ---------------- 底部 ----------------

    Gui, Settings: Show, w640 h474
    Gui, Settings: +LastFound
    STATE.guiHwnd := WinExist()
    GuiControl, Settings: ChooseString, DdlRatio, % CFG.ratio
    SetGuiIcon(STATE.guiHwnd)
    FillWL()
    SyncShapeControls()
}

SyncShapeControls() {
    global CFG
    Gui, Settings: Default
    if (CFG.shape = "square" || (CFG.shape = "circle" && CFG.ellipse)) {
        GuiControl, Enable, DdlRatio
    } else {
        GuiControl, Disable, DdlRatio
    }
    if (CFG.shape = "circle")
        GuiControl, Enable, ChkEllipse
    else
        GuiControl, Disable, ChkEllipse
}

FillWL() {
    global WL
    Gui, Settings: Default
    LV_Delete()
    for i, v in WL
        LV_Add("", v)
}

AddWhitelist(name) {
    global WL
    if (name = "")
        return
    for i, v in WL {
        if (v = name)
            return
    }
    WL.Push(name)
}

;---------------------------------------------------------------------
; 设置窗口事件
;---------------------------------------------------------------------
OnRadius:
    Gui, Settings: Default
    GuiControlGet, v,, SldRadius
    CFG.radius := v + 0
    GuiControl,, TxtRadius, %v% px
    BuildShape()
return

OnRatio:
    Gui, Settings: Default
    GuiControlGet, v,, DdlRatio
    CFG.ratio := NormalizeRatio(v)
    BuildShape()
return

OnShape:
    Gui, Settings: Default
    GuiControlGet, c1,, RadCircle
    GuiControlGet, c2,, RadSquare
    GuiControlGet, c3,, RadHeart
    GuiControlGet, c4,, RadStar
    GuiControlGet, c5,, RadTri
    if (c1)
        CFG.shape := "circle"
    else if (c2)
        CFG.shape := "square"
    else if (c3)
        CFG.shape := "heart"
    else if (c4)
        CFG.shape := "star"
    else if (c5)
        CFG.shape := "triangle"
    BuildShape()
    SyncShapeControls()
return

OnEllipse:
    Gui, Settings: Default
    GuiControlGet, v,, ChkEllipse
    CFG.ellipse := v ? 1 : 0
    if (CFG.ellipse && NormalizeRatio(CFG.ratio) = "1:1") {
        CFG.ratio := "4:3"
        GuiControl, Settings: ChooseString, DdlRatio, % CFG.ratio
    }
    BuildShape()
    SyncShapeControls()
return

OnOutline:
    Gui, Settings: Default
    GuiControlGet, v,, ChkOutline
    CFG.outline := v ? 1 : 0
return

OnOutW:
    Gui, Settings: Default
    GuiControlGet, v,, SldOutW
    CFG.outw := v + 0
    GuiControl,, TxtOutW, %v% px
    BuildShape()
return

OnRate:
    Gui, Settings: Default
    GuiControlGet, v,, SldRate
    CFG.rate := v + 0
    GuiControl,, TxtRate, %v% 毫秒
return

PickColor:
    Gui, Settings: Default
    c := PickColorDialog(STATE.guiHwnd, CFG.outcolor)
    if (c != "") {
        CFG.outcolor := c
        ApplyBorderColor()
    }
return

ResetHotkeys:
    Gui, Settings: Default
    GuiControl,, HkHole, % "``"
    GuiControl,, HkSecond, 1
    GuiControl,, HkPause, F9
return

AddWL:
    Gui, Settings: Default
    GuiControlGet, n,, EdNewWL
    n := Trim(n)
    if (n = "")
        return
    if (SubStr(n, -3) != ".exe")
        n := n . ".exe"
    AddWhitelist(n)
    GuiControl,, EdNewWL,
    FillWL()
return

DelWL:
    Gui, Settings: Default
    rows := []
    row := 0
    Loop {
        row := LV_GetNext(row)
        if !row
            break
        rows.Push(row)
    }
    cnt := rows.Length()
    Loop, %cnt%
    {
        idx := rows[cnt - A_Index + 1]
        WL.RemoveAt(idx)
    }
    FillWL()
return

GrabWL:
    ShowGrab()
return

ApplySettings:
    SettingsCommit()
return

CloseSettings:
    SettingsCommit()
return

SettingsGuiClose:
    SettingsCommit()
return

SettingsGuiEscape:
    SettingsCommit()
return

SettingsCommit() {
    global CFG, STATE, WL
    global Tab, SldRadius, TxtRadius, RadCircle, RadSquare, RadHeart, RadStar, RadTri
    global ChkEllipse, ChkOutline, SldOutW, TxtOutW, DdlRatio
    global SldRate, TxtRate, HkHole, HkSecond, HkPause, LvWL, EdNewWL
    Gui, Settings: Default
    Gui, Settings: Submit, NoHide
    if (RadCircle)
        CFG.shape := "circle"
    else if (RadSquare)
        CFG.shape := "square"
    else if (RadHeart)
        CFG.shape := "heart"
    else if (RadStar)
        CFG.shape := "star"
    else if (RadTri)
        CFG.shape := "triangle"
    CFG.ellipse := ChkEllipse ? 1 : 0
    CFG.outline := ChkOutline ? 1 : 0
    CFG.radius := Clamp(SldRadius + 0, 40, 700)
    CFG.ratio := NormalizeRatio(DdlRatio)
    CFG.rate := Clamp(SldRate + 0, 5, 100)
    CFG.outw := Clamp(SldOutW + 0, 1, 10)
    CFG.hkHole := Trim(HkHole)
    CFG.hkSecond := Trim(HkSecond)
    CFG.hkPause := Trim(HkPause)
    if (CFG.hkHole = "")
        CFG.hkHole := Chr(96)
    if (CFG.hkSecond = "")
        CFG.hkSecond := "1"
    if (CFG.hkPause = "")
        CFG.hkPause := "F9"
    BuildShape()
    RegisterHotkeys()
    ApplyBorderColor()
    SaveConfig()
    Gui, Settings: Destroy
    STATE.guiOpen := 0
    STATE.guiHwnd := 0
}

;---------------------------------------------------------------------
; 抓取正在运行的程序
;---------------------------------------------------------------------
ShowGrab() {
    global LvGrab
    names := {}
    WinGet, list, List
    Loop, %list%
    {
        w := list%A_Index%
        if !IsAltTabWindow(w)
            continue
        WinGet, pname, ProcessName, ahk_id %w%
        if (pname = "")
            continue
        names[pname] := 1
    }
    arr := []
    for k in names
        arr.Push(k)
    arr := SortStrings(arr)

    Gui, Grab: New, +AlwaysOnTop, 选择要加入白名单的程序
    Gui, Grab: Default
    Gui, Grab: Font, s10, Microsoft YaHei
    Gui, Grab: Add, Text, x12 y12 w356, 勾选程序，然后点下方按钮加入白名单：
    Gui, Grab: Add, ListView, x12 y40 w356 h300 Checked vLvGrab, 程序名
    for i, n in arr
        LV_Add("", n)
    Gui, Grab: Add, Button, x12 y352 w180 h32 gGrabAdd, 添加到白名单
    Gui, Grab: Add, Button, x204 y352 w100 h32 gGrabCloseGui, 关闭
    Gui, Grab: Show, w380 h398
    Gui, Grab: +LastFound
    SetGuiIcon(WinExist())
}

GrabAdd:
    Gui, Grab: Default
    row := 0
    Loop {
        row := LV_GetNext(row, "Checked")
        if !row
            break
        LV_GetText(nm, row)
        AddWhitelist(nm)
    }
    FillWL()
    SaveConfig()
    Gui, Grab: Destroy
return

GrabCloseGui:
    Gui, Grab: Destroy
return

SortStrings(arr) {
    n := arr.Length()
    Loop, %n%
    {
        i := A_Index
        v := arr[i]
        j := i - 1
        While (j >= 1 && arr[j] > v) {
            arr[j + 1] := arr[j]
            j := j - 1
        }
        arr[j + 1] := v
    }
    return arr
}

;=====================================================================
; 颜色选择
;=====================================================================
PickColorDialog(owner, cur) {
    ps := A_PtrSize
    if (ps = 8) {
        sz := 72
        offOwner := 8
        offRgb := 24
        offCust := 32
        offFlags := 40
    } else {
        sz := 36
        offOwner := 4
        offRgb := 12
        offCust := 16
        offFlags := 20
    }
    VarSetCapacity(cust, 64, 0)
    Loop, 16
        NumPut(0x00FFFFFF, cust, (A_Index - 1) * 4, "uint")
    VarSetCapacity(cc, sz, 0)
    NumPut(sz, cc, 0, "uint")
    NumPut(owner, cc, offOwner, "ptr")
    NumPut(HexToBGR(cur), cc, offRgb, "uint")
    NumPut(&cust, cc, offCust, "ptr")
    NumPut(0x103, cc, offFlags, "uint")
    r := DllCall("comdlg32\ChooseColorW", "ptr", &cc)
    if !r
        return ""
    return BGRToHex(NumGet(cc, offRgb, "uint"))
}

RgbToBgrHex(c) {
    ; Gui, Color 的取值按 0xBBGGRR 解释，而配置里存的是 RRGGBB，故交换红蓝
    return SubStr(c, 5, 2) . SubStr(c, 3, 2) . SubStr(c, 1, 2)
}

HexToBGR(hex) {
    r := HexVal(SubStr(hex, 1, 2))
    g := HexVal(SubStr(hex, 3, 2))
    b := HexVal(SubStr(hex, 5, 2))
    return (b << 16) | (g << 8) | r
}

BGRToHex(v) {
    r := v & 0xFF
    g := (v >> 8) & 0xFF
    b := (v >> 16) & 0xFF
    return HexByte(r) . HexByte(g) . HexByte(b)
}

HexVal(s) {
    v := 0
    Loop, 2
    {
        c := SubStr(s, A_Index, 1)
        p := InStr("0123456789ABCDEF", c)
        if !p
            p := 0
        v := v * 16 + (p ? p - 1 : 0)
    }
    return v
}

HexByte(n) {
    static h := "0123456789ABCDEF"
    return SubStr(h, (n >> 4) + 1, 1) . SubStr(h, (n & 15) + 1, 1)
}

;=====================================================================
; 工具
;=====================================================================
NormHk(s) {
    s := Trim(s)
    if (s = Chr(96) . Chr(96))
        return Chr(96)
    return s
}

Clamp(v, lo, hi) {
    if (v < lo)
        return lo
    if (v > hi)
        return hi
    return v
}

NormalizeRatio(s) {
    s := Trim(s)
    ParseRatio(s, a, b)
    return a . ":" . b
}

ParseRatio(s, ByRef a, ByRef b) {
    a := 1
    b := 1
    p := InStr(s, ":")
    if (p) {
        a := SubStr(s, 1, p - 1) + 0
        b := SubStr(s, p + 1) + 0
    }
    if (a <= 0)
        a := 1
    if (b <= 0)
        b := 1
}

SetGuiIcon(hwnd) {
    if (!hwnd || !A_IsCompiled)
        return
    ps := A_PtrSize
    VarSetCapacity(hb, ps, 0)
    VarSetCapacity(hs, ps, 0)
    n := DllCall("shell32\ExtractIconExW", "wstr", A_ScriptFullPath, "int", 0, "ptr", &hb, "ptr", &hs, "uint", 1)
    if (n > 0) {
        hBig := NumGet(hb, 0, "ptr")
        hSml := NumGet(hs, 0, "ptr")
        if (hBig)
            DllCall("SendMessageW", "ptr", hwnd, "uint", 0x80, "ptr", 1, "ptr", hBig)
        if (hSml)
            DllCall("SendMessageW", "ptr", hwnd, "uint", 0x80, "ptr", 0, "ptr", hSml)
    }
}

NormalizeShape(s) {
    s := Trim(s)
    if (s = "circle" || s = "square" || s = "heart" || s = "star" || s = "triangle")
        return s
    return "circle"
}

NormalizeColor(c) {
    c := Trim(c)
    if RegExMatch(c, "^[0-9A-Fa-f]{6}$")
        return c
    return "FFD400"
}

;=====================================================================
; Alt-Tab 窗口判定（沿用原版逻辑）
;=====================================================================
IsAltTabWindow(hWnd) {
    static WS_EX_APPWINDOW := 0x40000
    static WS_EX_TOOLWINDOW := 0x80
    static DWMWA_CLOAKED := 14
    static DWM_CLOAKED_SHELL := 2
    static WS_EX_NOACTIVATE := 0x8000000
    static GA_PARENT := 1
    static GW_OWNER := 4
    static VirtualDesktopExist := ""
    static PropEnumProcEx := RegisterCallback("PropEnumProcEx", "Fast", 4)
    if (VirtualDesktopExist = "") {
        OSbuildNumber := StrSplit(A_OSVersion, ".")[3]
        if (OSbuildNumber < 14393)
            VirtualDesktopExist := 0
        else
            VirtualDesktopExist := 1
    }
    if !DllCall("IsWindowVisible", "uptr", hWnd)
        return
    cloaked := 0
    DllCall("DwmApi\DwmGetWindowAttribute", "uptr", hWnd, "uint", DWMWA_CLOAKED, "uint*", cloaked, "uint", 4)
    if (cloaked = DWM_CLOAKED_SHELL)
        return
    if (realHwnd(DllCall("GetAncestor", "uptr", hwnd, "uint", GA_PARENT, "ptr")) != realHwnd(DllCall("GetDesktopWindow", "ptr")))
        return
    WinGetClass, winClass, ahk_id %hWnd%
    if (winClass = "Windows.UI.Core.CoreWindow")
        return
    if (winClass = "ApplicationFrameWindow") {
        VarSetCapacity(ApplicationViewCloakType, 4, 0)
        DllCall("EnumPropsEx", "uptr", hWnd, "ptr", PropEnumProcEx, "ptr", &ApplicationViewCloakType)
        if (NumGet(ApplicationViewCloakType, 0, "int") = 1)
            return
    }
    WinGet, exStyles, ExStyle, ahk_id %hWnd%
    if (exStyles & WS_EX_APPWINDOW) {
        if DllCall("GetProp", "uptr", hWnd, "str", "ITaskList_Deleted", "ptr")
            return
        if (VirtualDesktopExist = 0) or IsWindowOnCurrentVirtualDesktop(hwnd)
            return 1
        else
            return
    }
    if (exStyles & WS_EX_TOOLWINDOW) or (exStyles & WS_EX_NOACTIVATE)
        return
    hprev := hwnd
    Loop {
        hprev := hwnd
        hwnd := DllCall("GetWindow", "uptr", hwnd, "uint", GW_OWNER, "ptr")
        if !hwnd {
            if DllCall("GetProp", "uptr", hprev, "str", "ITaskList_Deleted", "ptr")
                return
            if (VirtualDesktopExist = 0) or IsWindowOnCurrentVirtualDesktop(hprev)
                return 1
            else
                return
        }
        if DllCall("IsWindowVisible", "uptr", hwnd)
            return
        WinGet, exStyles, ExStyle, ahk_id %hwnd%
        if ((exStyles & WS_EX_TOOLWINDOW) or (exStyles & WS_EX_NOACTIVATE)) and !(exStyles & WS_EX_APPWINDOW)
            return
    }
}

IsWindowOnCurrentVirtualDesktop(hwnd) {
    static IVirtualDesktopManager := ""
    if (IVirtualDesktopManager = "") {
        try {
            IVirtualDesktopManager := ComObjCreate("{AA509086-5CA9-4C25-8F95-589D3C07B48A}", "{A5CD92FF-29BE-454C-8D04-D82879FB3F1B}")
        } catch {
            IVirtualDesktopManager := 0
        }
        if !IVirtualDesktopManager
            return 1
    }
    onCur := 1
    DllCall(NumGet(NumGet(IVirtualDesktopManager + 0), 3 * A_PtrSize), "ptr", IVirtualDesktopManager, "uptr", hwnd, "int*", onCur)
    return onCur
}

PropEnumProcEx(hWnd, lpszString, hData, dwData) {
    if (StrGet(lpszString, "UTF-16") = "ApplicationViewCloakType") {
        NumPut(hData, dwData + 0, 0, "int")
        return false
    }
    return true
}

realHwnd(hwnd) {
    VarSetCapacity(var, 8, 0)
    NumPut(hwnd, var, 0, "uint64")
    return NumGet(var, 0, "uint")
}

;=====================================================================
; 命令行自检（--selftest）
;=====================================================================
Selftest() {
    global CFG, STATE, WL
    f := A_ScriptDir . "\selftest_out.txt"
    if FileExist(f)
        FileDelete, %f%
    Trace(f, "enter selftest ov1=" . STATE.ov1 . " ov2=" . STATE.ov2)
    shapes := ["circle", "square", "heart", "star", "triangle"]
    for i, s in shapes {
        CFG.shape := s
        BuildShape()
        Trace(f, "shape=" . s . " n=" . STATE.polyN . " maxr=" . Round(STATE.maxr) . " half=" . STATE.borderHalf)
    }
    CFG.shape := "circle"
    CFG.ellipse := 1
    BuildShape()
    Trace(f, "ellipse n=" . STATE.polyN)
    CFG.ellipse := 0
    BuildShape()
    BuildShape()
    Trace(f, "before ShowSettings")
    ShowSettings()
    Trace(f, "settings_hwnd=" . STATE.guiHwnd)
    Sleep, 250
    Trace(f, "before commit")
    SettingsCommit()
    Trace(f, "commit shape=" . CFG.shape . " radius=" . CFG.radius . " rate=" . CFG.rate)
    SaveConfig()
    radiusBefore := CFG.radius
    CFG.radius := -1
    LoadConfig()
    Trace(f, "ini_roundtrip radius=" . CFG.radius . " (was " . radiusBefore . ")")
    Trace(f, "wl_count=" . WL.Length())
    Trace(f, "done")
    ExitApp
}

RunGui() {
    global STATE, CFG
    tab := (A_Args[2] != "") ? A_Args[2] + 0 : 1
    hold := (A_Args[3] != "") ? A_Args[3] + 0 : 3000
    ShowSettings()
    if (STATE.guiHwnd)
        GuiControl, Settings: Choose, Tab, %tab%
    SetTimer, GuiExit, -%hold%
    return
}

RunGrab() {
    ShowGrab()
    hold := (A_Args[2] != "") ? A_Args[2] + 0 : 3000
    SetTimer, GuiExit, -%hold%
}

GuiExit:
ExitApp

Trace(f, msg) {
    FileAppend, % msg . "`n", %f%, UTF-8
}

;---------------------------------------------------------------------
; 测试用：鼠标/窗口来源抽象
;---------------------------------------------------------------------
ReadMouse() {
    global MPX, MPY, MX, MY
    if (MPX >= 0 && MPY >= 0) {
        MX := MPX
        MY := MPY
        return
    }
    MouseGetPos, MX, MY
}

ReadMouseHwnd() {
    global TEST_HWND
    if (TEST_HWND)
        return TEST_HWND
    MouseGetPos,,, rh
    return rh
}

WindowRegionType(h) {
    r := DllCall("gdi32\CreateRectRgn", "int", 0, "int", 0, "int", 0, "int", 0, "ptr")
    t := DllCall("GetWindowRgn", "ptr", h, "ptr", r)
    DllCall("gdi32\DeleteObject", "ptr", r)
    return t
}

; --test <hwnd> <shape> <inverted> <outline> [hold_ms] [ellipse]
RunTest() {
    global CFG, STATE, TEST_HWND, MPX, MPY, REG
    f := A_ScriptDir . "\test_out.txt"
    FileDelete, %f%
    hwnd := A_Args[2] + 0
    CFG.shape := A_Args[3]
    CFG.outline := (A_Args[5] = "1") ? 1 : 0
    hold := (A_Args[6] = "") ? 2500 : A_Args[6] + 0
    CFG.ellipse := (A_Args[7] = "1") ? 1 : 0
    Trace(f, "test hwnd=" . hwnd . " shape=" . CFG.shape . " ratio=" . CFG.ratio . " out=" . CFG.outline . " ell=" . CFG.ellipse)
    BuildShape()
    Trace(f, "shape_n=" . STATE.polyN . " maxr=" . Round(STATE.maxr) . " half=" . STATE.borderHalf)
    TEST_HWND := hwnd
    WinGetPos, wx, wy, ww, wh, % "ahk_id " . hwnd
    MPX := wx + ww // 2
    MPY := wy + wh // 2
    Trace(f, "target=" . wx . "," . wy . " " . ww . "x" . wh . " mouse=" . MPX . "," . MPY)
    t := ""
    for i, k in REG {
        t .= k . " "
    }
    Trace(f, "hotkeys=" . t)
    Trace(f, "region_before=" . WindowRegionType(hwnd))
    OpenHole()
    Trace(f, "MARK1")
    Trace(f, "holeOpen=" . STATE.holeOpen . " minimized=" . STATE.minimized.Length())
    names := ""
    cnt := 0
    for i, w in STATE.minimized {
        WinGet, pn, ProcessName, ahk_id %w%
        if (cnt < 10)
            names .= pn . " "
        cnt := cnt + 1
    }
    Trace(f, "minimized_names=" . names)
    Trace(f, "region_open=" . WindowRegionType(hwnd))
    VarSetCapacity(RC, 16, 0)
    rr := DllCall("gdi32\CreateRectRgn", "int", 0, "int", 0, "int", 0, "int", 0, "ptr")
    DllCall("GetWindowRgn", "ptr", hwnd, "ptr", rr)
    DllCall("gdi32\GetRgnBox", "ptr", rr, "ptr", &RC)
    bl := NumGet(RC, 0, "int")
    bt := NumGet(RC, 4, "int")
    br := NumGet(RC, 8, "int")
    bb := NumGet(RC, 12, "int")
    Trace(f, "region_box=" . bl . "," . bt . " " . (br - bl) . "x" . (bb - bt))
    if (STATE.ov1) {
        WinGetPos, bx, by, bw, bh, % "ahk_id " . STATE.ov1
        Trace(f, "border1=" . bx . "," . by . " " . bw . "x" . bh . " region=" . WindowRegionType(STATE.ov1))
    Trace(f, "dbg=" . DBG)
    }
    if (STATE.ov2) {
        WinGetPos, b2x, b2y, b2w, b2h, % "ahk_id " . STATE.ov2
        Trace(f, "border2=" . b2x . "," . b2y . " " . b2w . "x" . b2h)
    }
    Sleep, %hold%
    CloseHole()
    Sleep, 400
    Trace(f, "region_closed=" . WindowRegionType(hwnd))
    Trace(f, "minimized_after=" . STATE.minimized.Length())
    Trace(f, "done")
    ExitApp
}

RegType(h) {
    rr := DllCall("gdi32\CreateRectRgn", "int", 0, "int", 0, "int", 0, "int", 0, "ptr")
    t := DllCall("GetWindowRgn", "ptr", h, "ptr", rr)
    DllCall("gdi32\DeleteObject", "ptr", rr)
    return t
}
