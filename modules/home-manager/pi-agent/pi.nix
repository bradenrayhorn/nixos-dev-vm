{ pkgs, ... }:

let
  pi-coding-agent = pkgs.buildNpmPackage rec {
    pname = "pi-coding-agent";
    version = "0.52.9";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
      hash = "sha256-Cp8qNYA3UMJi0L9moQYvpPasJYXiFlC/AORMXlV7LlE=";
    };

    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-H5jMEuEKteOT0XDuapqix19JmBMCwORFc8zZ/At1RcA=";

    dontNpmBuild = true;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    postInstall = ''
      wrapProgram $out/bin/pi \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.fd ]}
    '';
  };
in
{
  home.packages = [
    pi-coding-agent
  ];
}
