#SingleInstance Force
#NoEnv
SetWorkingDir %A_ScriptDir%
SetBatchLines -1

ClearWukong()
EnvGet, vUserProfile, USERPROFILE
FilePath := % vUserProfile . "\AppData\Local\Warframe\EE.log"
File := FileOpen(FilePath, "r")
OldLogFileSize := 0
File.Seek(0, 2)

global squad := {}
global is_host := true
Global g_hToolBar, g_hLvItems

;Menu Tray, Icon, shell32.dll, -274
Gui Main: New, +LabelMain +hWndhMainWnd +Resize
Gui Font, s9, Segoe UI

Gui, Add, ListView, hWndg_hLvItems x0 y0 w640 h320 +LV0x14000, Alias|IP|Uid 
Gui, Add, Button, x10 y340 w200 h30 gGetSelection, Free Hongkong
Gui, Add, Button, x240 y340 w200 h30 gResetAll, Reset
Gui, Add, Checkbox, x10 y370 w130 h20 vHostMode gHostMode, Host Mode
Gui, Add, StatusBar, vMyStatusBar

DllCall("UxTheme.dll\SetWindowTheme", "Ptr", g_hLvItems, "WStr", "Explorer", "Ptr", 0)

SB_SetText("host: " is_host)
Gui Show, w640 h480, Freewukong-beta

If (!A_IsAdmin){
    MsgBox, 0, %A_ThisLabel%, Need Admin Permission!
    ClearWukong()
    ExitApp
}
Loop
{
	LogFileSize := File.Length
	if (LogFileSize >= OldLogFileSize)
	{
		Loop
		{
			if File.AtEOF
				Break
			TextLine := File.Readline()
			if (InStr(TextLine, "AddSquadMember"))
			{
				RegExMatch(TextLine, "O)AddSquadMember: (?<alias>.*), mm=(?<uid>.*), squadCount", aliasSubPat)
                squad[aliasSubPat["uid"]]:= {alias: aliasSubPat["alias"]}
                RefreshGUI()
            }
            else if (InStr(TextLine, "VOIP: Registered remote player"))
            {
                RegExMatch(TextLine, "O)VOIP: Registered remote player (?<uid>.*) \((?<ipv4>.*):(?<port>.*)\)", ipSubPat)
                squad[ipSubPat["uid"]]["ipv4"]:=ipSubPat["ipv4"]
                RefreshGUI()
            }
            else if (InStr(TextLine, "RemoveSquadMember"))
            {
                RegExMatch(TextLine, "O)RemoveSquadMember: (?<alias>.*) has been", removeSubPat)
                DeletebyAlias(removeSubPat["alias"], squad)
                RefreshGUI()
            }
            else if (InStr(TextLine, "RemovePlayerFromSession"))
            {
                RegExMatch(TextLine, "O)RemovePlayerFromSession:\(mm=(?<alias>.*)\)", removeSubPat)
                DeletebyAlias(removeSubPat["alias"], squad)
                RefreshGUI()
            }
            else if (InStr(TextLine, "(host: 0)"))
            {
                is_host := false
                SB_SetText("host: " is_host)
                RefreshGUI()
            }
            else if (InStr(TextLine, "(host: 1)"))
            {
                is_host := true
                SB_SetText("host: " is_host)
                RefreshGUI()
            }
            else if (InStr(TextLine, "MatchingService::EndSession"))
            {
                ClearWukong()
                RefreshGUI()
            }
            else if (InStr(TextLine, "Deleted session"))
            {
                ClearWukong()
                RefreshGUI()
            }
            else if (InStr(TextLine, "OnSquadCountdown: 1"))
            {
                GuiControl, , HostMode, 0
                ClearWukong()
                RefreshGUI()
            }
                    
        }
		OldLogFileSize := LogFileSize
	}
    Sleep, 1000 ; wait one second before checking again (change to whatever)
}
Return ; End of the auto-execute section.

MenuHandler:
Return

MainEscape:
MainClose:
    ClearWukong()
    ExitApp
Return

MainSize(GuiHwnd, EventInfo, Width, Height) {
    If (A_EventInfo == 1) { ; The window has been minimized.
        Return
    }

    AutoXYWH("wh", g_hLvItems)
    GuiControl Move, %g_hToolBar%, w%A_GuiWidth%
}

