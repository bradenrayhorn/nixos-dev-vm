{
  description = "Java 17 Environment";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

  outputs =
    { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.aarch64-linux;
    in
    {
      devShells.aarch64-linux.default = pkgs.mkShell {
        name = "java-17-env";
        packages = [
          pkgs.jdk17
        ];

        shellHook = ''
          export JAVA_HOME=${pkgs.jdk17}
        '';
      };
    };
}
