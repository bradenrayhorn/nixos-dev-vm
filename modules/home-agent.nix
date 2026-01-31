{ pkgs, ... }:

{
  imports = [
    ./home-manager/git.nix
    ./home-manager/tmux.nix
    ./home-manager/zsh.nix
    ./home-manager/agent.nix
  ];

  home.username = "agent";
  home.homeDirectory = "/home/agent";

  home.packages = import ./common-packages.nix pkgs;

  home.stateVersion = "25.11";
}
