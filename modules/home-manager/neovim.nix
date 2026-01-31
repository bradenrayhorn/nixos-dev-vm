{
  config,
  pkgs,
  ...
}:
{
  xdg.configFile = {
    nvim = {
      source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/nvim";
    };
  };
  programs.neovim = {
    enable = true;
    extraPackages = with pkgs; [
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
