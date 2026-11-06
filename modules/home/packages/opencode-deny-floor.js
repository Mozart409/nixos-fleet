// opencode plugin: the shell half of Claude's deny list, as a floor a
// project's opencode.json cannot loosen.
//
// Deployed by modules/home/packages/opencode.nix to
// ~/.config/opencode/plugins/deny-floor.js. Nix prepends
// `const DENY = [...]` (the `Bash(...)` rules of agent-permissions.nix's
// `deny`, as opencode globs), so DENY is not declared here.
//
// Why a plugin: the permission rules in the global opencode.json are
// overridable, because a project's .opencode/opencode.json loads after it.
// Claude's denies cannot be overridden by a project, and neither can this.
//
// It matches command text, so it is a guardrail and not a boundary: `bash -c
// '...'` is not unpacked (same as Claude's rules), and variables or encodings
// walk around it. The boundary is the agent account plus the unit sandbox.
//
// No imports on purpose: plain ESM, loaded by opencode's own runtime.

// Same matcher as opencode's: `*` crosses `/`, `?` is any char, a trailing
// ` *` also matches no args, anchored over the whole string.
function glob(pattern) {
  const re = pattern
    .replace(/[.+^${}()|[\]\\]/g, "\\$&")
    .replace(/\*/g, ".*")
    .replace(/\?/g, ".")
    .replace(/ \.\*$/, "( .*)?");
  return new RegExp(`^${re}$`, "s");
}

const RULES = DENY.map((pattern) => ({ pattern, re: glob(pattern) }));

// Split a command line into simple commands. `;` `&` `|` newline `(` `)` end
// one outside quotes; single quotes are opaque; inside double quotes `$(` and
// backtick still start a new command, because they execute.
function commands(cmd) {
  const out = [];
  let cur = "";
  let quote = null;
  const cut = () => {
    out.push(cur);
    cur = "";
  };
  for (let i = 0; i < cmd.length; i++) {
    const c = cmd[i];
    if (quote === "'") {
      cur += c;
      if (c === "'") quote = null;
      continue;
    }
    if (c === "\\") {
      cur += c + (cmd[i + 1] ?? "");
      i++;
      continue;
    }
    if (quote === '"') {
      if (c === '"') {
        quote = null;
        cur += c;
      } else if (c === "`" || (c === "$" && cmd[i + 1] === "(")) {
        cut();
        if (c === "$") i++;
      } else {
        cur += c;
      }
      continue;
    }
    if (c === "'" || c === '"') {
      quote = c;
      cur += c;
    } else if (";&|\n()".includes(c)) {
      cut();
    } else {
      cur += c;
    }
  }
  cut();
  return out;
}

// Drop what only wraps the real command: leading blanks, VAR=value
// assignments, env/command/exec, and `nix develop [args] -c`.
const WRAPPER = /^(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+|(?:env|command|exec)\s+|nix\s+develop(?:\s+\S+)*?\s+(?:-c|--command)\s+)/;

function strip(piece) {
  let s = piece.trimStart();
  for (;;) {
    const next = s.replace(WRAPPER, "").trimStart();
    if (next === s) return s;
    s = next;
  }
}

function check(text) {
  for (const { pattern, re } of RULES) {
    if (re.test(text)) {
      throw new Error(
        `deny-floor: blocked shell, "${pattern}" is denied. ` +
          "Do not retry with a different command; ask the user to run it if it is really needed.",
      );
    }
  }
}

export default {
  id: "deny-floor",

  async setup(ctx) {
    await ctx.tool.hook("execute.before", (event) => {
      const tool = String(event.tool || "").toLowerCase();
      if (tool !== "bash" && tool !== "shell") return;

      const args = event.input || {};
      const cmd = String(args.command ?? args.cmd ?? "");

      for (const piece of commands(cmd)) check(strip(piece).trimEnd());
      check(cmd.trim());
    });
  },
};
