Class SAP
    Private SERVER_DICTIONARY

    ' INITIALIZE -------------------------------------------------------------------
    Private Sub Class_Initialize
        Set SERVER_DICTIONARY = CreateObject("Scripting.Dictionary")
        SERVER_DICTIONARY("PRODUCTION DEI SAP TAIWAN") = "twtpe(erp?|its)ap*"
        SERVER_DICTIONARY("PRODUCTION BW4") = "twtpebw4ap"
        SERVER_DICTIONARY("QAS_DEI") = "twtpeerpqaf"
        SERVER_DICTIONARY("QAS_BW4") = "twtpebw4qag"
        SERVER_DICTIONARY("QAJ") = "twtpeerpqaj"
        SERVER_DICTIONARY("QA2 BW4 (Month end closing)") = "twtpebw4qag2"
    End Sub

    Private Property Get SAPServerIDDictionary(ID)
        SAPServerIDDictionary = SERVER_DICTIONARY(ID)
    End Property

    ' MAIN FUNCTION ----------------------------------------------------------------
    Public Function main(SAPFunction, SAPGUIPath, SAPServer, SAPClient)

        Dim WinTitle
        Dim application
        main = False

        ' Set the title of the SAP Logon Pad
        WinTitle = "SAP Logon Pad 740"

        ' Start SAP application
        If SAPFunction <> "CloseAll" Then
            Set application = startSAPApp(SAPGUIPath, WinTitle)
        End If

        ' Switch between functions
        Select Case SAPFunction

            ' Log in SAP
            Case "LogIn"

                ' Establish SAP Connection
                If Not application Is Nothing Then
                    main = establishSAPSession(application, SAPServer, SAPClient, True)
                Else
                    main = False
                    Exit Function
                End If
            
            ' Log in SAP but keep other connections
            Case "LogInKeep"

                ' Establish SAP Connection but keep other connections
                If Not application Is Nothing Then
                    main = establishSAPSession(application, SAPServer, SAPClient, False)
                Else
                    main = False
                    Exit Function
                End If

            ' Close connections by server and client
            Case "Close"

                ' Terminate SAP session by server and client
                If Not application Is Nothing Then
                    main = closeSAPSession(application, SAPServer, SAPClient)
                Else
                    main = False
                    Exit Function
                End If

            ' Close all SAP related
            Case "CloseAll"

                Dim SAPAppName, SAPPathSplit

                SAPPathSplit = Split(SAPGUIPath, "\")
                SAPAppName = SAPPathSplit(UBound(SAPPathSplit))

                ' Close all SAP connections and the application
                main = closeAllSAPSessions(".", SAPAppName)

            ' Exceptional cases
            Case Else
        End Select

        'Reset
        Set application = Nothing
    End Function

    ' INITIATE SAP APPLICATION ----------------------------------------------------
    Public Function startSAPApp(SAPGUIPath, WinTitle)

        Dim SAPGuiAuto, application
        Dim WSHShell

        ' Start logon pad
        Set WSHShell = WScript.CreateObject("WScript.Shell")

        If IsObject(WSHShell) Then

            ' Starts the SAP Logon Pad
            WSHShell.Exec SAPGUIPath

            ' Wait until application loads
            While Not WSHShell.AppActivate(WinTitle)
                WScript.Sleep 250
            Wend

            ' Reset 
            Set WSHShell = Nothing
        End If

        ' Set connection objects
        If Not IsObject(application) Then
            Set SAPGuiAuto  = GetObject("SAPGUI")
            Set application = SAPGuiAuto.GetScriptingEngine
        End If

        ' Return application
        Set startSAPApp = application
    End Function

    ' ESTABLISH REQUIRED SAP SESSION -----------------------------------------------
    Private Function establishSAPSession(application, SAPServer, SAPClient, disconnectOther)

        Dim serverID, resultConnection, closeStatus
        establishSAPSession = False

        ' Get SAP server ID
        serverID = SAPServerIDDictionary(SAPServer)

        ' Check existing connections
        Set resultConnection = checkExistingSAPSession(application, serverID, SAPClient)

        ' Establish required connection
        If resultConnection Is Nothing Then
            connectSAPServer application, SAPServer, SAPClient
        Else
            resetExistingSAPConnection resultConnection
        End If
        
        ' Disconnect other connections
        If disconnectOther Then
            closeStatus = closeSAPSessionKeep(application, SAPServer, SAPClient)
            If Not closeStatus Then
                establishSAPSession = False
                Exit Function
            End If
        End If
        
        ' Reset
        Set resultConnection = Nothing

        ' Return success
        establishSAPSession = True
    End Function

    ' CHECK ALL EXISTING SESSIONS --------------------------------------------------
    Private Function checkExistingSAPSession(application, serverID, SAPClient)

        Dim session
        Dim serverChecker: Set serverChecker = New RegExp
        serverChecker.Pattern = serverID

        ' Check if there is existing SAP connection
        For Each existingConnection In application.Children
            Set session = existingConnection.Children(0)

            ' If found existing connection with same server and client
            If serverChecker.Test(session.Info.ApplicationServer) And session.Info.Client = SAPClient Then
                Set checkExistingSAPSession = existingConnection
                Exit Function
            End If
        Next

        ' No existing connection
        Set checkExistingSAPSession = Nothing

        ' Reset
        Set session = Nothing
    End Function

    ' RESET EXISTING SAP CONNECTION ------------------------------------------------
    Private Sub resetExistingSAPConnection(connection)

        Dim startPageExist, sessionNameAll
        startPageExists = False
        sessionName = ""

        ' Reset all sessions in the connection
        For Each existingSession In connection.Children
            If Not startPageExists Then
                If InStr(existingSession.ActiveWindow.Text, "SAP Easy Access") = 0 Then
                    existingSession.EndTransaction
                End If
                startPageExists = True
            Else
                sessionNameAll = sessionNameAll & "ses[" & (existingSession.Info.SessionNumber - 1) & "],"
            End If
        Next

        For Each sessionName In Split(sessionNameAll, ",")
            If sessionName <> "" Then
                connection.CloseSession(sessionName)
            End If
        Next
    End Sub

    ' CONNECT TO SAP SERVER --------------------------------------------------------
    Private Sub connectSAPServer(application, SAPServer, SAPClient)

        Dim connection, session

        If Not IsObject(connection) Then
            Set connection = application.openConnection(SAPServer)
        End If

        ' Set session
        Set session = connection.Children(0)

        ' Check if there's a pop-up
        If session.ActiveWindow.Text = "Information" Then
            session.findById("wnd[0]").sendVKey 0
        End If

        ' Connect to client
        If Not session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,0]", False) Is Nothing Then
            firstClientID = session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,0]", False).Text
            Select Case firstClientID

                ' Client menu version 1
                Case "021"
                    If SAPClient = "021" And Not session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,0]", False) Is Nothing Then
                        session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,0]").setFocus
                        session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,0]").press  
                    ElseIf SAPClient = "025" And Not session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,1]", False) Is Nothing Then
                        session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,1]").setFocus
                        session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,1]").press
                    ElseIf SAPClient = "125" And Not session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,2]", False) Is Nothing Then
                        session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,2]").setFocus
                        session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,2]").press
                    ElseIf SAPClient = "225" And Not session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,3]", False) Is Nothing Then
                        session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,3]").setFocus
                        session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,3]").press
                    Else
                    End If

                ' Client menu version 2
                Case "025"
                    If SAPClient = "025" And Not session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,0]", False) Is Nothing Then
                        session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,0]").setFocus
                        session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,0]").press
                    ElseIf SAPClient = "125" And Not session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,1]", False) Is Nothing Then
                        session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,1]").setFocus
                        session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,1]").press
                    ElseIf SAPClient = "225" And Not session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,2]", False) Is Nothing Then
                        session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,2]").setFocus
                        session.findById("wnd[0]/usr/tblSAPMSYSTTC_IUSRACL/btnIUSRACL-MANDT[0,2]").press
                    Else
                    End If
            End Select
        End If

        ' Reset
        Set connection = Nothing
        Set session = Nothing
    End Sub

    ' CLOSE SAP CONNECTION BY SERVER & CLIENT --------------------------------------
    Private Function closeSAPSession(application, SAPServer, SAPClient)

        Dim session
        Dim serverID
        Dim serverChecker
        closeSAPSession = False

        ' Get SAP server ID
        serverID = SAPServerIDDictionary(SAPServer)

        ' Set comparator
        Set serverChecker = New RegExp
        serverChecker.Pattern = serverID

        ' Find matching SAP connection
        For Each existingConnection In application.Children
            Set session = existingConnection.Children(0)

            ' If found existing connection with same server and client
            If serverChecker.Test(session.Info.ApplicationServer) And session.Info.Client = SAPClient Then
                existingConnection.CloseConnection
                Exit For
            End If
        Next

        ' Reset
        Set session = Nothing

        ' Return success
        closeSAPSession = True
    End Function

    ' CLOSE SAP CONNECTIONS BUT KEET CERTAIN SERVER & CLIENT -------------------------
    Private Function closeSAPSessionKeep(application, keepSAPServer, keepSAPClient)

        Dim session
        Dim serverID
        Dim serverChecker
        closeSAPSessionKeep = False

        ' Get SAP server ID
        serverID = SAPServerIDDictionary(keepSAPServer)

        ' Set comparator
        Set serverChecker = New RegExp
        serverChecker.Pattern = serverID

        ' Find matching SAP connection
        For Each existingConnection In application.Children
            Set session = existingConnection.Children(0)
            ' If found existing connection with different server and client
            If Not serverChecker.Test(session.Info.ApplicationServer) Or session.Info.Client <> keepSAPClient Then
                existingConnection.CloseConnection
            End If
        Next

        ' Reset
        Set session = Nothing

        ' Return success
        closeSAPSessionKeep = True
    End Function

    ' CLOSE ALL SAP INSTANCES ------------------------------------------------------
    Private Function closeAllSAPSessions(computerName, SAPAppName)

        Dim process, strObject
        closeAllSAPSessions = False
        strObject = "winmgmts://" & computerName

        ' Search each running process
        For Each process in GetObject(strObject).InstancesOf("win32_process")
            If InStr(process.Name, SAPAppName) Then
                process.Terminate
            End If
        Next

        ' Return success
        closeAllSAPSessions = True
    End Function
End Class