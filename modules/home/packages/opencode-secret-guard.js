// opencode plugin: hard guardrail against reading / leaking secrets.
//
// Deployed by modules/home/packages/opencode.nix to
// ~/.config/opencode/plugins/secret-guard.js.
//
// Why a plugin and not just `permission` rules in opencode.json:
// the bash tool only matches `permission.bash` globs against the parsed
// command and NEVER applies `permission.read` rules to file arguments, so
// `cat .env`, `sed -n p .env`, `printenv`, `agenix -d ...` all pass. This
// hook runs before every tool call and throws, which surfaces as a tool
// error to the model. A second hook scrubs secret-looking tokens out of
// tool output so a value that slips through some unforeseen path still
// never reaches the model context (or the provider).
//
// V2 plugin API: opencode v2 default-exports a definition with an `id` and a
// `setup(ctx)` function, and hooks are registered on the domain that owns the
// operation (`ctx.tool.hook(...)`). The V1 `tool.execute.before` /
// `tool.execute.after` string keys and the `(input, output)` callback split
// are gone: each hook now receives a single mutable event
// (`{ tool, sessionID, agent, messageID, id, input }`, plus `status`/`result`
// or `status`/`error` on execute.after). We deliberately export the plain
// definition object instead of `Plugin.define(...)`: the loader validates
// `{ id, setup }` directly (or `{ id, effect }`), and importing
// `@opencode/plugin` would need node_modules this Nix-deployed file does not
// have.
//
// No imports on purpose: plain ESM, loaded by opencode's own runtime.

const REDACTED = "[REDACTED by secret-guard]";

// Files whose *content* is a secret. Matched against any path-like string
// the built-in file tools / bash receive.
const SECRET_PATH = new RegExp(
  [
    // dotenv family: .env, .env.local, .env.production, prod.env, ...
    String.raw`(^|[\s"'=/:(])\.?[\w.-]*\.env(\.[\w.-]+)?(?=$|[\s"'/:;|&)>*?])`,
    String.raw`\.envrc(?=$|[\s"'/;|&)>])`,
    // private keys / key material
    String.raw`id_(rsa|dsa|ecdsa|ed25519|ed25519_sk|ecdsa_sk)(?!\.pub)`,
    String.raw`\.(pem|key|p12|pfx|jks|keystore|ppk)(?=$|[\s"'/;|&)>])`,
    String.raw`-----BEGIN[ A-Z]*PRIVATE KEY-----`,
    // credential stores in $HOME
    String.raw`(~|\$HOME|/home/[^/\s]+|/root)/\.(ssh|aws|gnupg|azure|kube|docker|password-store)(/|$)`,
    String.raw`(~|\$HOME|/home/[^/\s]+|/root)/\.(netrc|pgpass|git-credentials|npmrc|pypirc)`,
    String.raw`\.config/(gh/hosts\.yml|hcloud|doctl|op/|gcloud/|sops/age)`,
    String.raw`\.local/share/opencode/auth\.json`,
    String.raw`\.claude/\.credentials\.json`,
    // secret-shaped config files
    String.raw`(^|/)(credentials|secrets?|service[-_]?account[^/\s]*)\.(json|ya?ml|toml|ini|txt)(?=$|[\s"'/;|&)>])`,
    String.raw`\.tfstate(\.backup)?(?=$|[\s"'/;|&)>])`,
    String.raw`/proc/[^/\s]+/environ`,
  ].join("|"),
  "i",
);

// Allowed even though they match SECRET_PATH: templates never hold values.
// .sops.env / .sops.yaml: sops dotenv store -- keys visible, values ENC[...].
const SAFE_PATH = /\.env\.(example|sample|template|dist|schema)(?=$|[\s"'/;|&)>])|\.sops\.(env|ya?ml)(?=$|[\s"'/;|&)>])|\.pub(?=$|[\s"'/;|&)>])/i;

