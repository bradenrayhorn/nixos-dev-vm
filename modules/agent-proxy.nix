{ pkgs, config, ... }:
let
  allowedExactUrls = config.profiles.agentProxy.allowedExactUrls;

  mitmFilterScript = pkgs.writeText "agent-mitm-filter.py" ''
    from mitmproxy import http

    ALLOWED_HOSTS = {
        "api.openai.com",
        "auth.openai.com",
        "chatgpt.com",
    }

    ALLOWED_EXACT_URLS = ${builtins.toJSON allowedExactUrls}


    def _is_allowed_host(host: str) -> bool:
        return any(host == allowed or host.endswith("." + allowed) for allowed in ALLOWED_HOSTS)


    def request(flow: http.HTTPFlow) -> None:
        host = flow.request.pretty_host
        url_without_query = flow.request.pretty_url.split("?", 1)[0]

        if _is_allowed_host(host) or url_without_query in ALLOWED_EXACT_URLS:
            return

        flow.response = http.Response.make(
            403,
            b"Blocked by agent MITM proxy\\n",
            {"Content-Type": "text/plain"},
        )
  '';
in
{
  users.groups.agent-mitmproxy = { };
  users.users.agent-mitmproxy = {
    group = "agent-mitmproxy";
    isSystemUser = true;
    description = "Mitmproxy Service User";
  };

  systemd.services.agent-mitmproxy = {
    description = "Agent HTTPS MITM proxy with URL filtering";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      User = "agent-mitmproxy";
      Group = "agent-mitmproxy";
      DynamicUser = false;
      StateDirectory = "agent-mitmproxy";
      StateDirectoryMode = "0755";

      ExecStart = ''
        ${pkgs.mitmproxy}/bin/mitmdump \
          --listen-host 127.0.0.1 \
          --listen-port 9999 \
          --set confdir=/var/lib/agent-mitmproxy \
          --set block_global=false \
          --set termlog_verbosity=warn \
          --scripts ${mitmFilterScript}
      '';
      Restart = "always";
      RestartSec = "2s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      MemoryDenyWriteExecute = false;
      LockPersonality = true;
    };
  };
}