MainContextMenu(GuiHwnd, CtrlHwnd, EventInfo, IsRightClick, X, Y) {

}

AutoXYWH(DimSize, cList*) {
    Local
    Static cInfo := {}
 
    If (DimSize = "reset") {
        Return cInfo := {}
    }
 
    For i, ctrl in cList {
        ctrlID := A_Gui ":" ctrl
        If (cInfo[ctrlID].x = "") {
            GuiControlGet i, %A_Gui%: Pos, %ctrl%
            MMD := InStr(DimSize, "*") ? "MoveDraw" : "Move"
            fx := fy := fw := fh := 0
            For i, dim in (a := StrSplit(RegExReplace(DimSize, "i)[^xywh]"))) {
                If (!RegExMatch(DimSize, "i)" . dim . "\s*\K[\d.-]+", f%dim%)) {
                    f%dim% := 1
                }
            }
            cInfo[ctrlID] := {x: ix, fx: fx, y: iy, fy: fy, w: iw, fw: fw, h: ih, fh: fh, gw: A_GuiWidth, gh: A_GuiHeight, a: a, m: MMD}
        } Else If (cInfo[ctrlID].a.1) {
            dgx := dgw := A_GuiWidth - cInfo[ctrlID].gw, dgy := dgh := A_GuiHeight - cInfo[ctrlID].gh
            Options := ""
            For i, dim in cInfo[ctrlID]["a"] {
                Options .= dim . (dg%dim% * cInfo[ctrlID]["f" . dim] + cInfo[ctrlID][dim]) . A_Space
            }
            GuiControl, % A_Gui ":" cInfo[ctrlID].m, % ctrl, % Options
        }
    }
}

DeletebyAlias(x, arr){
    for uid,info in squad{
        if (info["alias"] == x){
            _ := arr.Delete(uid)
            Break  
        }
    }
}

DeletebyUID(x, arr){
    for uid,info in squad{
        if (uid == x){
            _ := arr.Delete(uid)
            Break  
        }
    }
}

RefreshGUI(){
    LV_Delete()
    GuiControl, -Redraw, MyListView
    
    For uid,info in squad{
        LV_Add("", info["alias"],info["ipv4"] ,uid)
    }
    LV_ModifyCol(, "AutoHdr")
    LV_ModifyCol(1,"Sort")
	
    GuiControl, +Redraw, MyListView ; Re-enable redrawing (it was disabled above).
}

DropbyUID(alias, uid){
    If (!is_host) {
       MsgBox, 0, %A_ThisLabel%, You're not a Host
       Return
    }
    ip := squad[uid]["ipv4"]
    Run powershell /c "netsh advfirewall firewall add rule name='freewukong-%uid%-in' dir=in action=block enable=yes remoteip=%ip% profile=any",, HIDE
    Run powershell /c "netsh advfirewall firewall add rule name='freewukong-%uid%-out' dir=out action=block enable=yes remoteip=%ip% profile=any",, HIDE    DeletebyUID(uid, squad)
    MsgBox, Member %alias% dropped
    RefreshGUI()
}

ClearWukong(){
    Run powershell /c "Remove-NetFirewallRule -DisplayName 'freewukong*'",, HIDE
}

ClearSquad(){
    squad := {}
}

GetSelection:
    If !(SelectedRow := LV_GetNext()) {
       MsgBox, 0, %A_ThisLabel%, Select a row in the list-view, please!
       Return
    }
    LV_GetText(target_alias, SelectedRow, 1)
    LV_GetText(target_uid, SelectedRow, 3)
    DropbyUID(target_alias, target_uid)
Return

HostMode:
    Gui, Submit, NoHide
    if (HostMode){
        Run powershell /c "netsh advfirewall firewall add rule name="freewukong-host" dir=out action=block enable=yes localport=4950`,4955`,4960`,4965`,4970`,4975`,4980`,4985`,4990`,4995`,3074`,3080 protocol=udp profile=any",, HIDE
    }
    else{
        ClearWukong()
    }
return

ResetAll:
    ClearSquad()
    ClearWukong()
    RefreshGUI()
    
return