# cmux development Justfile
# Usage: just <recipe>

# Default tag for dev builds
default_tag := "dev"

# Show available recipes
default:
    @just --list

# First-time setup: init submodules + build/download GhosttyKit
setup:
    git submodule update --init --recursive
    @if [ -d "GhosttyKit.xcframework" ]; then \
        echo "==> GhosttyKit.xcframework already exists, skipping"; \
    elif command -v zig >/dev/null 2>&1; then \
        echo "==> zig found, running full setup..."; \
        ./scripts/setup.sh; \
    else \
        echo "==> zig not found, downloading prebuilt GhosttyKit..."; \
        cd "$(git rev-parse --show-toplevel)" && bash scripts/download-prebuilt-ghosttykit.sh; \
    fi

# Force re-download GhosttyKit (ignores cache)
setup-force:
    git submodule update --init --recursive
    rm -rf GhosttyKit.xcframework
    @if command -v zig >/dev/null 2>&1; then \
        ./scripts/setup.sh; \
    else \
        cd "$(git rev-parse --show-toplevel)" && bash scripts/download-prebuilt-ghosttykit.sh; \
    fi

# Build and launch debug app with a tag (isolated instance)
run tag=default_tag:
    ./scripts/reload.sh --tag {{tag}}

# Build and launch release app
run-release:
    ./scripts/reloadp.sh

# Build and launch staging app (isolated from production)
run-staging:
    ./scripts/reloads.sh

# Build only (no launch) — verify compilation
build tag=default_tag:
    xcodebuild -project GhosttyTabs.xcodeproj -scheme cmux -configuration Debug -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/cmux-{{tag}}" build 2>&1 | grep -E '(warning:|error:|fatal:|BUILD FAILED|BUILD SUCCEEDED|\*\* BUILD)' || true

# Build release configuration only (no launch)
build-release:
    xcodebuild -project GhosttyTabs.xcodeproj -scheme cmux -configuration Release -destination 'platform=macOS' build 2>&1 | grep -E '(warning:|error:|fatal:|BUILD FAILED|BUILD SUCCEEDED|\*\* BUILD)' || true

# Run unit tests (safe — no app launch)
test-unit:
    ./scripts/test-unit.sh

# Tail the debug log for a tagged build
log tag=default_tag:
    tail -f "/tmp/cmux-debug-{{tag}}.log"

# Tail the latest debug log (auto-detected)
log-latest:
    tail -f "$(cat /tmp/cmux-last-debug-log-path 2>/dev/null || echo /tmp/cmux-debug.log)"

# Kill a tagged debug instance
kill tag=default_tag:
    pkill -f "cmux DEV {{tag}}.app/Contents/MacOS/cmux DEV" || echo "No running instance with tag '{{tag}}'"

# Kill all debug instances
kill-all:
    pkill -f "cmux DEV.*app/Contents/MacOS/cmux DEV" || echo "No running debug instances"

# Clean derived data for a tag
clean tag=default_tag:
    rm -rf "$HOME/Library/Developer/Xcode/DerivedData/cmux-{{tag}}"
    rm -rf "/tmp/cmux-{{tag}}"
    rm -f "/tmp/cmux-debug-{{tag}}.sock"
    rm -f "/tmp/cmux-debug-{{tag}}.log"
    @echo "Cleaned tag '{{tag}}'"

# Clean ALL derived data
clean-all:
    rm -rf "$HOME/Library/Developer/Xcode/DerivedData/cmux-"*
    rm -rf /tmp/cmux-*
    @echo "Cleaned all cmux derived data"

# Rebuild GhosttyKit xcframework (release optimized)
rebuild-ghosttykit:
    cd ghostty && zig build -Demit-xcframework=true -Dxcframework-target=universal -Doptimize=ReleaseFast

# Rebuild cmuxd (release optimized)
rebuild-cmuxd:
    cd cmuxd && zig build -Doptimize=ReleaseFast

# Show git diff stats
diff:
    git diff --stat

# Show full diff
diff-full:
    git diff

# Show suspended workspaces JSON (if any)
show-suspended:
    @cat "$HOME/Library/Application Support/cmux/suspended-workspaces-"*.json 2>/dev/null | python3 -m json.tool || echo "No suspended workspaces file found"

# Clear all suspended workspaces from disk
clear-suspended:
    rm -f "$HOME/Library/Application Support/cmux/suspended-workspaces-"*.json
    @echo "Cleared suspended workspaces"

# Bump version (minor by default)
bump level="":
    ./scripts/bump-version.sh {{level}}

# OpenSpec status for the workspace-suspend-restore change
spec-status:
    openspec status --change workspace-suspend-restore
