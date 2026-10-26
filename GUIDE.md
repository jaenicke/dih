# DIH Configuration Guide

This guide explains the XML configuration format and walks through setting up the Delphi Install Helper for your own component packages.

## Table of Contents

- [XML Structure](#xml-structure)
- [Entry Elements](#entry-elements)
  - [paths](#paths)
  - [files](#files)
  - [build](#build)
  - [packages](#packages)
  - [registry](#registry)
  - [pre / post](#pre--post-events)
  - [source](#external-xml-references)
- [Placeholders](#placeholders)
- [Batch Scripts](#batch-scripts)
- [Build Modes](#build-modes)
- [Walkthrough: Example Component](#walkthrough-example-component)

---

## XML Structure

The configuration file has a `<dih>` root element containing one or more `<entry>` elements. Each entry represents an independent unit of work (a component library, global settings, etc.).

```xml
<?xml version="1.0" encoding="UTF-8"?>
<dih>
    <entry id="unique_id" description="Human-readable description">
        <!-- elements: paths, files, build, packages, registry, pre, post, source -->
    </entry>
</dih>
```

Entries are processed in document order. During **install**, the processing order within each entry is:

1. Pre-events
2. Registry values
3. Library paths
4. File copy
5. Build projects
6. Register packages
7. Post-events

During **uninstall**, the order is reversed (packages first, then paths, then registry, etc.).

---

## Entry Elements

### paths

Manages Delphi library paths. Three types are supported, each mapping to a specific Registry value and `EnvOptions.proj` property:

| Type | Registry Value | EnvOptions.proj Property |
|---|---|---|
| `<search>` | Search Path | DelphiLibraryPath |
| `<browsing>` | Browsing Path | DelphiBrowsingPath |
| `<namespace>` | Namespace Search Path | DelphiNamespaceSearchPath |

Both the Registry and `EnvOptions.proj` are updated simultaneously, so changes take effect without restarting the IDE.

```xml
<paths>
    <namespace platforms="Win32,Win64">
        <path>Vcl</path>
    </namespace>
    <search platforms="Win32,Win64">
        <path recursive="False">{#DcuTargetDir}</path>
    </search>
    <browsing platforms="Win32,Win64">
        <entry recursive="False">Source</entry>
    </browsing>
</paths>
```

The `platforms` attribute filters which platforms the paths apply to. If omitted, all platforms are used.

### files

Copies files to a target directory. Supports wildcards (`*.res`, `*.dcr`, etc.).

```xml
<files platforms="Win32,Win64">
    <file target="{#DcuTargetDir}">Source\MyComponent.res</file>
    <file target="{#DcuTargetDir}">Source\*.dcr</file>
</files>
```

| Attribute | Values | Default | Description |
|---|---|---|---|
| `platforms` | `Win32`, `Win64` | all | Platforms this group is copied for |
| `stage` | `after-build` | *(before the build)* | When the group is copied |

By default the files are **inputs** to the build and are copied before it -
a resource the compiler needs, for instance. `stage="after-build"` marks them
as **artefacts** of this entry's own `<build>`, so they are copied once the
projects are compiled:

```xml
<build platforms="Win32">
    <project>Tools\MyTool.dproj</project>
</build>
<files platforms="Win32" stage="after-build">
    <file target="{#LocalAppData}\MyComponent\bin">Tools\Bin\MyTool.exe</file>
</files>
```

Without it the copy would run before the compiler and install the *previous*
build. Both stages may appear in one entry: use two `<files>` elements, one of
each. When the build fails, the artefacts are **not** copied - the target keeps
the file it had - and the log says how many were left alone.

A target that is currently **running** can still be replaced: Windows refuses
to overwrite such a file but allows renaming it, so the old one is moved aside
as `<name>.<number>.old` and the new one takes its place. The aside copy is
left behind on purpose - a file somebody is executing cannot be deleted - and
the log names it.

A source file or directory that is not there **fails the entry** and is
reported in the summary. Nothing is installed half way without saying so.

During uninstall, the copied files are deleted from the target directory.

### build

Compiles Delphi projects via msbuild or bds.exe. The DCU, BPL, and DCP output directories are passed automatically.

```xml
<build platforms="Win32,Win64">
    <project>Packages\MyPkgR.dproj</project>
</build>
<build platforms="Win32">
    <project>Packages\MyPkgD.dproj</project>
</build>
```

Additional msbuild parameters can be specified per `<build>` or per `<project>`:

```xml
<build platforms="Win32" params="/p:DCC_AdditionalSwitches=&quot;-$O+&quot;">
    <project>Packages\MyPkgR.dproj</project>
    <project params="/v:d">Packages\MyPkgD.dproj</project>
</build>
```

### packages

Registers BPL packages in the IDE's Known Packages registry key.

```xml
<packages platforms="Win32">
    <package description="My Design-Time Package">$(BDSCOMMONDIR)\Bpl\MyPkgD.bpl</package>
</packages>
```

> **Note:** Use `$(BDSCOMMONDIR)` syntax (not `{#...}`) for package paths. The IDE stores and resolves these variables itself.

### registry

Sets arbitrary registry values under `HKEY_CURRENT_USER`. Supports `String` (default) and `Integer` types.

```xml
<registry path="{#BDS}\Editor\Options">
    <value name="Right Margin" type="Integer">130</value>
</registry>
<registry path="{#BDS}\Auto Save">
    <value name="Editor Files">True</value>
</registry>
```

The `{#BDS}` placeholder resolves to the BDS registry path (e.g. `Software\Embarcadero\BDS\23.0`).

### pre / post Events

Execute shell commands before or after the entry is processed. Placeholders are resolved in commands.

```xml
<pre platforms="Win32,Win64">
    <exec description="Compile resource script">brcc32 Source\MyRes.rc -foSource\MyRes.res</exec>
</pre>
<post platforms="Win32">
    <exec description="Run post-install check">check.bat {#Platform}</exec>
</post>
```

Commands are executed via `cmd.exe /c` with the XML file's directory as working directory.

### External XML References

Split configuration into multiple files using `<source>`. The referenced file must have the same `<dih>` root structure.

```xml
<!-- Main config -->
<entry id="settings" description="IDE settings (external)">
    <source>config\ide_settings.xml</source>
</entry>
```

```xml
<!-- config\ide_settings.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<dih>
    <entry id="settings" description="IDE editor settings">
        <registry path="{#BDS}\Editor\Options">
            <value name="Right Margin" type="Integer">130</value>
        </registry>
    </entry>
</dih>
```

---

## Placeholders

### Built-in Placeholders (`{#...}`)

| Placeholder | Example Value | Description |
|---|---|---|
| `{#DcuTargetDir}` | `.\DCU\Win32\Release` | DCU output directory |
| `{#BplTargetDir}` | `C:\Users\Public\...\Bpl` | BPL output directory |
| `{#DcpTargetDir}` | `C:\Users\Public\...\Dcp` | DCP output directory |
| `{#Platform}` | `Win32` | Current platform |
| `{#Config}` | `Release` | Current build configuration |
| `{#BaseDir}` | `C:\MyProject\` | XML file directory |
| `{#BDS}` | `Software\Embarcadero\BDS\23.0` | BDS registry path |
| `{#BDSVersion}` | `23.0` | BDS version number |
| `{#BDSRootDir}` | `C:\Program Files (x86)\...\Studio\23.0` | BDS installation directory |
| `{#BDSCommonDir}` | `C:\Users\Public\...\Studio\23.0` | BDS common directory |
| `{#LibSuffix}` | `230` | BDS version without the dot - the suffix `{$LIBSUFFIX AUTO}` appends to a package, so a config can name the built BPL without hard-coding the IDE version |
| `{#LocalAppData}` | `C:\Users\me\AppData\Local` | The current user's local application data directory (from the environment, so a packaged host's redirected view is what a target resolves to) |

### Environment Variables (`$(...)`)

Delphi-style environment variables like `$(BDSCOMMONDIR)` are also supported. DIH first tries to resolve them from its known values, then falls back to Windows environment variables.

### Custom Placeholders

Override any placeholder via command line:

```
delinst.exe 37.0 -config my.xml -D:DcuTargetDir=C:\MyCustomDCU
```

---

## Batch Scripts

### Minimal install.cmd

```batch
@echo off
setlocal

set BDSVER=23.0
set DELINST=%~dp0delinst.exe
set CONFIG=myconfig.xml
set USEBDS=

:: Build delinst.exe (auto-detects msbuild vs bds.exe)
call "%~dp0dih\builddih.cmd" %BDSVER%
if %ERRORLEVEL% NEQ 0 goto :error

:: Check if bds.exe fallback was used
if exist "%~dp0.dih_usebds" set USEBDS=-usebds

"%DELINST%" %BDSVER% -config "%CONFIG%" -platforms Win32 -configs Release -action install -verbose log %USEBDS%
if %ERRORLEVEL% NEQ 0 goto :error

echo Installation completed successfully.
pause
exit /b 0

:error
pause
exit /b 1
```

The `builddih.cmd` script:
1. Reads the BDS root directory from the Registry
2. Calls `rsvars.bat` to set up the build environment
3. Tries msbuild - if it fails (e.g. Community Edition), falls back to bds.exe
4. Creates a `.dih_usebds` marker file if bds.exe was used
5. Outputs `delinst.exe` to the parent directory

---

## Build Modes

### msbuild (default)

Used when a command-line compiler is available (Professional/Enterprise/Architect editions). Each project is built individually with output directories passed via `/p:` parameters.

### bds.exe (-usebds)

Used when no command-line compiler is available (Community Edition / Trial). DIH creates a temporary `.groupproj` for each project that passes the output directories as MSBuild properties. A background thread auto-closes any save dialogs that bds.exe may show.

The build mode is detected automatically by the batch scripts and passed to `delinst.exe` via the `-usebds` flag.

---

## Walkthrough: Example Component

The repository includes a complete example with `TDIHMemo`, a `TMemo` descendant with a line number gutter.

### Directory Layout

```
Delphi Install Helper/
  dih/                      # DIH tool
  Packages/
    DIHExamplePkgR.dpk      # Runtime package
    DIHExamplePkgD.dpk      # Design-time package
  Source/
    DIHExample.Memo.pas     # TDIHMemo component
    DIHExample.Memo.rc      # Resource script (component bitmap)
    DIHExample.Memo.bmp     # 24x24 palette bitmap
    DIHExample.Reg.pas      # Component registration
  config/
    ide_settings.xml        # External config: sets Right Margin to 130
  dihexample.xml            # Main configuration
  install.cmd               # Install script
  uninstall.cmd             # Uninstall script
  rebuild.cmd               # Build-only script
```

### Configuration (dihexample.xml)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<dih>
    <!-- External reference: IDE settings from separate file -->
    <entry id="ide_settings" description="IDE editor settings (external XML)">
        <source>config\ide_settings.xml</source>
    </entry>

    <!-- Global: add DCU directory to search path -->
    <entry id="global" description="Global settings for DIH Example">
        <paths>
            <search platforms="Win32,Win64">
                <path recursive="False">{#DcuTargetDir}</path>
            </search>
        </paths>
    </entry>

    <!-- Component: pre-event, paths, files, build, packages -->
    <entry id="dihexample" description="DIH Example Component (TDIHMemo)">
        <pre platforms="Win32,Win64">
            <exec description="Compile DIHExample.Memo resource">
                brcc32 Source\DIHExample.Memo.rc -foSource\DIHExample.Memo.res
            </exec>
        </pre>
        <paths>
            <browsing platforms="Win32,Win64">
                <entry recursive="False">Source</entry>
            </browsing>
        </paths>
        <files platforms="Win32,Win64">
            <file target="{#DcuTargetDir}">Source\DIHExample.Memo.res</file>
        </files>
        <packages platforms="Win32">
            <package description="DIH Example Design-Time Package">
                $(BDSCOMMONDIR)\Bpl\DIHExamplePkgD.bpl
            </package>
        </packages>
        <build platforms="Win32,Win64">
            <project>Packages\DIHExamplePkgR.dproj</project>
        </build>
        <build platforms="Win32">
            <project>Packages\DIHExamplePkgD.dproj</project>
        </build>
    </entry>
</dih>
```

### What happens during install of the example

1. **ide_settings** - Loads `config\ide_settings.xml`, sets Right Margin to 130 in the IDE
2. **global** - Adds `.\DCU\Win32\Release` to the library search path
3. **dihexample**:
   - Pre-event: Compiles `DIHExample.Memo.rc` to `.res` via `brcc32`
   - Paths: Adds `Source` to the browsing path
   - Files: Copies `DIHExample.Memo.res` to the DCU directory
   - Build: Compiles the runtime package (Win32+Win64) and design-time package (Win32)
   - Packages: Registers `DIHExamplePkgD.bpl` in the IDE
