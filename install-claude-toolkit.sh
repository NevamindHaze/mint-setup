#!/usr/bin/env bash
# Install (or update) my Claude Code toolkit, on Mint or Arch:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/NevamindHaze/mint-setup/main/install-claude-toolkit.sh)
#
# The Claude Code CLI, the GitHub plugins (Ponytail, LinkedIn Skills, Replica, Taste Skill), the 67
# design-* skills and OpenMontage. Superpowers, Code Review and the other desktop-app
# plugins come with the Claude desktop app, so they're not here.
# Needs Node.js, git, make, Python 3 and Chromium; setup.sh and arch-setup.sh install those first.
# Run it again any time to update everything.

set -u
FAILED=0
step() { printf '\n\e[1;32m==> %s\e[0m\n' "$1"; }
fail() { printf '\e[31m    %s\e[0m\n' "$1"; FAILED=1; }

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not with sudo."
    exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
BIN="$HOME/.local/bin"
mkdir -p "$BIN"
# Arch doesn't put ~/.local/bin on the PATH by itself (Mint does, from ~/.profile).
grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

step "Claude Code CLI"
# In ~/.local rather than system-wide, so it can update itself without sudo.
npm install -g --prefix "$HOME/.local" @anthropic-ai/claude-code >/dev/null \
    && printf '    %s\n' "$("$BIN/claude" --version)" || fail "Claude Code didn't install"

step "Plugins from GitHub"
for p in dietrichgebert/ponytail:ponytail sergebulaev/linkedin-skills:linkedin-skills \
         Jakeschincariol/replica-skill:replica-skill leonxlnx/taste-skill:taste-skill; do
    repo=${p%%:*}; name=${p##*:}
    # Both commands just say so when it's already there.
    "$BIN/claude" plugin marketplace add "$repo" >/dev/null \
        && "$BIN/claude" plugin install "$name@$name" >/dev/null \
        && echo "    $name" || fail "$name didn't install"
done

step "Design styles (67 design-* skills)"
# From awesome-design-skills; each one is renamed design-<style> so they sort together.
if curl -fsSL https://github.com/bergside/awesome-design-skills/archive/refs/heads/main.tar.gz \
    | tar -xz -C "$WORK"; then
    n=0
    for d in "$WORK"/awesome-design-skills-main/skills/*/; do
        style=$(basename "$d")
        dst="$HOME/.claude/skills/design-$style"
        mkdir -p "$dst" && cp -r "$d". "$dst/"
        sed -i "s/^name: .*/name: design-$style/" "$dst/SKILL.md"
        n=$((n + 1))
    done
    echo "    $n styles in ~/.claude/skills"
else
    fail "Couldn't download the design styles"
fi

step "OpenMontage (video production, in ~/OpenMontage)"
if [ -d "$HOME/OpenMontage/.git" ]; then
    git -C "$HOME/OpenMontage" pull -q
else
    git clone -q https://github.com/calesthio/OpenMontage.git "$HOME/OpenMontage"
fi && make -C "$HOME/OpenMontage" setup >/dev/null || fail "OpenMontage didn't set up"

if [ "$FAILED" -eq 0 ]; then
    echo
    echo "Claude toolkit ready. Start a new Claude session to load the plugins and skills."
fi
exit "$FAILED"
