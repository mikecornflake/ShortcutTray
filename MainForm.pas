Unit MainForm;

{$mode objfpc}{$H+}
{$WARN 5024 off : Parameter "$1" not used}
{-------------------------------------------------------------------------------
  Application      : ShortcutTray
  Description
    The second version of my own start menu.
    First was written in AutohotKey.  Powerful, but not easily portable.

  Source
    Copyright (c) 2026
    Inspector Mike 2.0 Pty Ltd
    Mike Thompson (mike.cornflake@gmail.com)

  History
    01/07/2026: Creattion

  License
    This library is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or (at
    your option) any later version.

    This library is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
    General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this library. If not, see <https://www.gnu.org/licenses/>.

    SPDX-License-Identifier: GPL-3.0-or-later
-------------------------------------------------------------------------------}
Interface

Uses
  Classes, Contnrs, SysUtils, Forms, Controls, Menus, ExtCtrls, Dialogs,
  LazFileUtils;

Type

  TShortcutInfo = Class
  Public
    Caption: String;
    MenuName: String;
    ExeName: String;
    Params: String;
    WorkDir: String;
  End;

  { TfrmShortcutTray }

  TfrmShortcutTray = Class(TForm)
    ilShortcuts: TImageList;
    pmShortcuts: TPopupMenu;
    TrayIcon: TTrayIcon;
    Procedure TrayIconClick(Sender: TObject);

    Procedure FormCreate(Sender: TObject);
    Procedure FormDestroy(Sender: TObject);
  Private
    FTokens: TStringList;
    FShortcutsFile: String;
    FShortcutInfos: TFPObjectList;
    Procedure AddSeparatorToMenu(Const AMenu: String);
    Function ExpandShortcutTokens(Const AText: String): String;
    Function ExtractExeAndParams(Const ALine: String; out AExe, AParams: String): Boolean;
    Function FindOrCreateFolderMenu(Const AFolder: String): TMenuItem;
    Function FolderNameForShortcut(Const AExe: String): String;
    Procedure AddShortcutToMenu(Const AMenu, ACaption, AExe, AParams: String);
    Procedure LoadShortcuts;
    Procedure RebuildMenu;
    Procedure RunShortcut(Sender: TObject);
    Procedure OpenShortcutsFile(Sender: TObject);
    Procedure DoAbout(Sender: TObject);
    Procedure ReloadShortcuts(Sender: TObject);
    Procedure ExitApp(Sender: TObject);
    Procedure SetTrayIcon(AImageIndex: Integer);
  Public
  End;

Var
  frmShortcutTray: TfrmShortcutTray;

Const
  ICON_TRAY_ENABLED = 11;
  ICON_TRAY_DISABLED = 12;

Implementation

{$R *.lfm}

Uses
  StrUtils, OSSupport, FileSupport, StringSupport, FormAbout, Graphics;

  { TfrmShortcutTray }

Procedure TfrmShortcutTray.FormCreate(Sender: TObject);
Begin
  FShortcutInfos := TFPObjectList.Create(True);
  FShortcutsFile := AppendPathDelim(ExtractFilePath(Application.ExeName)) + 'shortcuts.txt';

  TrayIcon.Hint := 'Shortcut Tray';
  TrayIcon.Visible := True;

  FTokens := TStringList.Create;
  FTokens.CaseSensitive := False;
  FTokens.NameValueSeparator := '=';

  RebuildMenu;
End;

Procedure TfrmShortcutTray.FormDestroy(Sender: TObject);
Begin
  FreeAndNil(FTokens);
  FreeAndNil(FShortcutInfos);
End;

Procedure TfrmShortcutTray.TrayIconClick(Sender: TObject);
Begin
  RebuildMenu;
  pmShortcuts.PopUp;
End;

Procedure TfrmShortcutTray.SetTrayIcon(AImageIndex: Integer);
Var
  LIcon: TIcon;
Begin
  LIcon := TIcon.Create;
  Try
    ilShortcuts.GetIcon(AImageIndex, LIcon);
    TrayIcon.Icon.Assign(LIcon);
  Finally
    LIcon.Free;
  End;
End;

Function TfrmShortcutTray.ExpandShortcutTokens(Const AText: String): String;
Var
  i: Integer;
  TokenName, TokenValue: String;
Begin
  Result := AText;

  // This only expands user-defined [Tokens].

  For i := 0 To FTokens.Count - 1 Do
  Begin
    TokenName := Trim(FTokens.Names[i]);
    TokenValue := Trim(FTokens.ValueFromIndex[i]);

    If TokenName <> '' Then
      Result := StringReplace(Result, '<' + TokenName + '>', TokenValue,
        [rfReplaceAll, rfIgnoreCase]);
  End;
