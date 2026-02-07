{
  lib,
  config,
  ...
}:
with lib;
let
  cfgKotlin = config.profiles.kotlin;
in
{
  options.profiles.kotlin = {
    enable = mkEnableOption "Kotlin development support";
  };

  config = mkIf cfgKotlin.enable {
    environment.variables.NX_KOTLIN_LSP_ENABLED = "1";
  };
}
