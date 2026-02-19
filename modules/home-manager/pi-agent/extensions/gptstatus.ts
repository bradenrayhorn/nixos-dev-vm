import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function gptStatusExtension(pi: ExtensionAPI) {
  pi.registerCommand("gptstatus", {
    description: "Show ChatGPT primary/secondary rate-limit usage windows",
    handler: async (_args, ctx) => {
      const script = `
AUTH_FILE="$HOME/.pi/agent/auth.json"

TOKEN=$(jq -r '."openai-codex".access' "$AUTH_FILE")
ACCOUNT_ID=$(jq -r '."openai-codex".accountId' "$AUTH_FILE")

curl -fsS 'https://chatgpt.com/backend-api/wham/usage' \
  -H "Authorization: Bearer $TOKEN" \
  -H "chatgpt-account-id: $ACCOUNT_ID" \
| jq -r '
  def window_fmt($seconds):
    if $seconds == null then
      "n/a"
    elif $seconds >= 86400 then
      "\\(($seconds / 86400) | if . == floor then tostring else (.*10|round/10|tostring) end) day" + (if ($seconds / 86400) == 1 then "" else "s" end)
    else
      "\\(($seconds / 3600) | if . == floor then tostring else (.*10|round/10|tostring) end) hour" + (if ($seconds / 3600) == 1 then "" else "s" end)
    end;

  def fmt($name; $w):
    if $w == null then
      "  \\($name): n/a"
    else
      "  \\($name): used=\\($w.used_percent)% | window=\\(window_fmt($w.limit_window_seconds)) | resets at \\($w.reset_at | strflocaltime(\"%Y-%m-%d %H:%M:%S %Z\"))"
    end;

  [
    "ChatGPT Rate Limits",
    "",
    "General:",
    fmt("primary"; .rate_limit.primary_window),
    fmt("secondary"; .rate_limit.secondary_window)
  ]
  | join("\\n")
'
`;

      const result = await pi.exec("bash", ["-lc", script], { timeout: 30000 });
      if (result.code !== 0) {
        const errorMessage = `gptstatus failed: ${result.stderr || "unknown error"}`;
        if (ctx.hasUI) {
          ctx.ui.notify(errorMessage, "error");
        }
        return;
      }

      const output = (result.stdout || "").trim() || "No usage output returned.";
      if (ctx.hasUI) {
        ctx.ui.notify(output, "info");
      }
    },
  });
}
