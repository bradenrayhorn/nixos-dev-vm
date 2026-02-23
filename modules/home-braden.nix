{
  pkgs,
  osConfig,
  lib,
  ...
}:

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
    DOCKER_HOST = "ssh://docker_host";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks.docker_host = {
      hostname = "10.0.2.2";
      port = 5223;
      user = "dockeragent";
      controlMaster = "auto";
      controlPath = "~/.ssh/controlmasters/%C";
      controlPersist = "30m";
    };
  };

  home.activation.createSshControlMasterDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.ssh/controlmasters"
    chmod 700 "$HOME/.ssh/controlmasters"
  '';

  home.file = lib.optionalAttrs osConfig.profiles.kotlin.enable {
    "jdks/jdk17".source = "${pkgs.jdk17}/lib/openjdk";
    "jdks/jdk21".source = "${pkgs.jdk21}/lib/openjdk";
  };

  home.packages = (import ./common-packages.nix pkgs) ++ [
    pkgs.docker-client
  ];

  home.stateVersion = "25.11";
}
