# The memory protocol for coding agents: when to recall from and retain into
# the shared Hindsight bank (hosts/containers/hindsight), which agents reach
# through axon-gateway's hindsight_* tools. One text for every harness, so
# Claude Code and OpenCode, on wotan and in the agent zones, follow the same
# rules:
#
#   - Claude Code: `sessionStartHook`, a SessionStart hook that prints the
#     text plus the current project into the session's context.
#   - OpenCode: `instructions`, written as the global
#     ~/.config/opencode/AGENTS.md (OpenCode has no session hooks).
#
# No Stop hook on purpose. In an interactive session Stop fires after every
# reply, and in a Multica task the extra turn it forces would replace the
# run's final `result` message, which Multica posts as the task's answer
# (server/pkg/agent/claude.go). Retaining is the agent's call, prompted by the
# text below.
#
# `agent` is the tag that attributes a memory: everything reaches Hindsight
# under axon's one key, so the tag is the only record of who wrote it.
{
  pkgs,
  lib,
  agent,
}: let
  instructions = ''
    # Shared memory (Hindsight)

    You can use the shared homelab memory through the MCP tools
    `hindsight_recall`, `hindsight_retain`, `hindsight_reflect`,
    `hindsight_list_memories` and `hindsight_get_memory` (axon-gateway). Other
    agents read and write the same bank. If these tools are not available,
    ignore this section.

    - **Recall at the start.** Before substantial work, call `hindsight_recall`
      once. Name the project or repo, the service or host, and the topic in the
      query: memories are found by those names, and a vague question misses
      them.
    - **Treat memories as hints.** They can be stale or wrong. Check them
      against the code or the live system before relying on them.
    - **Retain what would otherwise be rediscovered.** When you learn something
      durable that another agent would need (a lesson from a failure, a
      non-obvious fix, a decision and why it was made, a gotcha in a service),
      call `hindsight_retain` once with a short, self-contained statement that
      names the project or service and the date. Tag it `agent:${agent}` and
      `project:<repo name>`. In a task run, do it before your final answer.
    - **Don't retain** secrets, credentials or tokens, personal data, anything
      already in the repo, its docs or its git history, progress reports or
      summaries of what you did, or guesses.
    - `hindsight_retain` is asynchronous. Don't wait for it or check it.
  '';

  # Prints the instructions and the current project; Claude Code adds a
  # SessionStart hook's stdout to the session's context. The project is the
  # git repo of the session's cwd, so recall and retain get the same name.
  sessionStartHook = pkgs.writeShellScript "hindsight-session-start" ''
    cwd=$(${lib.getExe pkgs.jq} -r '.cwd // empty')
    root=$(${lib.getExe pkgs.git} -C "''${cwd:-.}" rev-parse --show-toplevel 2>/dev/null || echo "''${cwd:-$PWD}")
    cat ${pkgs.writeText "hindsight-instructions.md" instructions}
    printf '\nCurrent project: %s (tag `project:%s`).\n' "''${root##*/}" "''${root##*/}"
  '';
in {
  inherit instructions;

  # For settings.json `hooks`. No matcher: startup, resume, /clear and
  # compaction all start a context that needs the text again.
  claudeHooks.SessionStart = [
    {
      hooks = [
        {
          type = "command";
          command = "${sessionStartHook}";
        }
      ];
    }
  ];
}