// Bash-only: commands whose *purpose* is to reveal secrets, regardless of
// which file they touch.
const SECRET_CMD = new RegExp(
  [
    String.raw`(^|[\s;|&(])printenv(\s|$)`,
    String.raw`(^|[\s;|&(])env\s*(\||;|&|>|$)`, // bare `env` dump (not `env FOO=x cmd`)
    String.raw`(^|[\s;|&(])(export|declare|typeset)\s+-p(\s|$)`,
    // also catches `nix run github:ryantm/agenix -- -d ...`
    String.raw`\b(agenix|age|sops)\b[^|;&]*\s(-d|--decrypt|exec-env|exec-file)(\s|$)`,
    // `sops <file>` is edit mode: `EDITOR=cat sops .sops.env` prints plaintext.
    // Only encrypt / key-management / info invocations are allowed.
    String.raw`(^|[\s;|&(])(\w+=\S*\s+)*sops(?![^|;&]*\s(-e|--encrypt|-i|--in-place|updatekeys|rotate|filestatus|--version|-h|--help)(\s|$))\s+[^|;&]*\S`,
    String.raw`(^|[\s;|&(])gpg2?\s+[^|;&]*(-d|--decrypt|--decrypt-files|--export-secret-(sub)?keys?)\b`,
    String.raw`(^|[\s;|&(])gpg-connect-agent\b|(^|[\s;|&(])gpg-preset-passphrase\b`,
    String.raw`(^|[\s;|&(])pass\s+(show|ls|find|grep)\b`,
    String.raw`(^|[\s;|&(])op\s+(read|item\s+get|document\s+get|inject|run)\b`,
    String.raw`(^|[\s;|&(])gh\s+auth\s+(token|status\s+--show-token)\b`,
    String.raw`(^|[\s;|&(])vault\s+(kv\s+get|read)\b`,
    String.raw`(^|[\s;|&(])aws\s+configure\s+(get|export-credentials)\b`,
    String.raw`(^|[\s;|&(])secret-tool\s+lookup\b`,
    String.raw`(^|[\s;|&(])(kubectl|oc)\s+get\s+secrets?\b.*(-o|--output)`,
    String.raw`(^|[\s;|&(])(docker|podman)\s+(inspect|secret\s+inspect)\b`,
    String.raw`(^|[\s;|&(])systemctl\s+(--user\s+)?show-environment\b`,
    String.raw`(^|[\s;|&(])(cat|less|more|strings|xxd|hexdump|od|base64|bat|head|tail)\s+[^|;&]*\bsecrets?/`,
  ].join("|"),
  "i",
);

