{
  lib,
  config,
  pkgs,
  ...
}:
# TODO - can we skip binding /etc
let
  cfg = config.agentDispatch;
  extraEnvArgsLines = lib.mapAttrsToList (
    # Keep the trailing backslash for bwrap line continuation.
    name: value: "--setenv ${lib.escapeShellArg name} ${lib.escapeShellArg value} \\"
  ) cfg.envs;
  extraEnvArgsBlock = lib.optionalString (extraEnvArgsLines != [ ]) (
    lib.concatStringsSep "\n      " extraEnvArgsLines
  );
  agent = pkgs.writeShellScriptBin "spawn-agent" ''
    set -euo pipefail

    WORKING_DIR="$1"
    shift

    BOUND_WORKSPACE_DIRS=()
    BOUND_DIRS=()
    for ws_repo_path in "$@"; do
      # bind repo in the workspace
      sudo chown -R agent:dev $ws_repo_path
      BOUND_WORKSPACE_DIRS+=(--bind "$ws_repo_path" "$ws_repo_path")
      BOUND_WORKSPACE_DIRS+=(--ro-bind "$ws_repo_path/.git" "$ws_repo_path/.git")
      BOUND_DIRS+=($ws_repo_path)

      # read-only bind the git directory
      suffix=$(echo "$ws_repo_path" | cut -d'/' -f5-)
      git_path="/var/git/''${suffix}.git"
      BOUND_WORKSPACE_DIRS+=(--ro-bind "$git_path" "$git_path")
    done

    trap ''' INT

    # Setup persistent dir
    existing_sessions=$(find /var/agents -maxdepth 1 -type d -name "session_*" 2>/dev/null | sort -r)
    options="[CREATE NEW SESSION]"
    if [ -n "$existing_sessions" ]; then
        options=$(echo -e "$options\n$existing_sessions")
    fi

    # Use fzf to select
    selection=$(echo "$options" | fzf --prompt="session > " --height=40% --reverse)

    if [ -z "$selection" ]; then
        echo "No selection made. Exiting."
        exit 1
    elif [ "$selection" = "[CREATE NEW SESSION]" ]; then
        timestamp=$(date +%Y%m%d_%H%M)
        random_word=$(shuf -n 1 /var/nxdata/eff_large_wordlist.txt)
        session_name="''${timestamp}_''${random_word}"
        SESSION_DIR="/var/agents/session_$session_name"
        
        mkdir -p "$SESSION_DIR"
    else
        SESSION_DIR="$selection"
    fi
    echo "Using session: $SESSION_DIR"

    # Setup home and run dir
    TMP_DIR=$(mktemp -d -p /tmp agent-run-XXXXXXXX)
    HOME_DIR=$TMP_DIR/home
    mkdir -p $HOME_DIR
    sudo chmod 770 -R "$TMP_DIR"
    sudo chmod g+s -R "$TMP_DIR"

    mkdir -p $SESSION_DIR/.pi

    if [ -d /var/gradle/wrapper ]; then
      mkdir -p $HOME_DIR/.gradle
      cp -r /var/gradle/wrapper $HOME_DIR/.gradle
    fi

    sudo chown -R agent:dev "$TMP_DIR"

    # proxy vars
    HOST_PROXY_PORT=9999
    SOCKET_PATH=$TMP_DIR/proxy.sock
    SOCAT_PID_FILE=$TMP_DIR/socat.pid

    cleanup() {
      if [ -f "$SOCAT_PID_FILE" ]; then
        pkill -F "$SOCAT_PID_FILE" 2>/dev/null || true
      fi
      sudo rm -rf $TMP_DIR

      # reset perms
      for ws_repo_path in $BOUND_DIRS; do
        sudo chown -R braden:braden $ws_repo_path
      done

      if [ -z "$SESSION_DIR" ] || [ ! -d "$SESSION_DIR" ]; then
          return
      fi
      
      echo ""
      echo "Session: $SESSION_DIR"
      read -p "Do you want to [k]eep or [d]elete this session? (k/d): " choice
      
      case "$choice" in
          d|D)
              echo "Deleting session directory..."
              sudo rm -rf "$SESSION_DIR"
              echo "Session deleted."
              ;;
          k|K|*)
              echo "Session kept at: $SESSION_DIR"
              ;;
      esac
    }
    trap cleanup EXIT

    sudo -u agent ${pkgs.socat}/bin/socat UNIX-LISTEN:"$SOCKET_PATH",fork TCP:127.0.0.1:$HOST_PROXY_PORT &
    echo $! > "$SOCAT_PID_FILE"

    echo "Working from $WORKING_DIR"
    cd "$WORKING_DIR"

    AGENT_UID=$(id -u agent)
    AGENT_GID=$(getent group dev | cut -d: -f3)

    sudo -u agent ${pkgs.bubblewrap}/bin/bwrap \
      --unshare-all \
      --uid "$AGENT_UID" \
      --gid "$AGENT_GID" \
      --hostname agent-container \
      --proc /proc \
      --dev /dev \
      --tmpfs /tmp \
      --ro-bind /nix /nix \
      --ro-bind /bin /bin \
      --ro-bind /run/current-system /run/current-system \
      --ro-bind /etc /etc \
      --bind "$HOME_DIR" "/home/agent" \
      --bind "$SESSION_DIR/.pi" "/home/agent/.pi" \
      --bind /home/agent/.cache/nix /home/agent/.cache/nix \
      --ro-bind /home/agent/.zsh /home/agent/.zsh \
      --ro-bind /home/agent/.zshrc /home/agent/.zshrc \
      --ro-bind /home/agent/.zshenv /home/agent/.zshenv \
      --ro-bind /home/agent/.config /home/agent/.config \
      --ro-bind /home/agent/.pi/agent/auth.json /home/agent/.pi/agent/auth.json \
      --ro-bind /var/gradle/caches/modules-2 /var/gradle/caches/modules-2 \
      --ro-bind /var/flakes /var/flakes \
      --bind "$SOCKET_PATH" "/run/proxy.sock" \
      "''${BOUND_WORKSPACE_DIRS[@]}" \
      --clearenv \
      --setenv PATH "/etc/profiles/per-user/agent/bin:/run/current-system/sw/bin:${pkgs.socat}/bin" \
      --setenv HOME "/home/agent" \
      --setenv TERM "xterm-256color" \
      --setenv LANG "''${LANG}" \
      --setenv USER "agent" \
      --setenv HISTFILE "/dev/null" \
      --setenv SAVEHIST "0" \
      --setenv GRADLE_RO_DEP_CACHE "/var/gradle/caches" \
      ${extraEnvArgsBlock}
      --die-with-parent \
      --new-session \
      ${pkgs.bash}/bin/bash -c "
        socat TCP-LISTEN:9998,fork,bind=127.0.0.1 UNIX-CONNECT:/run/proxy.sock &
        SOCAT_PID=\$!

        export http_proxy=http://127.0.0.1:9998
        export https_proxy=http://127.0.0.1:9998
        export HTTP_PROXY=http://127.0.0.1:9998
        export HTTPS_PROXY=http://127.0.0.1:9998
        export GRADLE_OPTS='-Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=9998 -Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=9998'

        # create new files/dirs with group write access
        umask 002
        exec ${pkgs.zsh}/bin/zsh -c 'tmux'
      "
  '';
in
{
  options.agentDispatch = {
    envs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables to pass into the agent bubblewrap container.";
      example = {
        FOO = "bar";
      };
    };
  };

  config = {
    home.packages = [
      agent
      pkgs.socat
    ];
  };
}
