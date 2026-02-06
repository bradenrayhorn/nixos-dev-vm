{
  description = "Java 21 Environment";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

  outputs =
    { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.aarch64-linux;
    in
    {
      devShells.aarch64-linux.default = pkgs.mkShell {
        name = "java-21-env";
        packages = [
          pkgs.jdk21
        ];

        shellHook = ''
          export JAVA_HOME=${pkgs.jdk21}
        '';
      };
    };
}
