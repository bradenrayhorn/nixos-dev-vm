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
      # REPLACE THIS with the hash from the command above
      hash = "sha256-MhHEYHBctaDH9JVkN/guDCG1if9Bip1aP3n+JkvHCvA=";
      stripRoot = false;
    };

    # 2. Patching: NixOS cannot run downloaded binaries (like the bundled Java)
    # directly. autoPatchelfHook fixes the ELF interpreters.
    #    nativeBuildInputs = [
    #      pkgs.autoPatchelfHook
    #    ];

    installPhase = ''
      runHook preInstall

      # Copy all files to the nix store
      mkdir -p $out/share/kotlin-lsp
      cp -r . $out/share/kotlin-lsp

      # Create the bin directory
      mkdir -p $out/bin

      # Make the script executable
      chmod +x $out/share/kotlin-lsp/kotlin-lsp.sh

      # Symlink the binary to $out/bin so Neovim can find it
      ln -s $out/share/kotlin-lsp/kotlin-lsp.sh $out/bin/kotlin-lsp

      runHook postInstall
    '';
  };
in
{
  xdg.configFile = {
    nvim = {
      source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/nvim";
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
