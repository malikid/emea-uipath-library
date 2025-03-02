' Arguments

' SAP Function:
'   1. LogIn: Logs into the server & client specified, and close all other connections
'   2. LogInKeep: Logs into the server & client specified, but keep other connections
'   3. Close: close all connections, but leaves the logon pad open
'   4. CloseAll: close all connections and logon pad

' Change settings below ------------------------------------------------------------------

Arg_SAPFunction = WScript.Arguments(0)
Arg_SAPGUIPath = WScript.Arguments(1)
Arg_SAPServer = WScript.Arguments(2)
Arg_SAPClient = WScript.Arguments(3)

' Change settings above ------------------------------------------------------------------



' DO NOT MODIFY --------------------------------------------------------------------------

' Globals
Dim gsLibDir : gsLibDir = ".\"
Dim goFS     : Set goFS = CreateObject("Scripting.FileSystemObject")

' LibraryInclude
ExecuteGlobal goFS.OpenTextFile(goFS.BuildPath(gsLibDir, "SAP Class.vbs")).ReadAll()

' Set SAP handler
Dim SAPHandler, SAPStatus: SAPStatus = False
Set SAPHandler = New SAP

Arg_SAPGUIPath = Replace(Arg_SAPGUIPath, "!", " ")
Arg_SAPServer = Replace(Arg_SAPServer, "!", " ")
Arg_SAPClient = Replace(Arg_SAPClient, "!", " ")

' Start main
SAPStatus = SAPHandler.main(Arg_SAPFunction, Arg_SAPGUIPath, Arg_SAPServer, Arg_SAPClient)

Set SAPHandler = Nothing
WScript.Echo CStr(SAPStatus)
WScript.Quit
' -----------------------------------------------------------------------------------------