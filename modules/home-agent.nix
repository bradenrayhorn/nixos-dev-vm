{ pkgs, ... }:

{
  imports = [
    ./home-manager/git.nix
    ./home-manager/tmux-agent.nix
    ./home-manager/zsh.nix
    ./home-manager/direnv-agent.nix
    ./home-manager/pi-agent/pi.nix
  ];

  home.username = "agent";
  home.homeDirectory = "/home/agent";

  home.file.".pi/agent/extensions" = {
    source = ./home-manager/pi-agent/extensions;
    recursive = true;
  };

  home.packages = import ./common-packages.nix pkgs;

  home.stateVersion = "25.11";
}
