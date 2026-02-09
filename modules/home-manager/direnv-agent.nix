{
  ...
}:
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    config = {
      whitelist = {
        prefix = [ "/" ];
      };
    };
  };
}
