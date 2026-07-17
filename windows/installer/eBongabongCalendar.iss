; Packages the Flutter Windows release build
; (build\windows\x64\runner\Release\*, produced by `flutter build windows
; --release`) into a normal Windows installer, instead of shipping that
; folder as a raw zip.
;
; Compiled by .github/workflows/release.yml with:
;   ISCC.exe /DMyAppVersion=<version> windows\installer\eBongabongCalendar.iss
;
; Upgrades: as long as AppId and DefaultDirName stay identical release to
; release, running a newer version's installer over an existing install
; updates it in place — no uninstall/delete step needed.

#define MyAppName "eBongabong Calendar"
#define MyAppExeName "barangay_events.exe"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#define MyAppPublisher "Municipality of Bongabong"

[Setup]
; Fixed forever — this is what lets a newer version's installer recognize
; and upgrade an existing install instead of installing side-by-side.
; NEVER regenerate this.
AppId={{39EAA7A9-F313-4318-A9D1-8E1C284D2917}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
; Per-user install (no admin/UAC prompt needed) — same default as VS Code's
; own installer, friendlier for barangay-office machines without IT/admin
; access.
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputBaseFilename=e-calendar-{#MyAppVersion}-setup
OutputDir=..\..\installer_output
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
