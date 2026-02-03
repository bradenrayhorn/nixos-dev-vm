{
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

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
      "fmask=0022"
      "dmask=0022"
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
    (pkgs.writeShellScriptBin "rebuild-system" ''
      set -e
      nixos-rebuild switch --flake /etc/nixos#default
    '')
  ];

  # allowed unfree packages
  nixpkgs.config.allowUnfree = true;

  # Set the default editor to vim and shell to zsh
  environment.variables.EDITOR = "vim";
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

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

  users.users.braden = {
    isNormalUser = true;
    home = "/home/braden";
    createHome = true;
    group = "braden";
    extraGroups = [
      "agent"
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
    homeMode = "770";
  };

  system.stateVersion = "25.11";
}
