' dsh-pet: 从 cordis.patch.yml 中移除 dsh-pet 的 insert 条目，其余插件配置原样保留
Option Explicit
Dim fso, f, patch, lines, i, outText, removed, inBlock, ln, trimmed
Set fso = CreateObject("Scripting.FileSystemObject")
If WScript.Arguments.Count < 1 Then WScript.Quit 2
patch = WScript.Arguments(0)
If Not fso.FileExists(patch) Then
  WScript.Echo "nopatch"
  WScript.Quit 0
End If
' 字节级检查：文件不是纯 ASCII 就不动它（避免把 UTF-8 内容写成 GBK 弄坏配置）
Dim st2, raw2, nb2, bi2, nonAscii2
nonAscii2 = 0
On Error Resume Next
Set st2 = CreateObject("ADODB.Stream")
If Err.Number = 0 Then
  st2.Type = 1
  st2.Open
  st2.LoadFromFile patch
  raw2 = st2.Read
  st2.Close
  nb2 = LenB(raw2)
  For bi2 = 1 To nb2
    If AscB(MidB(raw2, bi2, 1)) > 127 Then nonAscii2 = nonAscii2 + 1
  Next
End If
On Error GoTo 0
If nonAscii2 > 0 Then
  WScript.Echo "nonascii"
  WScript.Quit 0
End If
fso.CopyFile patch, patch & ".bak", True

Set f = fso.OpenTextFile(patch, 1, False)
lines = Split(Replace(f.ReadAll, vbLf, ""), vbCr)
f.Close

outText = ""
removed = 0
inBlock = False
For i = 0 To UBound(lines)
  ln = lines(i)
  trimmed = Trim(ln)
  If inBlock Then
    If Len(trimmed) = 0 Then
      inBlock = False
      outText = outText & ln & vbCrLf
    ElseIf Left(trimmed, 1) = "-" Then
      inBlock = False
      outText = outText & ln & vbCrLf
    Else
      removed = removed + 1
    End If
  Else
    If InStr(ln, "id: dsh-pet") > 0 Then
      outText = DropLastInsert(outText)
      removed = removed + 1
      inBlock = True
    ElseIf InStr(ln, "# dsh-pet") > 0 Then
      removed = removed + 1
    Else
      If i = 0 And InStr(ln, "#") = 0 And InStr(ln, "-") = 0 Then
        removed = removed + 1
      Else
        outText = outText & ln & vbCrLf
      End If
    End If
  End If
Next


Do While InStr(outText, vbCrLf & vbCrLf & vbCrLf) > 0
  outText = Replace(outText, vbCrLf & vbCrLf & vbCrLf, vbCrLf & vbCrLf)
Loop

Set f = fso.CreateTextFile(patch, True, False)
f.Write outText
f.Close
WScript.Echo "ok:" & removed

Function DropLastInsert(s)
  Dim t, pos, lastLine
  t = s
  Do While Len(t) >= 2 And Right(t, 2) = vbCrLf
    t = Left(t, Len(t) - 2)
  Loop
  pos = InStrRev(t, vbCrLf)
  If pos > 0 Then
    lastLine = Mid(t, pos + 2)
  Else
    lastLine = t
  End If
  If InStr(lastLine, "insert:") > 0 Then
    If pos > 0 Then t = Left(t, pos - 1)
    DropLastInsert = t & vbCrLf
  Else
    DropLastInsert = s
  End If
End Function
