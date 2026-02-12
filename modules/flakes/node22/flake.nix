{
  description = "Node 22 Environment";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

  outputs =
    { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.aarch64-linux;
    in
    {
      devShells.aarch64-linux.default = pkgs.mkShell {
        name = "node-22";
        packages = [
          pkgs.nodejs_22
          pkgs.pnpm
          pkgs.yarn
        ];
      };
    };
}
