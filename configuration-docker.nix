{
  modulesPath,
  lib,
  pkgs,
  ...
}:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  boot.kernelPackages = pkgs.linuxPackages;
  boot.supportedFilesystems.zfs = lib.mkForce false;

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

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  security.sudo.wheelNeedsPassword = false;

  users.groups.braden = { };
  users.groups.dockeragent = { };

  users.users.braden = {
    isNormalUser = true;
    home = "/home/braden";
    createHome = true;
    group = "braden";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMxUPJoiKdlvEq4+i4ZCl7lj1NOSgT7BsspqfgncdJKQVV5CKVZ1hnn/MNO4cAXRFOWjXkzowN+7mJZm8cVhP18="
    ];
  };

  users.users.dockeragent = {
    isNormalUser = true;
    home = "/home/dockeragent";
    createHome = true;
    group = "dockeragent";
    linger = true;
  };

  virtualisation.docker.enable = false;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  system.stateVersion = "25.11";
}
