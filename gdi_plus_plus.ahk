class gdipp {
    Static ObjList := []
    
    Static __New() {
        this.LoadConstants()
    }
    Static BGR_RGB(_c) { ; this conversion works both ways, it ignores 0xFF000000
        return (_c & 0xFF)<<16 | (_c & 0xFF00) | (_c & 0xFF0000)>>16 | (_c & 0xFF000000)
    }
    Static AGBR_RGBA(_c) { ; full reversal of ABGR/RGBA
        return (_c & 0xFF)<<16 | (_c & 0xFF00) | (_c & 0xFF0000)>>16 | (_c & 0xFF000000) >> 24
    }
    Static CleanUp() {
        i := gdipp.ObjList.Length
        Loop i {
            obj := gdipp.ObjList[gdipp.ObjList.Length]
            obj.Destroy() ; Destroy() method actually REMOVES the item!
        }
    }
    Static GetDC(hwnd:=0) {
        hDC := DllCall("user32\GetDC", "UPtr", hwnd, "UPtr")
        if hDC {
            gdipp.ObjList.Push(obj := gdipp.DC([hDC,0]))
            return obj
        }
    }
    Static ImageFromFile(sFileName, ICM:=0) { ; from robodesign version
        If !FileExist(sFileName)
            throw Exception("Image file does not exist:`r`n`r`n" sFileName)
        
        hModule := DllCall("LoadLibrary", "Str", "gdiplus", "UPtr") ; success > 0
        si := BufferAlloc((A_PtrSize=8)?24:16,0), NumPut("UInt", 1, si)
        r2 := DllCall("gdiplus\GdiplusStartup", "UPtr*", &pToken:=0, "UPtr", si.ptr, "UPtr", 0) ; success = 0
        
        r1 := DllCall("gdiplus\GdipCreateBitmapFromFile" (ICM?"ICM":""), "Str", sFileName, "UPtr*", &old_image:=0)
        If !old_image
            throw Exception("GDI+ Image object failed to load.") 
        
        DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "UPtr", old_image, "UPtr*", &hBMP:=0, "UInt", 0)
        If !hBMP
            throw Exception("GDI+ Image object conversion to HBITMAP failed.")
        
        DllCall("gdiplus\GdipDisposeImage", "UPtr", old_image)
        
        gdipp.ObjList.Push(obj := gdipp.Bitmap([hBMP,0])) ; bitmap_new
        
        r1 := DllCall("gdiplus\GdiplusShutdown", "UPtr", pToken)
        DllCall("FreeLibrary", "UPtr", hModule)
        
        return obj
    }
    
    
    ; ===================================================================
    ; Base Obj
    ; ===================================================================
    class base_obj {
        __New(p*) { ; p1 = _gdipp // p2 = ptr
            this.ptr := p[2][1]
            
            If (this.cType = "DC") {
                (p[2][2]=0) ? (this.release := "ReleaseDC") : (p[2][2]=1) ? (this.release := "DeleteDC") : ""
                this.StretchBltMode := 3 ; 3 = ColorOnColor / 4 = Halftone - 3 is a good default for speed
                this.CurBitmap := 0
                this.CurBrush := 0
            } Else If (this.cType != "DC")
                this.CurDC := 0
            
            t := this.GetObjectType()
            If (t="Bitmap") Or (t="Pen") Or (t="Brush") Or (t="ExtPen") Or (t="Font") ; maybe missing HPALLETTE
                this.GetObject()
            
            gdipp.ObjList.Push(this)
        }
        GetObject() {
            iSize := DllCall("GetObject", "UPtr", this.ptr, "UInt", 0, "UPtr", 0)
            info  := BufferAlloc(iSize,0)
            iWritten := DllCall("GetObject", "UPtr", this.ptr, "UInt", iSize, "UPtr", info.ptr)
            
            first_elem := NumGet(info,"UInt")
            
            If (this.cType = "Bitmap" And first_elem = 0) {
                this.__w := NumGet(info,4,"UInt"),       this.__planes  := NumGet(info,16,"UShort")
                this.__h := NumGet(info,8,"UInt"),       this.__bpp     := NumGet(info,18,"UShort")
                this.__stride := NumGet(info,12,"UInt"), this.__bPtr    := NumGet(info,((A_PtrSize=8)?24:20), "UPtr")
                
                If (!this.__bPtr) { ; for DDB
                    this.__bpp := this.__stride
                    this.__stride := Round(this.__w * (this.__bpp/8))
                }
            } Else If (this.cType = "Brush") {
                
            }
            ; need to add more entries for pens, brush, etc...
        }
        __Delete() {
            this.Destroy()
        }
        Clean_Up(destroy:=true) {
            For i, obj in gdipp.ObjList {
                If (obj.ptr = this.ptr) {
                    (destroy) ? obj.Destroy() : ""
                    gdipp.ObjList.RemoveAt(i)
                    Break
                }
            }
        }
        CompatDC(hDC:=0) {
            hDC := DllCall("CreateCompatibleDC", "UPtr", hDC?hDC.ptr:0, "UPtr") ; 0 = memory DC
            If !hDC
                throw Exception("Compatible DC creation failed.")
            
            gdipp.ObjList.Push(obj := gdipp.DC([hDC,1]))
            return obj
        }
        CreateBitmap(hDC, w, h) {
            hBMP := DllCall("gdi32\CreateCompatibleBitmap", "UPtr", hDC.ptr, "Int", w, "Int", h)
            
            gdipp.ObjList.Push(hBitmap := gdipp.Bitmap([hBMP,0])) ; bitmap_new
            return hBitmap
        }
        CreateDIBSection(hDC, w, h, bpp:=32) {
            bi := BufferAlloc(40, 0)
            NumPut("UInt", 40, bi, 0        ; struct size
                  ,"UInt", w, bi, 4         ; image width
                  ,"UInt", h, bi, 8         ; image height
                  ,"UShort", 1, bi, 12      ; planes
                  ,"UShort", bpp, bi, 14    ; bpp / color depth
                  ,"UInt", 0, bi, 16)       ; 
            
            hBMP := DllCall("gdi32\CreateDIBSection", "UPtr", hDC.ptr
                                                    , "UPtr", bi.ptr    ; BITMAPINFO
                                                    , "UInt", Usage:=0
                                                    , "UPtr*", &ppvBits:=0
                                                    , "UPtr", hSection:=0
                                                    , "UInt", OffSet:=0, "UPtr")
            
            gdipp.ObjList.Push(hBitmap := gdipp.Bitmap([hBMP,0])) ; bitmap_new
            return hBitmap
        }
        Destroy(r1 := "") {
            If !this.ptr
                return
            
            If (this.cType = "DC")
                r1 := DllCall(this.release, "UPtr", this.ptr) ; ReleaseDC?
            Else If (this.cType = "Bitmap")
                r1 := DllCall("DeleteObject", "UPtr", this.ptr)
            Else If (this.cType = "Brush")
                r1 := DllCall("DeleteObject", "UPtr", this.ptr)
            
            If (r1="")
                throw Exception("Error on obj release, or object not yet supported."
                              ,,"Obj Type: " this.cType "`r`nObj Ptr: " this.ptr)
        }
        GetObjectType() {
            Static types := ["Pen","Brush","DC","MetaDC","PAL","Font","Bitmap","Region"
                           , "MetaFile","MemDC","ExtPen","EnhMetaDC","EnhMetaFIle","ColorSpace"]
            
            result := DllCall("gdi32\GetObjectType", "UPtr", this.ptr)
            return (!result) ? 0 : types[result]
        }
        cType[] {
            get => StrReplace(this.__Class,"gdipp.","")
        }
    }
    
    ; ===================================================================
    ; Brush - mostly LOGBRUSH
    ; ===================================================================
    ; Brush & Hatch Styles: https://docs.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-logbrush
    ;   - Brush: DibPattern, DibPattern8x8, DibPatternPT, Hatched, Hollow, Pattern, Pattern8x8, Solid (default)
    ;   - Hatch: BDiagonal, Cross, DiagCross, FDiagonal, Horizontal (default), Vertical
    ;   NOTE: For corresponding integer values, see constants below in .LoadConstants() method.
    class Brush extends gdipp.base_obj {
        ; style[t:=0] {
            ; get {
                ; _r := NumGet(this.struct, "UInt")
                ; return t ? gdipp.GetFlag(_r,"BrushTypes") : _r
            ; }
            ; set {
                ; NumPut("UInt", (t ? gdipp.BrushTypes[value] : value), this.struct)
            ; }
        ; }
        color[r:=0] { ; reverse BGR to RGB if r > 0 ; GetDCBrushColor
            get {
                color := DllCall("gdi32\GetDCBrushColor", this.CurDC.ptr) << 32 >> 32
                return (r) ? gdipp.BGR_RGB(color) : color
            }
            set {
                DllCall("gdi32\SetDCBrushColor", "UPtr", this.CurDC.ptr, "UInt", gdipp.BGR_RGB(value))
            }
        }
        ; hatch[t:=0] {
            ; get {
                ; _h := NumGet(this.struct, 8, "UPtr")
                ; result := (t and _h>5) ? gdipp.GetFlag(_h,"HatchTypes") : _h
                ; return result
            ; }
            ; set {
                ; HS_TYPE := t ? gdipp.HatchTypes[value] : value
                ; NumPut("UPtr", HS_TYPE, this.struct, 8)
            ; }
        ; }
    }
    
    ; ===================================================================
    ; Bitmap obj (previously HBITMAP)
    ; ===================================================================
    class Bitmap extends gdipp.base_obj {
        CopyToClipboard() { ; thanks to guest3456 (mmikeww) for several details to this function
            r1 := DllCall("OpenClipboard", "UPtr", 0) ; was "hwnd"
            r2 := DllCall("EmptyClipboard")
            If !r2 {
                msgbox "Error:  Clipboard could not be emptied."
                DllCall("CloseClipboard")
                Return
            }
            
            oi:=BufferAlloc((A_PtrSize = 8) ? 104 : 84, 0)
            iWritten := DllCall("GetObject", "UPtr", this.ptr, "int", oi.Size, "UPtr", oi.ptr)
            
            hDib := BufferAlloc(40+this.size)
            r0 := DllCall("RtlMoveMemory", "UPtr", hDib.ptr, "UPtr", oi.ptr+((A_PtrSize=8)?32:24), "UPtr", 40)
            r1 := DllCall("RtlMoveMemory", "UPtr", hDib.ptr+40, "UPtr", this.bPtr, "UPtr", this.size)
            r3 := DllCall("SetClipboardData", "uint", 8, "UPtr", hdib.ptr) ; CF_BITMAP = 2 ; CF_DIB = 8
            DllCall("CloseClipboard")
        }
        ScaleToRect(w,h:=0) {
            w := Round(w)
            (h=0) ? h:=w : ""
            h := Round(h)
            
            xR := w/this.w, yR := h/this.h      ; Define xRatio and yRatio for resize.
            smallest := (xR<yR) ? "xR" : "yR"   ; Identify smallest ratio.
            
            new_W := Round(this.w * %smallest%) ; Apply ratios.
            new_H := Round(this.h * %smallest%)
            (w-new_W=1) ? new_W += 1 : ""       ; Check for 1 px diff on both x and y axis.
            (h-new_H=1) ? new_H += 1 : ""
            
            new_X := (new_W=w) ? 0 : ((w//2)-(new_W//2))    ; Set new x.
            new_Y := (new_H=h) ? 0 : ((h//2)-(new_H//2))    ; Set new y.
            return {w:new_W, h:new_H, x:new_X, y:new_Y}
        }
        bpp[] {
            get => this.__bpp
        }
        bPtr[] { ; pointer to bitmap data
            get => this.__bPtr
        }
        planes[] { ; this is usually 1
            get => this.__planes
        }
        size[] {
            get => this.__h * this.__stride
        }
        stride[] {
            get => this.__stride
        }
        type[] {
            get => (this.bPtr) ? "DIB" : "DDB"
        }
        w[] {
            get => this.__w
        }
        h[] {
            get => this.__h
        }
    }
    
    ; ===================================================================
    ; Device Context obj
    ; ===================================================================
    class DC extends gdipp.base_obj { ; maybe have param to specify BltStretchMode() 
        Clone() {
            return this.CompatDC(this)
        }
        CreateBrush(ColorRef:=0x00000000, _type:="solid", _hatch:="Horizontal") {
            LOGBRUSH := BufferAlloc((A_PtrSize=8)?16:12,0)
            
            BR_TYPE  := IsInteger(_type) ? _type : gdipp.BrushTypes[_type]
            COLORREF := gdipp.BGR_RGB(ColorRef) ; reverse input RGB to BGR, leave alpha
            HS_TYPE  := IsInteger(_hatch) ? _hatch : gdipp.HatchTypes[_hatch]
            
            NumPut("UInt", BR_TYPE, "UInt", COLORREF, "UPtr", HS_TYPE, LOGBRUSH) ; HS_TYPE can also be a ptr to a packed DIB
            
            pLogbrush := DllCall("gdi32\CreateBrushIndirect", "UPtr", LOGBRUSH.ptr)
            gdipp.ObjList.Push(brush := gdipp.Brush([pLogbrush,0]))
            this.SelectObject(brush)
            
            return brush
        }
        DrawImage(img, _d:=0, _s:=0, Raster:=0) { ; thanks to mmikeww and GeekDude for some details on this func
            (!_d) ? (_d := [0,0]) : ""
            (_d.Length=2) ? (_d.Push(img.w), _d.Push(img.h)) : ""
            (!_s) ? _s := [0,0] : ""
            
            this.SelectObject(tempDC := this.CompatDC(this), img)
            
            r1 := DllCall("gdi32\BitBlt", "UPtr", this.ptr, "int", _d[1], "int", _d[2], "int", _d[3], "int", _d[4] ; dest DC
                                        , "UPtr", tempDC.ptr,   "int", _s[1], "int", _s[2] ; src DC
                                        , "UInt", Raster?Raster:0x00CC0020)
            tempDC.Destroy()
            return r1
        }
        DrawImageAlpha(img, _d:=0, alpha:=255, _s:=0) { ; thanks to mmikeww and GeekDude for some details on this func
            (!_d) ? (_d := [0,0]) : ""
            (_d.Length=2) ? (_d.Push(img.w), _d.Push(img.h)) : ""
            (!_s) ? _s := [0,0,img.w,img.h] : ""
            
            this.SelectObject(tempDC := this.CompatDC(this), img)
            
            r1 := DllCall("msimg32\AlphaBlend", "UPtr", this.ptr,   "int", _d[1], "int", _d[2], "int", _d[3], "int", _d[4] ; dest DC
                                              , "UPtr", tempDC.ptr, "int", _s[1], "int", _s[2], "int", _s[3], "int", _s[4] ; src DC
                                              , "UInt", alpha<<16|1<<24)
            
            tempDC.Destroy()
            return r1
        }
        DrawImageStretch(img, _d:=0, _s:=0, Raster:=0) { ; thanks to mmikeww and GeekDude for some details on this func
            (!_d) ? (_d := [0,0]) : ""
            (_d.Length=2) ? (_d.Push(img.w), _d.Push(img.h)) : ""
            (!_s) ? _s := [0,0,img.w,img.h] : ""
            
            this.SelectObject(tempDC := this.CompatDC(), img)
            
            r1 := DllCall("gdi32\StretchBlt", "UPtr", this.ptr, "int", _d[1], "int", _d[2], "int", _d[3], "int", _d[4] ; dest DC
                                            , "UPtr", tempDC.ptr, "int", _s[1], "int", _s[2], "int", _s[3], "int", _s[4] ; src DC
                                            , "UInt", Raster ? Raster : 0x00CC0020)
            
            tempDC.Destroy()
            return r1
        }
        DrawImageTrans(img, _d:=0, _s:=0, trans_color:=0) { ; thanks to GeekDude for his comments on this func
            (!_d) ? (_d := [0,0]) : ""
            (_d.Length=2) ? (_d.Push(img.w), _d.Push(img.h)) : ""
            (!_s) ? _s := [0,0,img.w,img.h] : ""
            
            this.SelectObject(tempDC := this.CompatDC(), img)
            
            r1 := DllCall("msimg32\TransparentBlt", "UPtr", this.ptr, "int", _d[1], "int", _d[2], "int", _d[3], "int", _d[4] ; dest DC
                                                  , "UPtr", tempDC.ptr, "int", _s[1], "int", _s[2], "int", _s[3], "int", _s[4] ; src DC
                                                  , "UInt", trans_color)
            
            tempDC.Destroy()
            return r1
        }
        FillRect(_RECT:=0, hBrush:=0) {
            (!_RECT) ? (_RECT := [0,0,this.w,this.h]) : "" ; apply to full DC when _RECT omitted
            
            RECT := BufferAlloc(16,0)
            For i, value in _RECT
                NumPut("UInt", value, RECT, (A_Index-1) * 4)
            
            _brush := (!hBrush) ? this.CurBrush : hBrush ; use CurBrush or use specified brush
            If !_brush
                throw Exception("Invalid brush selected for operation.")
            
            return DllCall("user32\FillRect", "UPtr", this.ptr, "UPtr", RECT.ptr, "UPtr", _brush.ptr)
        }
        Flush() {
            return DllCall("gdi32\GdiFlush")
        }
        GetBitmap(w:=0, h:=0, Raster:=0) { ; considering:   _type:="DIB", always use default raster?
            (!w) ? w := this.w : ""
            (!h) ? h := this.h : ""
            
            new_BMP := this.CreateDIBSection(tempDC := this.CompatDC(), w, h)
            tempDC.SelectObject(new_BMP)
            
            r1 := DllCall("gdi32\StretchBlt", "UPtr", this.ptr, "int", 0, "int", 0, "int", w, "int", h ; dest DC
                                            , "UPtr", tempDC.ptr, "int", 0, "int", 0, "int", w, "int", h ; src DC
                                            , "UInt", Raster ? Raster : 0x00CC0020)
            
            tempDC.Destroy()
            return new_BMP
        }
        SelectObject(p*) {
            If (p.Length = 1)
                DC := this, CurObj := p[1]
            Else If (p.Length = 2)
                DC := p[1], CurObj := p[2]
            Else If (!p.Length Or p.Length > 2)
                throw Exception("Invalid number of parameters.")
            
            _type := CurObj.cType
            this.Cur%_type% := CurObj   ; set .Cur%_type% for most recent obj of that type
            CurObj.CurDC := DC          ; set obj.CurDC in the obj
            return DllCall("gdi32\SelectObject", "UPtr", DC.ptr, "UPtr", CurObj.ptr)
        }
        StretchBltMode[] { ; 4 = Halftone / 3 = ColorOnColor
            set => DllCall("gdi32\SetStretchBltMode", "UPtr", this.ptr, "Int", value)
            get => DllCall("gdi32\GetStretchBltMode", "UPtr", this.ptr)
        }
        
        AspectX[] {
            get => gdipp.GetDeviceCaps(this.ptr, 40)
        }
        AspectY[] {
            get => gdipp.GetDeviceCaps(this.ptr, 42)
        }
        AspectXY[] {
            get => gdipp.GetDeviceCaps(this.ptr, 44)
        }
        BltAlignment[] {
            get => gdipp.GetDeviceCaps(this.ptr, 119)
        }
        bpp[] {
            get => gdipp.GetDeviceCaps(this.ptr, 12)
        }
        ; BrushColor[] { ; seems weird, compared to CreateBrushIndirect...
            ; set => DllCall("gdi32\SetDCBrushColor", "UPtr", this.ptr, "UInt", value)
            ; get => DllCall("gdi32\GetDCBrushColor", "UPtr", this.ptr) << 32 >> 32
        ; }
        ColorRes[] {
            get => this.GetDeviceCaps(this.ptr, 108)
        }
        DpiX[] {
            get => this.GetDeviceCaps(this.ptr, 88)
        }
        DpiY[] {
            get => this.GetDeviceCaps(this.ptr, 90)
        }
        DesktopH[] {
            get => this.GetDeviceCaps(this.ptr, 117)
        }
        DesktopW[] {
            get => this.GetDeviceCaps(this.ptr, 118)
        }
        DriverVersion[] {
            get => this.GetDeviceCaps(this.ptr, 0)
        }
        mmX[] {
            get => this.GetDeviceCaps(this.ptr, 4)
        }
        mmY[] {
            get => this.GetDeviceCaps(this.ptr, 6)
        }
        NumBrushes[] {
            get => this.GetDeviceCaps(this.ptr, 16)
        }
        NumColors[] {
            get => this.GetDeviceCaps(this.ptr, 24)
        }
        NumFonts[] {
            get => this.GetDeviceCaps(this.ptr, 22)
        }
        NumMarkers[] {
            get => this.GetDeviceCaps(this.ptr, 20)
        }
        NumPens[] {
            get => this.GetDeviceCaps(this.ptr, 18)
        }
        PaletteSize[] {
            get => this.GetDeviceCaps(this.ptr, 104)
        }
        PDeviceSize[] {
            get => this.GetDeviceCaps(this.ptr, 26)
        }
        PhysicalOffsetX[] {
            get => this.GetDeviceCaps(this.ptr, 112)
        }
        PhysicalOffsetY[] {
            get => this.GetDeviceCaps(this.ptr, 113)
        }
        PhysicalW[] {
            get => this.GetDeviceCaps(this.ptr, 110)
        }
        PhysicalH[] {
            get => this.GetDeviceCaps(this.ptr, 111)
        }
        Planes[] {
            get => this.GetDeviceCaps(this.ptr, 14)
        }
        ScalingFactorX[] {
            get => this.GetDeviceCaps(this.ptr, 114)
        }
        ScalingFactorY[] {
            get => this.GetDeviceCaps(this.ptr, 115)
        }
        VRefresh[] {
            get => this.GetDeviceCaps(this.ptr, 116)
        }
        w[] {
            get => this.GetDeviceCaps(this.ptr, 8)
        }
        h[] {
            get => this.GetDeviceCaps(this.ptr, 10)
        }
        
        GetDeviceCaps(hdc, index) { ; (https://docs.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-getdevicecaps)
            return DllCall("gdi32\GetDeviceCaps", "UPtr", hDC, "int", index) ; thanks to GeekDude and mmikeww for these docs!
        }
    }
    
    ; =============================================================================================
    ; method for loading constants - so we can turn CaseSense off in Map()
    ; =============================================================================================
    Static LoadConstants() {
        ; Brush Types (0-3, 5-8) ; https://docs.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-logbrush
        bt := Map(), bt.CaseSense := false
          bt["Solid"]:=0, bt["Pattern8x8"]:=7, bt["Pattern"]:=3, bt["Hollow"]:=1, bt["Hatched"]:=2
        , bt["DibPatternPT"]:=6, bt["DibPattern8x8"]:=8, bt["DibPattern"]:=5
        this.BrushTypes := bt
        
        ; Hatch Styles (0-5) ; https://docs.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-logbrush
        ht := Map(), ht.CaseSense := false
          ht["BDiagonal"]:=3, ht["Cross"]:=4, ht["DiagCross"]:=5, ht["FDiagonal"]:=2, ht["Horizontal"]:=0, ht["Vertical"]:=1
        this.HatchTypes := ht
        
        
    }
    Static GetFlag(iInput,member) { ; reverse lookup for Map() constants
        output := ""
        For prop, value in gdipp.%member%
            If (iInput = value)
                return prop
    }
}


/**
 * Bilinear resize ARGB image.
 * pixels is an array of size w * h.
 * Target dimension is w2 * h2.
 * w2 * h2 cannot be zero.
 * 
 * @param pixels Image pixels.
 * @param w Image width.
 * @param h Image height.
 * @param w2 New width.
 * @param h2 New height.
 * @return New array with size w2 * h2.
 */
 
; public int[] resizeBilinear(int[] pixels, int w, int h, int w2, int h2) {
    ; int[] temp = new int[w2*h2] ;
    ; int a, b, c, d, x, y, index ;
    ; float x_ratio = ((float)(w-1))/w2 ;
    ; float y_ratio = ((float)(h-1))/h2 ;
    ; float x_diff, y_diff, blue, red, green ;
    ; int offset = 0 ;
    ; for (int i=0;i<h2;i++) {
        ; for (int j=0;j<w2;j++) {
            ; x = (int)(x_ratio * j) ;
            ; y = (int)(y_ratio * i) ;
            ; x_diff = (x_ratio * j) - x ;
            ; y_diff = (y_ratio * i) - y ;
            ; index = (y*w+x) ;                
            ; a = pixels[index] ;
            ; b = pixels[index+1] ;
            ; c = pixels[index+w] ;
            ; d = pixels[index+w+1] ;

            ; // blue element
            ; // Yb = Ab(1-w)(1-h) + Bb(w)(1-h) + Cb(h)(1-w) + Db(wh)
            ; blue = (a&0xff)*(1-x_diff)*(1-y_diff) + (b&0xff)*(x_diff)*(1-y_diff) +
                   ; (c&0xff)*(y_diff)*(1-x_diff)   + (d&0xff)*(x_diff*y_diff);

            ; // green element
            ; // Yg = Ag(1-w)(1-h) + Bg(w)(1-h) + Cg(h)(1-w) + Dg(wh)
            ; green = ((a>>8)&0xff)*(1-x_diff)*(1-y_diff) + ((b>>8)&0xff)*(x_diff)*(1-y_diff) +
                    ; ((c>>8)&0xff)*(y_diff)*(1-x_diff)   + ((d>>8)&0xff)*(x_diff*y_diff);

            ; // red element
            ; // Yr = Ar(1-w)(1-h) + Br(w)(1-h) + Cr(h)(1-w) + Dr(wh)
            ; red = ((a>>16)&0xff)*(1-x_diff)*(1-y_diff) + ((b>>16)&0xff)*(x_diff)*(1-y_diff) +
                  ; ((c>>16)&0xff)*(y_diff)*(1-x_diff)   + ((d>>16)&0xff)*(x_diff*y_diff);

            ; temp[offset++] = 
                    ; 0xff000000 | // hardcode alpha
                    ; ((((int)red)<<16)&0xff0000) |
                    ; ((((int)green)<<8)&0xff00) |
                    ; ((int)blue) ;
        ; }
    ; }
    ; return temp ;
; }