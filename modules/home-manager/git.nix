{
  ...
}:
{
  programs.git = {
    enable = true;
    settings.user.name = "Braden Rayhorn";
    settings.user.email = "25675893+bradenrayhorn@users.noreply.github.com";
    settings.safe.directory = "/etc/nixos";
    ignores = [
      ".envrc"
    ];
  };
}