// Values that look like credentials; scrubbed from every tool result.
const SECRET_VALUE = [
  /-----BEGIN[ A-Z]*PRIVATE KEY-----[\s\S]*?-----END[ A-Z]*PRIVATE KEY-----/g,
  /\bAGE-SECRET-KEY-1[AC-HJ-NP-Z02-9]{50,}\b/g,
  /\bsk-(ant-|proj-)?[A-Za-z0-9_-]{20,}\b/g, // OpenAI / Anthropic
  /\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}\b/g, // GitHub
  /\bgithub_pat_[A-Za-z0-9_]{60,}\b/g,
  /\bglpat-[A-Za-z0-9_-]{20,}\b/g, // GitLab
  /\bxox[abprs]-[A-Za-z0-9-]{10,}\b/g, // Slack
  /\bAKIA[0-9A-Z]{16}\b/g, // AWS access key id
  /\bAIza[0-9A-Za-z_-]{35}\b/g, // Google API key
  /\bhf_[A-Za-z0-9]{30,}\b/g, // HuggingFace
  /\bnpm_[A-Za-z0-9]{36}\b/g,
  /\bdop_v1_[a-f0-9]{64}\b/g, // DigitalOcean
  /\bpypi-AgEIcHlwaS5vcmc[A-Za-z0-9_-]{50,}\b/g,
  /\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b/g, // JWT
  // KEY=value / key: value with a secret-ish name and a non-trivial value
  /\b((?:[A-Z0-9_]*(?:SECRET|TOKEN|PASSWORD|PASSWD|API_?KEY|PRIVATE_?KEY|ACCESS_?KEY|AUTH|CREDENTIALS?)[A-Z0-9_]*)\s*[=:]\s*["']?)([^\s"'#][^\s"']{7,})/g,
  /\b((?:api[_-]?key|secret|token|password|passwd|client[_-]?secret|private[_-]?key)["']?\s*[=:]\s*["']?)([^\s"',;][^\s"',;]{7,})/gi,
];

// Built-in tools that take paths / patterns. MCP tools are skipped on
// purpose: a Loki/SQL query mentioning ".env" is not a file read.
const FILE_TOOLS = new Set(["read", "edit", "write", "patch", "multiedit", "glob", "grep", "list", "ls"]);

function strings(value, out = []) {
  if (typeof value === "string") out.push(value);
  else if (Array.isArray(value)) value.forEach((v) => strings(v, out));
  else if (value && typeof value === "object") Object.values(value).forEach((v) => strings(v, out));
  return out;
}

function isSecretPath(s) {
  return SECRET_PATH.test(s) && !SAFE_PATH.test(s);
}

function block(tool, what) {
  throw new Error(
    `secret-guard: blocked ${tool} — ${what}. ` +
      "Secrets (.env, private keys, credential stores, decrypt/reveal commands) are off-limits. " +
      "Do not retry with a different command; ask the user if you genuinely need this.",
  );
}

function redact(text) {
  if (typeof text !== "string" || text.length === 0) return { text, hits: 0 };
  let hits = 0;
  let out = text;
  for (const re of SECRET_VALUE) {
    out = out.replace(re, (m, ...groups) => {
      hits++;
      // Patterns with a capture group keep the key name, drop the value.
      const key = typeof groups[0] === "string" && typeof groups[1] === "string" ? groups[0] : null;
      return key ? `${key}${REDACTED}` : REDACTED;
    });
  }
  return { text: out, hits };
}

// Recursively scrub every string in a tool result value (result.output is a
// string; result.content is a string, a Tool.Content object, or an array of
// them). Returns the scrubbed value plus how many tokens were redacted.
function scrub(value) {
  if (typeof value === "string") {
    const {text, hits} = redact(value);
    return {value: text, hits};
  }
  if (Array.isArray(value)) {
    let hits = 0;
    const out = value.map((v) => {
      const r = scrub(v);
      hits += r.hits;
      return r.value;
    });
    return { value: out, hits };
  }
  if (value && typeof value === "object") {
    let hits = 0;
    const out = {...value};
    for (const k of Object.keys(out)) {
      const r = scrub(out[k]);
      hits += r.hits;
      out[k] = r.value;
    }
    return { value: out, hits };
  }
  return { value, hits: 0 };
}

function notice(hits) {
  return `\n\n[secret-guard: ${hits} secret-looking value(s) redacted from this output]`;
}

// Append the notice to whatever text field the result actually carries, so the
// model learns the output was scrubbed. Falls back to metadata when there is
// no string to extend.
function appendNotice(result, hits) {
  const text = notice(hits);
  if (typeof result.output === "string") {
    result.output += text;
    return;
  }
  if (typeof result.content === "string") {
    result.content += text;
    return;
  }
  if (result.content && !Array.isArray(result.content) && typeof result.content.text === "string") {
    result.content.text += text;
    return;
  }
  if (Array.isArray(result.content)) {
    const part = result.content.find((p) => p && typeof p === "object" && typeof p.text === "string");
    if (part) {
      part.text += text;
      return;
    }
  }
  result.metadata = {...(result.metadata || {}), secretGuard: text.trim()};
}

export default {
  id: "secret-guard",

  async setup(ctx) {
    await ctx.tool.hook("execute.before", (event) => {
      const tool = String(event.tool || "").toLowerCase();
      const args = event.input || {};

      if (tool === "bash") {
        const cmd = String(args.command || "");
        if (SECRET_CMD.test(cmd)) block(tool, "command reveals environment/secrets");
        if (isSecretPath(cmd)) block(tool, "command touches a secret file");
        return;
      }

      if (FILE_TOOLS.has(tool)) {
        for (const s of strings(args)) {
          if (isSecretPath(s)) block(tool, `secret path ${JSON.stringify(s)}`);
        }
      }
    });

    await ctx.tool.hook("execute.after", (event) => {
      if (event.status !== "completed" || !event.result) return;
      const result = event.result;

      let hits = 0;
      if (typeof result.output === "string") {
        const r = redact(result.output);
        result.output = r.text;
        hits += r.hits;
      }
      const scrubbed = scrub(result.content);
      result.content = scrubbed.value;
      hits += scrubbed.hits;

      if (hits > 0) appendNotice(result, hits);
    });
  },
};
