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
  options.profiles = {
    kotlin.enable = mkEnableOption "Kotlin development support";

    docker.enable = mkEnableOption "Connection to remote docker VM";

    agentProxy.allowedExactUrls = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [
        "https://example.com/myfile.txt"
      ];
      description = "Exact request URLs allowed through the agent MITM proxy.";
    };
  };

  config = mkIf cfgKotlin.enable {
    environment.variables.NX_KOTLIN_LSP_ENABLED = "1";
  };
}
