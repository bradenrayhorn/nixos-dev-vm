{
  config,
  pkgs,
  osConfig,
  lib,
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
      pkgs.jdk21
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

      # 1. Setup directories
      mkdir -p $out/lib/kotlin-lsp $out/bin
      cp -r * $out/lib/kotlin-lsp

      # 2. Symlink the Nix JDK to 'jre'
      #    We replace the bundled JRE with a link to the system JDK.
      rm -rf $out/lib/kotlin-lsp/jre
      ln -s ${pkgs.jdk21}/lib/openjdk $out/lib/kotlin-lsp/jre

      # 3. Patch the startup script
      #    Stop it from trying to 'chmod' the read-only java binary.
      substituteInPlace $out/lib/kotlin-lsp/kotlin-lsp.sh \
        --replace 'chmod +x' '# chmod +x'

      # 4. Make the startup script executable (Crucial Step!)
      chmod +x $out/lib/kotlin-lsp/kotlin-lsp.sh

      # 5. Create the wrapper
      #    We use makeWrapper to create a binary in $out/bin that calls the script in $out/lib.
      #    We also inject the PATH and JAVA_HOME here.
      makeWrapper $out/lib/kotlin-lsp/kotlin-lsp.sh $out/bin/kotlin-lsp \
        --set JAVA_HOME "${pkgs.jdk21}/lib/openjdk" \
        --prefix PATH : ${
          pkgs.lib.makeBinPath [
            pkgs.jdk17
            pkgs.jdk21
            pkgs.coreutils
            pkgs.bash
            pkgs.git
          ]
        }

      runHook postInstall
    '';
  };

  tree-sitter-cli = pkgs.stdenv.mkDerivation rec {
    pname = "tree-sitter-cli";
    version = "0.26.5";

    treeSitterPlatform = "linux-arm64";

    src = pkgs.fetchurl {
      url = "https://github.com/tree-sitter/tree-sitter/releases/download/v${version}/tree-sitter-${treeSitterPlatform}.gz";
      hash = "sha256-UZ6GSABKclo7tWa9s/MTSUbfTJ1/zaa+XPZ9I30rCSE=";
    };

    nativeBuildInputs = [
      pkgs.gzip
    ];

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack
      gunzip -c $src > tree-sitter
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 tree-sitter $out/bin/tree-sitter
      runHook postInstall
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
    extraPackages = [
      tree-sitter-cli

      pkgs.eslint
      pkgs.gopls
      pkgs.nil
      pkgs.svelte-language-server
      pkgs.typescript
      pkgs.nodejs_24
      pkgs.vtsls
      pkgs.typescript-language-server
      pkgs.vscode-langservers-extracted

      # format
      pkgs.nixfmt-rfc-style
      pkgs.prettierd
      pkgs.stylua
    ]
    ++ lib.optionals osConfig.profiles.kotlin.enable [
      kotlin-lsp
    ];
  };
}
