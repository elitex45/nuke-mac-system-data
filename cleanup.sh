#!/bin/bash
# macOS Storage Cleanup Script
# Run with: bash cleanup.sh
# For full cleanup (including Docker/Ollama): bash cleanup.sh --full

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FULL=false
if [[ "$1" == "--full" ]]; then
    FULL=true
fi

freed=0

bytes_to_gb() {
    echo "scale=2; $1 / 1073741824" | bc
}

get_size() {
    if [ -e "$1" ]; then
        du -sk "$1" 2>/dev/null | awk '{print $1 * 1024}'
    else
        echo 0
    fi
}

clean() {
    local label="$1"
    local path="$2"
    local size=$(get_size "$path")
    if [ "$size" -gt 0 ] 2>/dev/null; then
        local gb=$(bytes_to_gb "$size")
        rm -rf "$path"
        freed=$((freed + size))
        echo -e "${GREEN}✓${NC} $label — freed ${gb} GB"
    fi
}

clean_cmd() {
    local label="$1"
    shift
    echo -e "${YELLOW}→${NC} $label"
    "$@" 2>/dev/null || true
}

echo ""
echo "============================================"
echo "  macOS Storage Cleanup"
echo "============================================"
echo ""

# --- Disk usage before ---
before=$(df -k / | tail -1 | awk '{print $4}')
echo -e "${YELLOW}Free space before:${NC} $(bytes_to_gb $((before * 1024))) GB"
echo ""

# --- Caches ---
echo -e "${RED}[ Caches ]${NC}"
clean "User caches" "$HOME/Library/Caches"
clean "System caches (needs prior sudo)" "/Library/Caches"
clean "User logs" "$HOME/Library/Logs"
echo ""

# --- Dev tool caches ---
echo -e "${RED}[ Dev Tools ]${NC}"
clean_cmd "npm cache" npm cache clean --force
clean "npm cache dir" "$HOME/.npm/_cacache"
clean_cmd "pip cache" pip cache purge
clean_cmd "Homebrew cleanup" brew cleanup --prune=all
clean "Homebrew cache" "$HOME/Library/Caches/Homebrew"
clean "pnpm cache" "$HOME/Library/Caches/pnpm"
clean "bun cache" "$HOME/Library/Caches/bun"
clean "node-gyp cache" "$HOME/Library/Caches/node-gyp"
echo ""

# --- IDE caches ---
echo -e "${RED}[ IDE Caches ]${NC}"
clean "VS Code cached extensions" "$HOME/Library/Application Support/Code/CachedExtensionVSIXs"
clean "VS Code WebStorage" "$HOME/Library/Application Support/Code/WebStorage"
clean "VS Code logs" "$HOME/Library/Application Support/Code/logs"
clean "VS Code CachedData" "$HOME/Library/Application Support/Code/CachedData"
clean "VS Code Cache" "$HOME/Library/Application Support/Code/Cache"
clean "VS Code Crashpad" "$HOME/Library/Application Support/Code/Crashpad"
clean "Cursor CachedData" "$HOME/Library/Application Support/Cursor/CachedData"
clean "Cursor cached extensions" "$HOME/Library/Application Support/Cursor/CachedExtensionVSIXs"
clean "Cursor logs" "$HOME/Library/Application Support/Cursor/logs"
clean "Cursor Cache" "$HOME/Library/Application Support/Cursor/Cache"
clean "Claude vm_bundles" "$HOME/Library/Application Support/Claude/vm_bundles"
echo ""

# --- node_modules ---
echo -e "${RED}[ node_modules ]${NC}"
echo -e "${YELLOW}→${NC} Scanning for node_modules..."
nm_total=0
while IFS= read -r dir; do
    size=$(get_size "$dir")
    if [ "$size" -gt 0 ] 2>/dev/null; then
        gb=$(bytes_to_gb "$size")
        echo -e "  ${GREEN}✓${NC} $(echo "$dir" | sed "s|$HOME|~|") — ${gb} GB"
        rm -rf "$dir"
        nm_total=$((nm_total + size))
    fi
done < <(find "$HOME" -name "node_modules" -type d -prune 2>/dev/null)
if [ "$nm_total" -gt 0 ]; then
    freed=$((freed + nm_total))
    echo -e "  Total node_modules freed: $(bytes_to_gb $nm_total) GB"
else
    echo "  No node_modules found."
fi
echo ""

# --- Full mode: Docker, Ollama, Time Machine ---
if $FULL; then
    echo -e "${RED}[ Full Cleanup — Docker, Ollama, Time Machine ]${NC}"

    docker_size=$(get_size "$HOME/Library/Containers/com.docker.docker")
    if [ "$docker_size" -gt 0 ] 2>/dev/null; then
        echo -e "${YELLOW}→${NC} Docker cleanup ($(bytes_to_gb $docker_size) GB)..."
        docker system prune -a --volumes -f 2>/dev/null || true
        new_size=$(get_size "$HOME/Library/Containers/com.docker.docker")
        saved=$((docker_size - new_size))
        if [ "$saved" -gt 0 ]; then
            freed=$((freed + saved))
            echo -e "${GREEN}✓${NC} Docker — freed $(bytes_to_gb $saved) GB"
        fi
    fi

    clean "Ollama models" "$HOME/.ollama/models"

    echo -e "${YELLOW}→${NC} Deleting Time Machine local snapshots..."
    sudo tmutil deletelocalsnapshots / 2>/dev/null || true
    echo ""
fi

# --- Disk usage after ---
after=$(df -k / | tail -1 | awk '{print $4}')
echo "============================================"
echo -e "${GREEN}Free space after:${NC}  $(bytes_to_gb $((after * 1024))) GB"
echo -e "${GREEN}Space recovered:${NC}  $(bytes_to_gb $((( after - before ) * 1024))) GB"
echo "============================================"
echo ""
echo "Tip: Restart or wait 5 min for macOS Storage to update."
