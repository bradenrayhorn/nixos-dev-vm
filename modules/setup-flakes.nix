{
  lib,
  ...
}:

let
  localFlakesDir = ./flakes;

  flakeNames =
    let
      contents = builtins.readDir localFlakesDir;
      isDir = name: type: type == "directory";
    in
    lib.attrNames (lib.filterAttrs isDir contents);

  mkDeployScript = name: ''
    echo "  - Deploying ${name}..."
    target="/var/flakes/${name}"

    rm -rf "$target"
    mkdir -p "$target"

    cp -r "${localFlakesDir}/${name}/." "$target/"

    # Make writable so flake.lock can be generated on first use
    chmod -R u+w "$target"
  '';

in
{
  systemd.tmpfiles.rules = [
    "d /var/flakes 0755 root root -"
  ];

  system.activationScripts.deployCustomFlakes = ''
    echo "Deploying development flakes to /var/flakes..."

    ${lib.concatMapStringsSep "\n" mkDeployScript flakeNames}

    echo "Done deploying flakes."
  '';
}
