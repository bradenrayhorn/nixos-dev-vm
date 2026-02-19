import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function reviewExtension(pi: ExtensionAPI) {
  pi.registerCommand("review", {
    description: "Review of current uncommitted changes",
    handler: async (args, ctx) => {
      await ctx.waitForIdle();

      const status = await pi.exec("git", ["status", "--porcelain"]);
      if (status.code !== 0) {
        if (ctx.hasUI) {
          ctx.ui.notify(`git status failed: ${status.stderr || "unknown error"}`, "error");
        }
        return;
      }

      if (!status.stdout.trim()) {
        if (ctx.hasUI) {
          ctx.ui.notify("No uncommitted changes found.", "info");
        }
        return;
      }

      const providedGoal = (args || "").trim();
      let originalGoal = providedGoal;

      if (!originalGoal && ctx.hasUI) {
        originalGoal =
          (await ctx.ui.input(
            "Original goal (short context)",
            "What was this change trying to accomplish?",
          ))?.trim() ?? "";
      }

      const goalContext = originalGoal
        ? `Original goal of this change: ${originalGoal}`
        : "Original goal of this change: (not provided)";

      const reviewPrompt = `
Act as a code reviewer for changes made by another engineer.

Focus on code that is uncommitted in git. Only flag issues introduced by code currently uncommitted.

${goalContext}

Evaluate findings in light of the original goal. If tradeoffs were made to satisfy that goal, account for them and avoid flagging clearly intentional decisions unless they create a concrete issue.

Before finalizing feedback, consider repository-specific context:
- Read and use relevant repo docs (including AGENTS.md and other project docs when present).
- Check README guidance relevant to the changed area.
- Prefer existing patterns and conventions in this codebase over generic advice.

Below are some guidelines for what to watch for. These are just guidelines, apply judgement to what might need to be pointed out or is irrelevant.
- If there are no relevant issues, don't manufacture issues, just explicitly say the change looks good.
- Call out new dependencies added
- Don't flag issues that are clearly intentional by the engineer
- Don't speculate a change may impact another part of the code, verify.
- In tests, flag excessive mocking to the point where nothing is being tested. Prefer integration tests if possible and consistent with the pattern of the codebase.
- Avoid flattery like "Great job..." - only call out issues.

Provide findings in a clear and structured format so that another engineer can work through them:
- Each finding should include a file, location within the file, and explanation.
- Keep findings concise.
- Don't generate a full fix, just note the issue and short suggestions.
      `;

      if (ctx.hasUI) {
        ctx.ui.notify("Running review in background...", "info");
      }

      const result = await pi.exec("pi", ["-p", reviewPrompt], { timeout: 600000 });
      if (result.code !== 0) {
        if (ctx.hasUI) {
          const timedOut = result.killed ? " (timed out after 10m)" : "";
          ctx.ui.notify(`Review failed${timedOut}: ${result.stderr || "unknown error"}`, "error");
        }
        return;
      }

      const reviewText = (result.stdout || "").trim() || "(No review output)";
      pi.sendMessage({
        customType: "review",
        content: reviewText,
        display: true,
        details: { source: "spawned-pi", originalGoal: originalGoal || undefined },
      });

      const followUpInstructions = ctx.hasUI
        ? (
            await ctx.ui.input(
              "Review complete",
              "Optional: add follow-up instructions (e.g., ignore X, fix Y). Leave blank to skip.",
            )
          )?.trim() ?? ""
        : "";

      if (followUpInstructions) {
        const followUpMessage = `Please handle this review feedback with the following instructions.
Review feedback:
${reviewText}

Instructions:
${followUpInstructions}`;

        pi.sendUserMessage(followUpMessage);
        if (ctx.hasUI) {
          ctx.ui.notify("Queued follow-up with your instructions.", "info");
        }
      } else if (ctx.hasUI) {
        ctx.ui.notify("Review complete. No follow-up queued.", "info");
      }
    },
  });
}
