{
  modulesPath,
  lib,
  pkgs,
  ...
}:
let
  dockerPrecachePolicy = pkgs.writeText "docker-precache-policy.json" ''
    {
      "default": [
        { "type": "reject" }
      ],
      "transports": {
        "docker": {
          "": [
            { "type": "insecureAcceptAnything" }
          ]
        }
      }
    }
  '';

  dockerPrecacheScript = pkgs.writeShellScript "docker-precache-images" ''
    set -euo pipefail

    SKOPEO="${pkgs.skopeo}/bin/skopeo"
    DOCKER="${pkgs.docker-client}/bin/docker"
    POLICY_FILE="/home/braden/.config/docker-precache/policy.json"
    CACHE_DIR="/var/dockercache"

    sudo mkdir -p $CACHE_DIR
    sudo chown braden:braden $CACHE_DIR
    sudo chmod 755 $CACHE_DIR

    DOCKERAGENT_UID="$(${pkgs.coreutils}/bin/id -u dockeragent)"
    DOCKERAGENT_RUNTIME="/run/user/$DOCKERAGENT_UID"
    DOCKER_SOCKET="''${DOCKER_SOCKET:-$DOCKERAGENT_RUNTIME/docker.sock}"

    if [[ ! -f "$POLICY_FILE" ]]; then
      echo "missing policy file: $POLICY_FILE" >&2
      exit 1
    fi

    mkdir -p "$CACHE_DIR"

    declare -a images=()

    if [[ "$#" -gt 0 ]]; then
      images=("$@")
    else
      echo "usage: docker-precache-images <image> [<image> ...]" >&2
      exit 1
    fi

    for image in "''${images[@]}"; do
      safe_name="$(echo "$image" | ${pkgs.coreutils}/bin/tr '/:@' '___')"
      archive="$CACHE_DIR/$safe_name.tar"
      echo "Caching $image -> $archive"
      "$SKOPEO" --policy "$POLICY_FILE" copy --retry-times 3 \
        "docker://$image" "docker-archive:$archive:$image"

      chmod 755 $archive

      echo "Loading $image into dockeragent daemon via $DOCKER_SOCKET"
      sudo -u dockeragent XDG_RUNTIME_DIR="$DOCKERAGENT_RUNTIME" \
        "$DOCKER" --host "unix://$DOCKER_SOCKET" load --input "$archive"

      rm -rf $archive
    done
  '';
in
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
      AllowUsers = [
        "braden"
        "dockeragent"
      ];
      AllowAgentForwarding = true;
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    allowedTCPPortRanges = [
      {
        from = 32768;
        to = 60999;
      }
    ];
    backend = "iptables";
    extraCommands = ''
      iptables -A OUTPUT -m owner --uid-owner dockeragent -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      ip6tables -A OUTPUT -m owner --uid-owner dockeragent -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

      iptables -A OUTPUT -m owner --uid-owner dockeragent -p tcp -j REJECT --reject-with tcp-reset
      ip6tables -A OUTPUT -m owner --uid-owner dockeragent -p tcp -j REJECT --reject-with tcp-reset
      iptables -A OUTPUT -m owner --uid-owner dockeragent -j REJECT --reject-with icmp-host-prohibited
      ip6tables -A OUTPUT -m owner --uid-owner dockeragent -j REJECT --reject-with icmp6-adm-prohibited
    '';
    extraStopCommands = ''
      iptables -D OUTPUT -m owner --uid-owner dockeragent -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
      ip6tables -D OUTPUT -m owner --uid-owner dockeragent -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

      iptables -D OUTPUT -m owner --uid-owner dockeragent -p tcp -j REJECT --reject-with tcp-reset 2>/dev/null || true
      ip6tables -D OUTPUT -m owner --uid-owner dockeragent -p tcp -j REJECT --reject-with tcp-reset 2>/dev/null || true
      iptables -D OUTPUT -m owner --uid-owner dockeragent -j REJECT --reject-with icmp-host-prohibited 2>/dev/null || true
      ip6tables -D OUTPUT -m owner --uid-owner dockeragent -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null || true
    '';
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
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMxUPJoiKdlvEq4+i4ZCl7lj1NOSgT7BsspqfgncdJKQVV5CKVZ1hnn/MNO4cAXRFOWjXkzowN+7mJZm8cVhP18="
    ];
  };

  system.activationScripts.installDockerPrecache = lib.stringAfter [ "users" ] ''
    install -d -m 0700 -o braden -g braden /home/braden/bin
    install -d -m 0700 -o braden -g braden /home/braden/.config/docker-precache
    install -d -m 0700 -o braden -g braden /home/braden/docker-image-cache

    install -m 0600 -o braden -g braden ${dockerPrecachePolicy} /home/braden/.config/docker-precache/policy.json
    install -m 0700 -o braden -g braden ${dockerPrecacheScript} /home/braden/bin/docker-precache-images
  '';

  virtualisation.docker.enable = false;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  system.stateVersion = "25.11";
}
