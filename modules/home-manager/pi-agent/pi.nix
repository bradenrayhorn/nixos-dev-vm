{ pkgs, ... }:

let
  pi-coding-agent = pkgs.buildNpmPackage rec {
    pname = "pi-coding-agent";
    version = "0.51.2";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
      hash = "sha256-e5zpDgOKbz5ng+Ho2vudeyTdb87fa4UedLFs439+oqA=";
    };

    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-+kcyK3WQXRnU+Wm4TAZBxdSQD9UvI6xBVKQfBJXTVQw=";

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
