#Include Gdip_All.ahk


GDIPToken := Gdip_Startup()
exts := Map(), exts.caseSense := false
exts["bmp"] := "", exts["jpg"] := "", exts["png"] := ""
PicFolder := A_ScriptDir
;_______________________________________________________________________________________________________________________
Gui1 := Gui("+OwnDialogs","Pictures")
Gui1.OnEvent("close",GuiClose)
Gui1.OnEvent("escape",GuiClose)
Gui1.Add("ListBox","w600 r20 +Sort vPicList").OnEvent("change",ShowPicProps)
ctl := Gui1.Add("Button","","Select Folder")
ctl.OnEvent("click",SelectPics)
Gui1.Show()

SelectPics(ctl,"")

Return
;_______________________________________________________________________________________________________________________
Esc::GuiClose("")
GuiClose(*) {
    Global
    Gdip_Shutdown(GDIPToken)
    ExitApp
}
;_______________________________________________________________________________________________________________________
SelectPics(ctl, info) {
   Global
   
   StartingFolder := (PicFolder != "") ? ("*" PicFolder) : ""
   PicFolder := DirSelect(StartingFolder, 2, "Select the pictures' folder, please!")
   
   If (PicFolder = "")
      Return
   
   ctl.gui["PicList"].Delete()
   
   Loop Files PicFolder "\*"
      If exts.Has(A_LoopFileExt)
        ctl.gui["PicList"].Add([A_LoopFileFullPath])
}
;_______________________________________________________________________________________________________________________
ShowPicProps(ctl, info) {
   Global
   Pic := ctl.Text
   
   If (Pic = "")
      Return
      
   GDIPImage := Gdip_LoadImageFromFile(Pic)
   Properties := Gdip_GetAllPropertyItems(GDIPImage)
   
   If (Properties.Count = 0) {
      MsgBox "Error, Couldn't get properties of image: " Pic
      Return
   }
   
   Gdip_DisposeImage(GDIPImage)
   
   g := Gui("+LastFound +Owner" Gui1.hwnd " +ToolWindow")
   g.OnEvent("close",PropsClose)
   g.OnEvent("escape",PropsClose)
   
   g.MarginX := 0, g.MarginY := 0
   ctl := g.Add("ListView","Grid w600 r20",["ID","Name","Length","Type","Value"])
   For ID, Val in Properties.OwnProps() {
      If IsInteger(ID) {
         PropName := Gdip_GetPropertyTagName(ID)
         PropType := Gdip_GetPropertyTagType(Val.Type)
         If (PropType = "Byte") || (PropType = "Undefined") || (PropType = "Unknown")
            ctl.Add("", ID, PropName, Val.Length, PropType, "")
         Else
            ctl.Add("", ID, PropName, Val.Length, PropType, Val.Value)
      }
   }
   
   ctl.ModifyCol(1, "Integer")
   Loop ctl.GetCount("Column")
      ctl.ModifyCol(A_Index, "AutoHdr")
   ctl.ModifyCol(1,"Sort")
   g.Title := PIC " - " Properties.Count " properties"
   g.Show()
}
;_______________________________________________________________________________________________________________________
PropsClose(_gui) {
    _gui.Destroy()
    return
}