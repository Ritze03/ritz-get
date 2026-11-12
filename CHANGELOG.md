# Changelog

All notable user-facing changes, newest first. Categories:

**Added** (new features),
**Fixed** (bug and behaviour fixes),
**Removed** (things taken out),
**Info** (notes worth knowing).

## 2026-11-10

### Added
- **Teamspeak 6 mods**: added to the list of programs.

### Fixed
- **Offline use**: programs that could not be reached are remembered and stay hidden
  when you are offline.

## 2026-11-04

### Fixed
- **Update with admin rights**: updating now asks for your password like the other
  commands do.

## 2026-10-29

### Added
- **Deleted branches**: Ritz-Get notices when a program's branch was removed online and
  skips updating it.

### Fixed
- **Delete data**: you now confirm by typing the program's name.

### Info
- **Names**: Ritz-Get and Ritz-Get-GUI are now written that way everywhere.

## 2026-10-28

### Fixed
- **Running as root**: Ritz-Get now refuses to run as the administrator.
- **Failed first install**: the message after a failed first install is now clearer.

## 2026-10-27

### Fixed
- **Progress bar**: it now fills steadily instead of starting over.

## 2026-10-25

### Added
- **Progress bar**: installs and updates show a progress bar.
- **Quiet installs**: build details are hidden unless you ask for them with the
  verbose option.
- **Start menu shortcuts**: install offers a shortcut, and removing a website takes its
  shortcut away.
- **Delete data**: remove a program's saved data separately from the program itself.
- **Website icons**: websites in the list now have icons.
- **More programs**: added Forza Telemetry V3, Steam Userdata Copier and Ritz-Get-GUI.

## 2026-10-24

### Added
- **Hold**: keep a program from being updated.
- **Reset and switch**: reset a program or switch it to another branch.
- **Add-on support**: programs that need extra downloaded parts now install them
  correctly.
- **Program list**: Software, Helpers and websites are listed in groups, with extra
  setup steps shown after install.
- **Machine-readable list**: a list format for graphical frontends.

### Fixed
- **Install location**: Ritz-Get always updates itself from its own folder.

## 2026-10-22

### Added
- **First release**: a package manager that installs, updates and removes the author's
  programs by building them from source.
