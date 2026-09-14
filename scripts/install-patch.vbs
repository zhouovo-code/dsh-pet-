' dsh-pet: write the dsh-pet entry into cordis.patch.yml
'   * file missing / comments only / "[]" placeholder -> write a clean entry
'   * other plugin entries present                     -> append, newline separated
'   * entry already present                            -> do nothing
'   * file contains non-ASCII bytes (UTF-8 comments)   -> refuse, let the user edit
' ASCII only on purpose: the DSH YAML parser reads UTF-8, so writing GBK text
' here would corrupt the profile.
Option Explicit
Dim fso, f, patch, hostUrl, existing, lines, i, ln, t, kept, hasEntry, block, result, nonAscii, k, ch
Set fso = CreateObject("Scripting.FileSystemObject")
If WScript.Arguments.Count < 2 Then WScript.Quit 2
patch = WScript.Arguments(0)
hostUrl = WScript.Arguments(1)

' ---- byte level check: never touch a file that is not pure ASCII ----
nonAscii = 0
If fso.FileExists(patch) Then
  Dim st, raw, nb, bi
  On Error Resume Next
  Set st = CreateObject("ADODB.Stream")
  If Err.Number = 0 Then
    st.Type = 1
    st.Open
    st.LoadFromFile patch
    raw = st.Read
    st.Close
    nb = LenB(raw)
    For bi = 1 To nb
      If AscB(MidB(raw, bi, 1)) > 127 Then nonAscii = nonAscii + 1
    Next
  End If
  On Error GoTo 0
End If
If nonAscii > 0 Then
  WScript.Echo "nonascii"
  WScript.Quit 0
End If

existing = ""
If fso.FileExists(patch) Then
  Set f = fso.OpenTextFile(patch, 1, False)
  If Not f.AtEndOfStream Then existing = f.ReadAll
  f.Close
End If

If InStr(existing, "id: dsh-pet") > 0 Then
  WScript.Echo "exists"
  WScript.Quit 0
End If

kept = ""
lines = Split(Replace(existing, vbLf, ""), vbCr)
For i = 0 To UBound(lines)
  ln = lines(i)
  t = Trim(ln)
  If t = "[]" Or t = "---" Then
    ' drop the empty-array placeholder
  ElseIf i = 0 And Len(t) > 0 And Left(t, 1) <> "#" And Left(t, 1) <> "-" Then
    ' drop a damaged first line
  Else
    kept = kept & ln & vbCrLf
  End If
Next

hasEntry = False
lines = Split(Replace(kept, vbLf, ""), vbCr)
For i = 0 To UBound(lines)
  t = Trim(lines(i))
  If Len(t) > 0 And Left(t, 1) <> "#" Then hasEntry = True
Next

block = "# dsh-pet: pet widget (added by the installer)" & vbCrLf & _
        "- insert:" & vbCrLf & _
        "    - id: dsh-pet" & vbCrLf & _
        "      name: '" & hostUrl & "'" & vbCrLf

If hasEntry Then
  result = kept
  Do While Len(result) >= 2
    If Right(result, 2) = vbCrLf Then result = Left(result, Len(result) - 2) Else Exit Do
  Loop
  result = result & vbCrLf & vbCrLf & block
Else
  result = kept & block
End If

If fso.FileExists(patch) Then
  On Error Resume Next
  fso.CopyFile patch, patch & ".bak", True
  On Error GoTo 0
End If

Set f = fso.CreateTextFile(patch, True, False)
f.Write result
f.Close
WScript.Echo "added"
