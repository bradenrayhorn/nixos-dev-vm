{ ... }:
{
  environment.etc."tinyproxy/filter".text = ''
    api.openai.com
    auth.openai.com
    chatgpt.com
  '';

  services.tinyproxy = {
    enable = true;
    settings = {
      Port = 9999;
      Listen = "127.0.0.1";
      Timeout = 60;
      Allow = "127.0.0.1";

      FilterURLs = "On";
      FilterExtended = "On";
      FilterDefaultDeny = "Yes";

      Filter = "/etc/tinyproxy/filter";

      ConnectPort = [
        443
        80
      ];
    };
  };
}
