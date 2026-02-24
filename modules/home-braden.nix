{
  pkgs,
  osConfig,
  lib,
  ...
}:
let
  dockerEnabled = osConfig.profiles.docker.enable;
  dockerSocketPath = "/home/braden/.docker/run/docker.sock";

  dockerTunnel = pkgs.writeShellScript "docker-host-tunnel" ''
    set -euo pipefail

    rm -f "${dockerSocketPath}"
    mkdir -p "$(dirname "${dockerSocketPath}")"

    REMOTE_DOCKER_UID="$(${pkgs.openssh}/bin/ssh -o BatchMode=yes docker_host id -u)"
    REMOTE_DOCKER_SOCKET="/run/user/$REMOTE_DOCKER_UID/docker.sock"

    exec ${pkgs.openssh}/bin/ssh -nNT \
      -o ExitOnForwardFailure=yes \
      -o StreamLocalBindUnlink=yes \
      -o ControlMaster=no \
      -o ControlPersist=no \
      -o ControlPath=none \
      -L "${dockerSocketPath}:$REMOTE_DOCKER_SOCKET" \
      docker_host
  '';

  dockerPrecacheImages = pkgs.writeShellScriptBin "docker-precache-images" ''
    set -euo pipefail
    exec ${pkgs.openssh}/bin/ssh braden@docker_host_admin /home/braden/bin/docker-precache-images "$@"
  '';
in
{
  imports = [
    ./home-manager/git.nix
    ./home-manager/neovim.nix
    ./home-manager/tmux.nix
    ./home-manager/zsh.nix
    ./home-manager/direnv.nix
    ./home-manager/agent-dispatch.nix
  ];

  home.username = "braden";
  home.homeDirectory = "/home/braden";

  home.sessionVariables = {
    GRADLE_USER_HOME = "/var/gradle";
    PNPM_HOME = "/var/pnpm";
  }
  // lib.optionalAttrs dockerEnabled {
    DOCKER_HOST = "unix://${dockerSocketPath}";
    TESTCONTAINERS_HOST_OVERRIDE = "192.168.64.12";
  };

  # connection to remote docker - only when enabled
  programs.ssh = lib.optionalAttrs dockerEnabled {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks.docker_host = {
      hostname = "192.168.64.12";
      port = 22;
      user = "dockeragent";
      controlMaster = "auto";
      controlPath = "~/.ssh/controlmasters/%C";
      controlPersist = "30m";
    };
    matchBlocks.docker_host_admin = {
      hostname = "192.168.64.12";
      port = 22;
      user = "braden";
    };
  };

  home.activation.createSshControlMasterDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.ssh/controlmasters"
    chmod 700 "$HOME/.ssh/controlmasters"
  '';

  systemd.user.services = lib.optionalAttrs dockerEnabled {
    docker-host-tunnel = {
      Unit = {
        Description = "SSH tunnel for remote docker socket";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        ExecStart = "${dockerTunnel}";
        PassEnvironment = [ "SSH_AUTH_SOCK" ];
        Restart = "always";
        RestartSec = 2;

        Environment = "PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.openssh
          ]
        }";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };

  home.file = lib.optionalAttrs osConfig.profiles.kotlin.enable {
    "jdks/jdk17".source = "${pkgs.jdk17}/lib/openjdk";
    "jdks/jdk21".source = "${pkgs.jdk21}/lib/openjdk";
  };

  home.packages = (import ./common-packages.nix pkgs) ++ [
    pkgs.docker-client
    dockerPrecacheImages
  ];

  home.stateVersion = "25.11";
}
