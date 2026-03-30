{ pkgs, ... }:

let
  pi-coding-agent = pkgs.buildNpmPackage rec {
    pname = "pi-coding-agent";
    version = "0.64.0";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
      hash = "sha256-SSdIyhoK9DEa0qFNK3dAsTPcOhvhJQ/w7klVCB2kqZo=";
    };

    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-FTaTT7ssdAbbeMYKXAxbuWzwjRm2atttCCl4l+G63aU=";

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
