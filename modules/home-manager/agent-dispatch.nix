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
  extraEnvArgsBlock =
    if extraEnvArgsLines != [ ] then lib.concatStringsSep "\n      " extraEnvArgsLines else "\\";

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

    # make some required dirs
    sudo -u agent mkdir -p /home/agent/.cache/nix
    mkdir -p /var/gradle/caches/modules-2
    chown braden:dev /var/gw

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

    # proxy + trust vars
    HOST_PROXY_PORT=9999
    SOCKET_PATH=$TMP_DIR/proxy.sock
    SOCAT_PID_FILE=$TMP_DIR/socat.pid
    DOCKER_SOCKET_PATH=$TMP_DIR/docker.sock
    DOCKER_SSH_PID_FILE=$TMP_DIR/docker-ssh.pid

    MITM_CA_CERT_HOST=/var/lib/agent-mitmproxy/mitmproxy-ca-cert.pem
    MITM_CA_CERT_TMP=$TMP_DIR/mitmproxy-ca-cert.pem
    JAVA_TRUSTSTORE_HOST=$TMP_DIR/java-mitm-truststore.jks

    if [ ! -f "$MITM_CA_CERT_HOST" ]; then
      echo "ERROR: mitm CA cert still missing at $MITM_CA_CERT_HOST"
      exit
    fi

    cp "$MITM_CA_CERT_HOST" "$MITM_CA_CERT_TMP"
    ${pkgs.jdk17_headless}/bin/keytool \
      -importcert \
      -noprompt \
      -alias agent-mitmproxy-ca \
      -file "$MITM_CA_CERT_TMP" \
      -keystore "$JAVA_TRUSTSTORE_HOST" \
      -storepass changeit
    chmod 644 "$MITM_CA_CERT_TMP" "$JAVA_TRUSTSTORE_HOST"

    sudo chown -R agent:dev "$TMP_DIR"

    cleanup() {
      if [ -f "$SOCAT_PID_FILE" ]; then
        pkill -F "$SOCAT_PID_FILE" 2>/dev/null || true
      fi
      if [ -f "$DOCKER_SSH_PID_FILE" ]; then
        pkill -F "$DOCKER_SSH_PID_FILE" 2>/dev/null || true
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

    REMOTE_DOCKER_UID=$(${pkgs.openssh}/bin/ssh docker_host id -u)
    REMOTE_DOCKER_SOCKET="/run/user/$REMOTE_DOCKER_UID/docker.sock"
    rm -f "$DOCKER_SOCKET_PATH"
    ${pkgs.openssh}/bin/ssh -nNT \
      -o ExitOnForwardFailure=yes \
      -o StreamLocalBindUnlink=yes \
      -o StreamLocalBindMask=0117 \
      -L "$DOCKER_SOCKET_PATH:$REMOTE_DOCKER_SOCKET" \
      docker_host &
    echo $! > "$DOCKER_SSH_PID_FILE"

    for _ in $(${pkgs.coreutils}/bin/seq 1 50); do
      if [ -S "$DOCKER_SOCKET_PATH" ]; then
        break
      fi
      sleep 0.1
    done

    if [ ! -S "$DOCKER_SOCKET_PATH" ]; then
      echo "ERROR: docker socket tunnel failed to come up at $DOCKER_SOCKET_PATH"
      exit 1
    fi

    sudo chown agent:dev "$DOCKER_SOCKET_PATH"
    sudo chmod 660 "$DOCKER_SOCKET_PATH"

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
      --ro-bind /usr/bin /usr/bin \
      --ro-bind /run/current-system /run/current-system \
      --ro-bind /etc /etc \
      --bind "$HOME_DIR" "/home/agent" \
      --bind "$SESSION_DIR/.pi" "/home/agent/.pi" \
      --bind /home/agent/.cache/nix /home/agent/.cache/nix \
      --ro-bind /home/agent/.zsh /home/agent/.zsh \
      --ro-bind /home/agent/.zshrc /home/agent/.zshrc \
      --ro-bind /home/agent/.zshenv /home/agent/.zshenv \
      --ro-bind /home/agent/.config /home/agent/.config \
      --ro-bind /home/agent/.pi/agent/extensions /home/agent/.pi/agent/extensions \
      --ro-bind /home/agent/.pi/agent/auth.json /home/agent/.pi/agent/auth.json \
      --ro-bind /var/gradle/caches/modules-2 /var/gradle/caches/modules-2 \
      --ro-bind /var/pnpm /var/pnpm \
      --ro-bind /var/flakes /var/flakes \
      --dir /run/mitm \
      --ro-bind "$MITM_CA_CERT_TMP" "/run/mitm/mitmproxy-ca-cert.pem" \
      --ro-bind "$JAVA_TRUSTSTORE_HOST" "/run/mitm/java-truststore.jks" \
      --bind "$SOCKET_PATH" "/run/proxy.sock" \
      --bind "$DOCKER_SOCKET_PATH" "/run/docker.sock" \
      "''${BOUND_WORKSPACE_DIRS[@]}" \
      --clearenv \
      --setenv PATH "/etc/profiles/per-user/agent/bin:/run/current-system/sw/bin:${pkgs.socat}/bin:${pkgs.docker-client}/bin" \
      --setenv HOME "/home/agent" \
      --setenv TERM "xterm-256color" \
      --setenv LANG "''${LANG}" \
      --setenv USER "agent" \
      --setenv HISTFILE "/dev/null" \
      --setenv SAVEHIST "0" \
      --setenv GRADLE_RO_DEP_CACHE "/var/gradle/caches" \
      --setenv PNPM_HOME "/var/pnpm" \
      --setenv DOCKER_HOST "unix:///run/docker.sock" \
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

        export SSL_CERT_FILE=/run/mitm/mitmproxy-ca-cert.pem
        export CURL_CA_BUNDLE=/run/mitm/mitmproxy-ca-cert.pem
        export REQUESTS_CA_BUNDLE=/run/mitm/mitmproxy-ca-cert.pem
        export GIT_SSL_CAINFO=/run/mitm/mitmproxy-ca-cert.pem
        export NODE_EXTRA_CA_CERTS=/run/mitm/mitmproxy-ca-cert.pem
        export NIX_SSL_CERT_FILE=/run/mitm/mitmproxy-ca-cert.pem

        export JAVA_TRUSTSTORE=/run/mitm/java-truststore.jks
        export JAVA_TRUST_OPTS='-Djavax.net.ssl.trustStore=/run/mitm/java-truststore.jks -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStoreType=JKS'

        export JAVA_TOOL_OPTIONS=\"\$JAVA_TRUST_OPTS ''${JAVA_TOOL_OPTIONS:-}\"
        export GRADLE_OPTS=\"-Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=9998 -Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=9998 \$JAVA_TRUST_OPTS ''${GRADLE_OPTS:-}\"

        # create new files/dirs with group write access
        umask 007
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
