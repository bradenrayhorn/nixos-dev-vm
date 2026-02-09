{
  ...
}:
{
  programs.git = {
    enable = true;
    settings.user.name = "Braden Rayhorn";
    settings.user.email = "25675893+bradenrayhorn@users.noreply.github.com";
    # agent never has write access to .git; this is a single-user system
    settings.safe.directory = "*";
    ignores = [
      ".envrc"
      ".direnv"
    ];
  };
}
