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
  };

  home.file = lib.optionalAttrs osConfig.profiles.kotlin.enable {
    "jdks/jdk17".source = "${pkgs.jdk17}/lib/openjdk";
    "jdks/jdk21".source = "${pkgs.jdk21}/lib/openjdk";
  };

  home.packages = import ./common-packages.nix pkgs;

  home.stateVersion = "25.11";
}
