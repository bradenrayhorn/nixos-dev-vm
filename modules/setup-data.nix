{
  lib,
  ...
}:

let
  localDataDir = ./data;

  fileNames =
    let
      contents = builtins.readDir localDataDir;
    in
    lib.attrNames contents;

  mkDeployScript = name: ''
    echo "  - ${name}..."
    target="/var/nxdata/${name}"

    cp -r "${localDataDir}/${name}" "$target"
  '';

in
{
  systemd.tmpfiles.rules = [
    "d /var/nxdata 0755 root root -"
  ];

  system.activationScripts.deployCustomData = ''
    echo "Staging data..."

    ${lib.concatMapStringsSep "\n" mkDeployScript fileNames}

    echo "Done staging data."
  '';
}
