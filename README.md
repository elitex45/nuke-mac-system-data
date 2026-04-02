# macOS Storage Cleanup

Shell script to reclaim disk space by nuking caches, `node_modules`, IDE junk, and optionally Docker/Ollama/Time Machine snapshots.

## Usage

```bash
# Quick cleanup — caches, node_modules, IDE junk
bash cleanup.sh

# Full nuke — adds Docker, Ollama models, Time Machine snapshots
bash cleanup.sh --full
```

## What it cleans

### Default mode

- **User & system caches** — `~/Library/Caches/*`, `/Library/Caches/*`, `~/Library/Logs/*`
- **npm cache** — `~/.npm/_cacache` (can grow to 10+ GB silently)
- **pip cache** — `~/Library/Caches/pip`
- **Homebrew cache** — stale downloads and old versions
- **pnpm / bun / node-gyp caches**
- **VS Code** — `CachedExtensionVSIXs`, `WebStorage`, `logs`, `CachedData`, `Cache`, `Crashpad`
- **Cursor** — `CachedData`, `CachedExtensionVSIXs`, `logs`, `Cache`
- **Claude Desktop** — `vm_bundles` (sandbox VMs, regenerated on demand)
- **All `node_modules`** — recursively found under `$HOME` and deleted. Run `npm install` in any project when needed.

### Full mode (`--full`)

Everything above, plus:

- **Docker** — `docker system prune -a --volumes -f` (removes all images, containers, volumes)
- **Ollama models** — `~/.ollama/models` (need to re-pull models after)
- **Time Machine local snapshots** — `sudo tmutil deletelocalsnapshots /`

## What it does NOT touch

- Your actual project source code
- Application settings and configs (`User/` dirs in VS Code/Cursor)
- Installed applications
- Documents, photos, or personal files
- Git history
- Homebrew-installed packages (only clears download cache)

## Expected recovery

Typical run reclaims 30-80+ GB depending on how long since last cleanup. The script prints before/after free space and per-item savings.

## Notes

- System caches (`/Library/Caches`) need a prior `sudo` auth or the script skips them silently.
- macOS Storage settings can take 5-10 minutes to update after cleanup. A restart forces reindex.
- Safe to run repeatedly. Everything deleted is either cache (regenerated automatically) or explicitly disposable.
