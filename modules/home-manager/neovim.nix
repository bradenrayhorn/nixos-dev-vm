{
  config,
  pkgs,
  ...
}:
let
  kotlin-lsp = pkgs.stdenv.mkDerivation rec {
    pname = "kotlin-lsp";
    version = "261.13587.0";

    src = pkgs.fetchzip {
      url = "https://download-cdn.jetbrains.com/kotlin-lsp/${version}/kotlin-lsp-${version}-linux-aarch64.zip";
      hash = "sha256-MhHEYHBctaDH9JVkN/guDCG1if9Bip1aP3n+JkvHCvA=";
      stripRoot = false;
    };

    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      pkgs.makeWrapper
    ];

    buildInputs = [
      pkgs.alsa-lib
      pkgs.freetype
      pkgs.libgcc.lib
      pkgs.libx11
      pkgs.libxi
      pkgs.libxrender
      pkgs.libxtst
      pkgs.wayland
      pkgs.zlib
    ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/lib/kotlin-lsp
      cp -r * $out/lib/kotlin-lsp
      chmod +x $out/lib/kotlin-lsp/jre/bin/java
      chmod +x $out/lib/kotlin-lsp/kotlin-lsp.sh
      ln -s $out/lib/kotlin-lsp/kotlin-lsp.sh $out/bin/kotlin-lsp

      runHook postInstall
    '';

    postInstall = ''
      substituteInPlace $out/lib/kotlin-lsp/kotlin-lsp.sh \
        --replace 'chmod +x "$LOCAL_JRE_PATH/bin/java"' '# chmod removed for NixOS'

      wrapProgram $out/bin/kotlin-lsp \
        --set JAVA_HOME "$out/lib/kotlin-lsp/jre"
    '';
  };
in
{
  xdg.configFile = {
    nvim = {
      source = config.lib.file.mkOutOfStoreSymlink "/var/gw/main/bradenrayhorn/nixos-dev-vm/nvim";
    };
  };

  programs.neovim = {
    enable = true;
    extraPackages = with pkgs; [
      kotlin-lsp

      tree-sitter
      eslint
      gopls
      nil
      svelte-language-server
      typescript
      nodejs_24
      vtsls
      typescript-language-server
      vscode-langservers-extracted

      # format
      nixfmt-rfc-style
      prettierd
      stylua
    ];
  };
}
