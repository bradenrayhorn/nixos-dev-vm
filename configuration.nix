{
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./modules/flakes-setup.nix
    ./profiles.nix
  ]
  ++ lib.optional (builtins.pathExists ./local.nix) ./local.nix;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  programs.nix-ld.enable = true;

  # ssh
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;

      AllowUsers = [ "braden" ];
      AllowAgentForwarding = true;
    };
  };

  security = {
    sudo.wheelNeedsPassword = false;
  };

  # hardware
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "virtio_pci"
    "usbhid"
    "usb_storage"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    { device = "/dev/disk/by-label/swap"; }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # boot
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # pkgs
  environment.systemPackages = with pkgs; [
    vim
    ghostty
    (pkgs.writeShellScriptBin "nx-rebuild" ''
      set -e
      if [ "$(id -u)" -ne 0 ]; then
        echo >&2 "error: script must be run with sudo"
        exit 1
      fi

      nixos-rebuild switch --flake /var/gw/main/bradenrayhorn/nixos-dev-vm#default
    '')
    (pkgs.writeShellScriptBin "nx-init" ''
      set -e
      if [ "$(id -u)" -eq 0 ]; then
        echo >&2 "error: do not run script with sudo"
        exit 1
      fi

      shopt -s nullglob dotglob
      sudo rm -rf /etc/nixos/*

      mkdir -p /var/git/bradenrayhorn
      mkdir -p /var/gw/main/bradenrayhorn
      echo "(cd /var/git/bradenrayhorn && git clone --bare git@github.com:bradenrayhorn/nixos-dev-vm.git)"
      echo "(cd /var/git/bradenrayhorn/nixos-dev-vm.git && git worktree add /var/gw/main/bradenrayhorn/nixos-dev-vm main)"
      echo "nx-rebuild"
    '')
  ];

  # allowed unfree packages
  nixpkgs.config.allowUnfree = true;

  # Set the default editor to vim and shell to zsh
  environment.variables.EDITOR = "vim";
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # time
  time.timeZone = "America/Chicago";

  # gc
  boot.loader.systemd-boot.configurationLimit = 6;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # user setup
  users.groups.braden = { };
  users.groups.agent = { };
  users.groups.dev = { };

  users.users.braden = {
    isNormalUser = true;
    home = "/home/braden";
    createHome = true;
    group = "braden";
    extraGroups = [
      "agent"
      "dev"
      "wheel"
    ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMxUPJoiKdlvEq4+i4ZCl7lj1NOSgT7BsspqfgncdJKQVV5CKVZ1hnn/MNO4cAXRFOWjXkzowN+7mJZm8cVhP18="
    ];
  };
  users.users.agent = {
    isNormalUser = true;
    home = "/home/agent";
    createHome = true;
    group = "agent";
    extraGroups = [ "dev" ];
    homeMode = "770";
  };

  # working directories
  systemd.tmpfiles.rules = [
    "d /var/git 2770 braden dev -"
    "d /var/gw  2770 braden dev -"

    "d /var/gradle  2770 braden dev -"
  ];

  # docker
  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  system.stateVersion = "25.11";
}
