# Packaging

Produces `CopilotQuotaWidget.dmg` — a drag-to-install macOS disk image for distribution via the DSG internal app repository.

## What's in the DMG

| Item | Description |
|---|---|
| `CopilotQuotaWidget.app` | One-shot installer app — double-click to install |
| `Applications` | Symlink to `~/Applications` for drag-install |

## What the installer app does

When double-clicked:
1. Copies `SwiftBar.app` to `~/Applications/` (bundled, no download)
2. Copies `gh` CLI universal binary to `~/Applications/` (bundled)
3. Checks `gh auth status` — opens Terminal for `gh auth login` if not authenticated
4. Copies widget scripts to `~/.config/copilot-quota-widget/`
5. Creates a Python venv + installs Pillow for PNG bar rendering
6. Configures SwiftBar plugins directory, symlinks the plugin
7. Runs initial quota fetch, launches SwiftBar
8. Shows a macOS notification on completion

## Building

### Prerequisites

- macOS with `hdiutil` (ships with macOS)
- Internet access (to download SwiftBar and gh CLI)

### Steps

```bash
# 1. Assemble bundled binaries (one-time, or when updating versions)
bash packaging/assemble.sh

# 2. Build the DMG
bash packaging/build-dmg.sh
```

Output: `packaging/dist/CopilotQuotaWidget.dmg`

### Updating bundled versions

Edit version strings in `packaging/assemble.sh` and re-run it, then rebuild the DMG.

## What's NOT committed

The following are assembled by `assemble.sh` and excluded from git (binaries are large):

- `CopilotQuotaWidget.app/Contents/Resources/SwiftBar.app`
- `CopilotQuotaWidget.app/Contents/Resources/gh`
- `dist/`
