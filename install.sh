#!/usr/bin/env bash
# WordGet installer — Linux & macOS
#
#   curl -fsSL https://raw.githubusercontent.com/tsarouxas/wordget/master/install.sh | bash
#
# Environment overrides:
#   WORDGET_INSTALL_DIR  target directory (default: ~/.local/bin)
#   WORDGET_REF          git branch/tag to install from (default: master)
#
# Running it again upgrades to the latest version.

set -euo pipefail

# Wrapped in main() so a truncated download can't execute half a script.
main() {
    local repo="tsarouxas/wordget"
    local ref="${WORDGET_REF:-master}"
    local url="https://raw.githubusercontent.com/${repo}/${ref}/wordget.sh"
    local name="wordget"

    say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
    warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
    die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

    case "$(uname -s)" in
        Linux*|Darwin*) ;;
        *) die "Unsupported OS: $(uname -s). Only Linux and macOS are supported." ;;
    esac

    # Downloader
    local fetch
    if command -v curl >/dev/null 2>&1; then
        fetch="curl -fsSL"
    elif command -v wget >/dev/null 2>&1; then
        fetch="wget -qO-"
    else
        die "curl or wget is required."
    fi

    # Current user only, no sudo.
    local dir="${WORDGET_INSTALL_DIR:-$HOME/.local/bin}"
    mkdir -p "$dir" || die "Could not create ${dir}"
    [ -w "$dir" ] || die "${dir} is not writable by $(id -un)"

    # Download to a temp file and sanity-check before touching the target.
    # Global (not local) so the EXIT trap can still see it after main returns.
    WORDGET_TMP="$(mktemp "${TMPDIR:-/tmp}/wordget.XXXXXX")"
    trap 'rm -f "${WORDGET_TMP:-}"' EXIT
    local tmp="$WORDGET_TMP"

    say "Downloading wordget (${ref})"
    $fetch "$url" > "$tmp" || die "Download failed: $url"
    head -n1 "$tmp" | grep -q '^#!.*bash' || die "Downloaded file doesn't look like wordget.sh"
    bash -n "$tmp" || die "Downloaded script has syntax errors; aborting."
    chmod 755 "$tmp"

    local target="${dir}/${name}"
    say "Installing to ${target}"
    rm -f "$target"
    install -m 755 "$tmp" "$target"

    local version
    version="$(grep -m1 -o 'WordGet v[0-9.]*' "$target" || true)"
    say "Installed ${version:-wordget}"

    # PATH check
    case ":${PATH}:" in
        *":${dir}:"*) ;;
        *)
            warn "${dir} is not in your PATH. Add this to your shell profile (~/.zshrc or ~/.bashrc):"
            printf '    export PATH="%s:$PATH"\n' "$dir" >&2
            ;;
    esac

    local found
    found="$(command -v "$name" 2>/dev/null || true)"
    if [ -n "$found" ] && [ "$found" != "$target" ]; then
        warn "Another wordget at ${found} comes first in your PATH and will be used instead."
        warn "Remove it (e.g. rm ${found}) or put ${dir} earlier in PATH."
    fi

    # Runtime dependencies (informational only)
    local missing="" bin
    for bin in ssh rsync mysql mysqldump wp gzip; do
        command -v "$bin" >/dev/null 2>&1 || missing="$missing $bin"
    done
    if [ -n "$missing" ]; then
        warn "Not found on this machine:$missing"
        warn "wordget needs ssh + rsync; mysql/mysqldump for -d imports; wp-cli for localwp/vvv/localmode."
    fi

    say "Done. Run: wordget"
}

main "$@"
