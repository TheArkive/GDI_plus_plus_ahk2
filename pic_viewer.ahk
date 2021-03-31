#INCLUDE gdi_plus_plus.ahk
; #INCLUDE gdip_class.ahk
; #INCLUDE TheArkive_WIC.ahk


OnExit(On_Exit)

; WM_EXITSIZEMOVE := 0x0232
OnMessage(0x232,resize_done)

cols := 4
rows := 4
go := false

g := Gui("+Resize -DpiScale")
g.OnEvent("size",gui_resize)
g.OnEvent("close",gui_close)
g.OnEvent("escape",gui_close)

gui_close(*) {
    ExitApp
}

g.Show("w1200 h800")
g.GetClientPos(&_x, &_y, &_w, &_h)

hDC := gdipp.GetDC(g.hwnd)

sFile := "" ; <---- pick a file to open
If !sFile {
    msgbox "pick a file first!  edit the script."
    return
}
img := gdipp.ImageFromFile(sFile)

; Some suggestions for big files to test with:
; https://www.wallpaperup.com/931329/STAR_WARS_BATTLEFRONT_sci-fi_1swbattlefront_action_fighting_futuristic_shooter.html
; https://www.desktopbackground.org/download/7680x4320/2015/04/02/926533_ultra-high-resolution-wallpapers-10240-6400-high-definition_10240x6400_h.jpg

; ==============================================================
; test saving - needs gdip_class.ahk (not available for now)
; ==============================================================
; gdi := gdip.Startup()
; gdip_bmp := gdi.BitmapFromHBITMAP(img2.ptr)
; gdip_bmp.SaveImage("test.png")
; msgbox "saved"
; gdip_bmp.Destroy()
; gdi.Shutdown()
; ==============================================================

d := img.ScaleToRect(_w,_h)
hDC.StretchBltMode := 4
hDC.DrawImageStretch(img,[0,0,d.w,d.h]) ; change to width,height to disable scaling
hDC.StretchBltMode := 3
brush := hDC.CreateBrush(0x080808)

go := true

gui_resize(_gui, MinMax, Width, Height) {
    Global
    Static last_min_max := 0
    
    If go {
        hDC.FillRect()
        d := img.ScaleToRect(width,height)
        hDC.DrawImageStretch(img,[0,0,d.w,d.h]) ; change to width,height to disable scaling
        
        If (last_min_max != MinMax) {
            hDC.StretchBltMode := 4
            r1 := hDC.DrawImageStretch(img,[0,0,d.w,d.h]) ; change to width,height to disable scaling
            hDC.StretchBltMode := 3
        }
    }
    last_min_max := MinMax
}

resize_done(wParam, lParam, msg, hwnd) {
    global
    
    If go {
        g.GetClientPos(&_x, &_y, &_w, &_h)
        d := img.ScaleToRect(_w,_h)
        hDC.StretchBltMode := 4
        hDC.DrawImageStretch(img,[0,0,d.w,d.h]) ; change to width,height to disable scaling
        hDC.StretchBltMode := 3
    }
}

On_Exit(ExitReason, ExitCode) {
    gdipp.CleanUp()
}

F2::{
    Global
    
}