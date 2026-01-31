{
  pkgs,
  ...
}:
let
  agent = pkgs.writeShellScriptBin "agent" ''
    set -euo pipefail

    if [ $# -ne 1 ]; then
      echo "Error: Missing change description" >&2
      echo "Usage: agent <description>" >&2
      exit 1
    fi

    DESCRIPTION="$1"

    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
    if [ -z "$GIT_ROOT" ]; then
      echo "Error: Must be in a git repository" >&2
      exit 1
    fi

    sudo mkdir -p /var/agents
    sudo chown agent:agent /var/agents
    sudo chmod g+s /var/agents
    sudo chmod 775 /var/agents

    REPO_NAME=$(basename "$GIT_ROOT")
    DATE=$(date +%Y%m%d)
    WORKTREE_PATH="/var/agents/''${REPO_NAME}/''${DATE}-''${DESCRIPTION}"

    echo "Creating worktree at $WORKTREE_PATH..."
    git worktree add "$WORKTREE_PATH"
    sudo chown -R agent:agent "$WORKTREE_PATH"
    cd "$WORKTREE_PATH"

    AGENT_UID=$(id -u agent)
    AGENT_GID=$(id -g agent)

    sudo -u agent ${pkgs.bubblewrap}/bin/bwrap \
      --unshare-all \
      --share-net \
      --uid "$AGENT_UID" \
      --gid "$AGENT_GID" \
      --proc /proc \
      --dev /dev \
      --tmpfs /tmp \
      --ro-bind /nix /nix \
      --ro-bind /run/current-system /run/current-system \
      --ro-bind /etc /etc \
      --bind "/home/agent" "/home/agent" \
      --bind "$WORKTREE_PATH" "$WORKTREE_PATH" \
      --chdir "$WORKTREE_PATH" \
      --clearenv \
      --setenv PATH "/etc/profiles/per-user/agent/bin:/run/current-system/sw/bin" \
      --setenv HOME "/home/agent" \
      --setenv TERM "xterm-256color" \
      --setenv LANG "''${LANG}" \
      --setenv USER "agent" \
      --setenv HISTFILE "/dev/null" \
      --setenv SAVEHIST "0" \
      --die-with-parent \
      --new-session \
      ${pkgs.zsh}/bin/zsh
  '';
in
{
  home.packages = ([
    agent
  ]);
}
