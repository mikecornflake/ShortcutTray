# Inspector Mike Portable Start Menu

**IM_Start** is a lightweight Lazarus/LCL system tray application
that provides quick access to your favourite applications, folders and
documents.

It reads a simple `shortcuts.txt` file located alongside the executable
and builds a hierarchical popup menu. The configuration is designed to
be easy to edit with any text editor and is ideal for portable USB
drives, offshore toolkits, and development environments.

## Features

-   Launch applications, documents and folders.
-   User-defined menu groups.
-   User-defined path tokens.
-   Supports command-line parameters.
-   Automatically hides shortcuts whose target does not exist.
-   Portable -- no installation or registry entries required.

## Configuration

ShortcutTray reads `shortcuts.txt` from the executable folder.

### Comments

Blank lines are ignored.

Lines beginning with `;` or `#` are treated as comments.

### Tokens

A special `[Tokens]` section allows commonly-used paths to be defined
once and reused throughout the file.

``` ini
[Tokens]
apps=B:\Apps
code=B:\Code
project=Z:\Current Project
```

Tokens are referenced using angle brackets:

``` ini
Lazarus=<apps>\Dev\lazarus\lazarus.exe
Reports=<project>\Reports
```

`<exedir>` is also supported, allowing shortcuts relative to the
executable location.

### Menus

Each section becomes a submenu.

``` ini
[Development]
Lazarus=<apps>\Dev\lazarus\lazarus.exe
DBeaver=<apps>\Dev\dbeaver\dbeaver.exe

[Utilities]
Explorer=<exedir>\Tools\Explorer.exe
```

### Shortcut format

Each shortcut is written as:

``` text
Caption=Target [optional parameters]
```

Examples:

``` ini
Notepad++=B:\PortableApps\Notepad++Portable\Notepad++Portable.exe

Kodi=B:\Apps\Dev\Kodi\kodi.exe -p

Project Folder=<project>

Daily Report=<project>\Reports\Daily Report.docx
```

If no caption is supplied, the filename is used.

### Separators

A line containing only a single dash creates a menu separator.

``` ini
[Development]
Lazarus=...
DBeaver=...
-
Arduino IDE=...
```

## Missing shortcuts

ShortcutTray checks that each target exists before adding it to the
menu.

This allows a single configuration file to be shared across multiple
computers or portable drives. Missing applications or folders are simply
omitted from the menu.

## License

Released under the GNU General Public License v3.0.
