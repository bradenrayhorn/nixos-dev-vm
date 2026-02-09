{ pkgs, ... }:

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
  };

  home.packages = import ./common-packages.nix pkgs;

  home.stateVersion = "25.11";
}
