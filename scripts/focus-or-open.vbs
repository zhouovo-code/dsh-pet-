' dsh-pet: 尽量切到已经打开的 DSH 页面，避免重复开标签
Option Explicit
Dim url, title, sh, ok
If WScript.Arguments.Count < 2 Then WScript.Quit 2
url = WScript.Arguments(0)
title = WScript.Arguments(1)
Set sh = CreateObject("WScript.Shell")
On Error Resume Next
ok = sh.AppActivate(title)
On Error GoTo 0
If ok Then
  WScript.Echo "focused"
  WScript.Quit 0
End If
WScript.Echo "no-window"
WScript.Quit 1