End;

Function TfrmShortcutTray.ExtractExeAndParams(Const ALine: String;
  out AExe, AParams: String): Boolean;
Var
  s: String;
  p: SizeInt;
Begin
  Result := False;
  AExe := '';
  AParams := '';

  s := Trim(ALine);
  If s = '' Then
    Exit;

  // Allow comments in shortcuts.text.
  If (s[1] = '#') Or (s[1] = ';') Then
    Exit;

  If s[1] = '"' Then
  Begin
    p := PosEx('"', s, 2);
    If p = 0 Then
      Exit;

    AExe := Copy(s, 2, p - 2);
    AParams := Trim(Copy(s, p + 1, MaxInt));
  End
  Else
  Begin
    // Fallback for unquoted paths with no spaces.
    p := Pos(' ', s);
    If p = 0 Then
      AExe := s
    Else
    Begin
      AExe := Copy(s, 1, p - 1);
      AParams := Trim(Copy(s, p + 1, MaxInt));
    End;
  End;

  Result := AExe <> '';
End;

Function TfrmShortcutTray.FolderNameForShortcut(Const AExe: String): String;
Var
  PathPart: String;
  Parts: TStringList;
Begin
  Result := 'Other';

  PathPart := ExtractFilePath(AExe);
  PathPart := StringReplace(PathPart, '/', '\', [rfReplaceAll]);
  PathPart := StringReplace(PathPart, ExtractFileDrive(PathPart), '', []);
  PathPart := TrimSet(PathPart, ['\']);

  If PathPart = '' Then
    Exit;

  Parts := TStringList.Create;
  Try
    Parts.Delimiter := '\';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := PathPart;

    If Parts.Count = 1 Then
      Result := Parts[0]
    Else If Parts.Count > 1 Then
      Result := Parts[0] + '\' + Parts[1];
  Finally
    Parts.Free;
  End;
End;

Function TfrmShortcutTray.FindOrCreateFolderMenu(Const AFolder: String): TMenuItem;
Var
  i: Integer;
Begin
  For i := 0 To pmShortcuts.Items.Count - 1 Do
    If SameText(pmShortcuts.Items[i].Caption, AFolder) Then
      Exit(pmShortcuts.Items[i]);

  Result := TMenuItem.Create(pmShortcuts);
  Result.Caption := AFolder;
  Result.ImageIndex := 1;
  pmShortcuts.Items.Add(Result);
End;

Procedure TfrmShortcutTray.AddSeparatorToMenu(Const AMenu: String);
Var
  FolderMenu, Item: TMenuItem;
Begin
  If Trim(AMenu) = '' Then
    Exit;

  FolderMenu := FindOrCreateFolderMenu(AMenu);

  Item := TMenuItem.Create(pmShortcuts);
  Item.Caption := '-';
  FolderMenu.Add(Item);
End;

Procedure TfrmShortcutTray.AddShortcutToMenu(Const AMenu, ACaption, AExe, AParams: String);
Var
  Info: TShortcutInfo;
  FolderMenu, Item: TMenuItem;
  bFile, bFolder: Boolean;
  icoTemp: TIcon;
Begin
  bFile := FileExists(AExe);
  bFolder := DirectoryExists(AExe);

  If Not bFile And Not bFolder Then
    Exit;

  Info := TShortcutInfo.Create;
  Info.MenuName := AMenu;
  Info.ExeName := AExe;
  Info.Params := AParams;
  Info.WorkDir := ExtractFilePath(AExe);

  If Trim(ACaption) <> '' Then
    Info.Caption := Trim(ACaption)
  Else
    Info.Caption := ExtractFileNameOnly(AExe);

  FShortcutInfos.Add(Info);

  If Trim(AMenu) <> '' Then
    FolderMenu := FindOrCreateFolderMenu(AMenu)
  Else
    FolderMenu := FindOrCreateFolderMenu('Other');

  Item := TMenuItem.Create(pmShortcuts);
  If Trim(ACaption) <> '' Then
    Item.Caption := Trim(ACaption)
  Else
    Item.Caption := ExtractFileNameOnly(AExe);
  Item.Hint := AExe + ' ' + AParams;
  Item.Tag := PtrInt(Info);
  Item.OnClick := @RunShortcut;

  icoTemp := GetShellSmallIcon(AExe);
  Try
    If Assigned(icoTemp) Then
      Item.ImageIndex := ilShortcuts.AddIcon(icoTemp);
  Finally
    icoTemp.Free;
  End;

  FolderMenu.Add(Item);
End;

Procedure TfrmShortcutTray.LoadShortcuts;
Var
  sl: TStringList;
  i, p: Integer;
  Line, SectionName, CaptionText, CommandText: String;
  ExeName, Params: String;
Begin
  FShortcutInfos.Clear;
  FTokens.Clear;

  If Not FileExistsUTF8(FShortcutsFile) Then
    Exit;

  sl := TStringList.Create;
  Try
    sl.LoadFromFile(FShortcutsFile);

    SectionName := 'Shortcuts';

    For i := 0 To sl.Count - 1 Do
    Begin
      Line := ExpandFile(Trim(sl[i]));

      If Line = '' Then
        Continue;

      If (Line[1] = '#') Or (Line[1] = ';') Then
        Continue;

      If (Line[1] = '[') And (Line[Length(Line)] = ']') Then
      Begin
        SectionName := Trim(Copy(Line, 2, Length(Line) - 2));
        Continue;
      End;

      If SameText(SectionName, 'Tokens') Then
      Begin
        p := Pos('=', Line);
        If p > 0 Then
          FTokens.Values[Trim(Copy(Line, 1, p - 1))] :=
            Trim(Copy(Line, p + 1, MaxInt));
        Continue;
      End;

      If Line = '-' Then
      Begin
        AddSeparatorToMenu(SectionName);
        Continue;
      End;

      p := Pos('=', Line);

      If p > 0 Then
      Begin
        CaptionText := Trim(Copy(Line, 1, p - 1));
        CommandText := Trim(Copy(Line, p + 1, MaxInt));
      End
      Else
      Begin
        CaptionText := '';
        CommandText := Line;
      End;

      CommandText := ExpandShortcutTokens(CommandText);

      If ExtractExeAndParams(CommandText, ExeName, Params) Then
        AddShortcutToMenu(SectionName, CaptionText, ExeName, Params);
    End;

  Finally
    sl.Free;
  End;
End;

Procedure TfrmShortcutTray.RebuildMenu;
Var
  Item: TMenuItem;
Begin
  SetTrayIcon(ICON_TRAY_DISABLED);
  Try
    pmShortcuts.Items.Clear;
    LoadShortcuts;

    If FShortcutInfos.Count = 0 Then
    Begin
      Item := TMenuItem.Create(pmShortcuts);
      Item.Caption := 'No shortcuts found';
      Item.Enabled := False;
      pmShortcuts.Items.Add(Item);
    End;

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := '-';
    pmShortcuts.Items.Add(Item);

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := 'About';
    Item.OnClick := @DoAbout;
    Item.ImageIndex := 11;
    pmShortcuts.Items.Add(Item);

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := '-';
    pmShortcuts.Items.Add(Item);

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := 'Reload shortcuts';
    Item.OnClick := @ReloadShortcuts;
    Item.ImageIndex := 9;
    pmShortcuts.Items.Add(Item);

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := 'Open shortcuts.txt';
    Item.OnClick := @OpenShortcutsFile;
    Item.Enabled := FileExistsUTF8(FShortcutsFile);
    Item.ImageIndex := 3;
    pmShortcuts.Items.Add(Item);

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := '-';
    pmShortcuts.Items.Add(Item);

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := 'Exit';
    Item.OnClick := @ExitApp;
    Item.ImageIndex := 10;
    pmShortcuts.Items.Add(Item);
  Finally
    SetTrayIcon(ICON_TRAY_ENABLED);
  End;
End;

Procedure TfrmShortcutTray.RunShortcut(Sender: TObject);
Var
  Info: TShortcutInfo;
Begin
  If Not (Sender Is TMenuItem) Then
    Exit;

  Info := TShortcutInfo(TMenuItem(Sender).Tag);
  If Not Assigned(Info) Then
    Exit;

  If DirectoryExists(Info.ExeName) Then
    LaunchDocument(Info.ExeName)
  Else If SameText(ExtractFileExt(Info.ExeName), '.exe') Then
    LaunchExternalTool(Info.ExeName, Info.Params)
  Else
    LaunchDocument(Info.ExeName);
End;

Procedure TfrmShortcutTray.OpenShortcutsFile(Sender: TObject);
Begin
  LaunchDocument(FShortcutsFile);
End;

Procedure TfrmShortcutTray.DoAbout(Sender: TObject);
Begin
  FormAbout.ShowAbout;
End;

Procedure TfrmShortcutTray.ReloadShortcuts(Sender: TObject);
Begin
  RebuildMenu;
End;

Procedure TfrmShortcutTray.ExitApp(Sender: TObject);
Begin
  Application.Terminate;
End;

End.
