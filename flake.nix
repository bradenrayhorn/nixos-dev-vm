{
  description = "A basic NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "aarch64-linux";
    in
    {
      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self; };
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.braden = import ./modules/home-braden.nix;
            home-manager.users.agent = import ./modules/home-agent.nix;
          }
        ];
      };

      packages.${system}.iso = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self; };
        modules = [
          (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
          (
            { pkgs, modulesPath, ... }:
            {
              boot.kernelPackages = pkgs.linuxPackages;

              # incompatible with linuxPackages_latest and not needed
              boot.supportedFilesystems.zfs = nixpkgs.lib.mkForce false;

              imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
              isoImage.squashfsCompression = "zstd -Xcompression-level 19";

              # copy nixos config into iso
              environment.etc."nixos-config".source = self;

              # copy script to format drives
              environment.systemPackages = [
                (pkgs.writeShellScriptBin "install-system" ''
                  set -e

                  DISK=''${1:-/dev/vda}
                  SWAP_SIZE="4096"

                  echo "Partitioning $DISK..."
                  ${pkgs.parted}/bin/parted $DISK -- mklabel gpt

                  # Partition 1: Boot (ESP) - 512MB
                  ${pkgs.parted}/bin/parted $DISK -- mkpart ESP fat32 1MB 512MB
                  ${pkgs.parted}/bin/parted $DISK -- set 1 esp on

                  # Partition 2: Swap - 4GB
                  # Start at 512MB, end at 512MB + SWAP_SIZE
                  ${pkgs.parted}/bin/parted $DISK -- mkpart primary linux-swap 512MB "$((512 + SWAP_SIZE))MB"

                  # Partition 3: Root (ext4) - Rest of the disk
                  ${pkgs.parted}/bin/parted $DISK -- mkpart primary ext4 "$((512 + SWAP_SIZE))MB" 100%

                  echo "Formatting partitions..."
                  ${pkgs.dosfstools}/bin/mkfs.fat -F 32 -n BOOT ''${DISK}1
                  ${pkgs.util-linux}/bin/mkswap -L swap ''${DISK}2
                  ${pkgs.e2fsprogs}/bin/mkfs.ext4 -L nixos ''${DISK}3

                  echo "Mounting file systems..."
                  mount /dev/disk/by-label/nixos /mnt
                  mkdir -p /mnt/boot
                  mount /dev/disk/by-label/BOOT /mnt/boot
                  swapon /dev/disk/by-label/swap

                  echo "Copying configuration..."
                  mkdir -p /mnt/etc/nixos
                  cp -r /etc/nixos-config/* /mnt/etc/nixos/
                  chmod -R 775 /mnt/etc/nixos
                  chown -R root:wheel /mnt/etc/nixos

                  echo "Installing NixOS..."
                  nixos-install --flake /mnt/etc/nixos#default

                  echo "Installation complete. Please shutdown and disconnect the ISO."
                '')
              ];
            }
          )
        ];
      };
    };
}
