' dsh-pet: 在桌面创建「启动看板娘 / 关闭看板娘」两个带图标的快捷方式
Option Explicit
Dim fso, sh, pluginDir, desktop
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
If WScript.Arguments.Count < 1 Then WScript.Quit 2
pluginDir = WScript.Arguments(0)
desktop = sh.ExpandEnvironmentStrings("%DSH_PET_DESKTOP%")
If desktop = "%DSH_PET_DESKTOP%" Then desktop = sh.SpecialFolders("Desktop")
If Not fso.FolderExists(desktop) Then WScript.Quit 1
MakeOne "启动看板娘", "start-dsh.cmd", "icon-start.ico"
MakeOne "关闭看板娘", "stop-pet.cmd", "icon-stop.ico"
WScript.Echo "ok"
WScript.Quit 0

Sub MakeOne(name, script, icon)
  Dim path, s, ico
  path = fso.BuildPath(desktop, name & ".lnk")
  Set s = sh.CreateShortcut(path)
  s.TargetPath = fso.BuildPath(pluginDir, script)
  s.WorkingDirectory = pluginDir
  ico = fso.BuildPath(pluginDir, "assets\" & icon)
  If fso.FileExists(ico) Then s.IconLocation = ico & ",0"
  s.Description = name
  s.Save
End Sub
