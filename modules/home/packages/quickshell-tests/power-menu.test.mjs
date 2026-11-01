// Checks quickshell/PowerActions.js -- the power menu's entries -- against the
// packages wotan actually runs. Run through Nix (default.nix), which provides:
//   POWER_ACTIONS  quickshell/PowerActions.js
//   THEME_QML      quickshell/Theme.qml
//   HYPR_STUBS     the pinned Hyprland's share/hypr/stubs/hl.meta.lua
//   PATH           with that Hyprland's hyprctl and systemd's loginctl/systemctl
//
//   just quickshell-test
import {test} from "node:test";
import assert from "node:assert/strict";
import {spawnSync} from "node:child_process";
import {accessSync, constants, readFileSync} from "node:fs";
import path from "node:path";
import vm from "node:vm";

const env = (name) => {
  const value = process.env[name];
  assert.ok(value, `${name} is not set; run this through default.nix`);
  return value;
};

// `.pragma library` is QML's, not JavaScript's; the rest is plain JS.
const loadActions = () => {
  const source = readFileSync(env("POWER_ACTIONS"), "utf8")
    .replace(/^\.pragma library\s*$/m, "");
  const context = vm.createContext({});
  vm.runInContext(source, context);
  // Out of the vm's realm, or deepStrictEqual sees a foreign Array prototype.
  return JSON.parse(JSON.stringify(context.actions));
};

const themeColours = () =>
  new Set(
    [...readFileSync(env("THEME_QML"), "utf8")
      .matchAll(/property color (\w+):/g)].map((m) => m[1]),
  );

// Dispatcher names per namespace class, read from the Lua stubs Hyprland
// ships: "HL.DspNamespace" -> {"exit", "exec_cmd", ...}.
const dispatchers = () => {
  const byClass = new Map();
  let current = null;
  for (const line of readFileSync(env("HYPR_STUBS"), "utf8").split("\n")) {
    const cls = line.match(/^---@class (\S+)/);
    if (cls) {
      current = new Set();
      byClass.set(cls[1], current);
      continue;
    }
    const field = line.match(/^---@field (\w+) fun\(/);
    if (field && current) current.add(field[1]);
  }
  return byClass;
};

// Hyprland 0.57's `hyprctl dispatch` evaluates its argument as Lua and expects
// a dispatcher: `hl.dsp.exit()`, `hl.dsp.window.close()`. Returns why `arg`
// is not one, or null.
const dispatchProblem = (arg, known) => {
  const m = arg.match(/^hl\.dsp\.(?:(\w+)\.)?(\w+)\((.*)\)$/s);
  if (!m) return `"${arg}" is not an hl.dsp.<name>(...) call`;
  const [, ns, name] = m;
  const cls = ns
    ? `HL.Dsp${ns[0].toUpperCase()}${ns.slice(1)}Namespace`
    : "HL.DspNamespace";
  if (!known.get(cls)?.has(name)) {
    return `hl.dsp.${ns ? `${ns}.` : ""}${name} is not a Hyprland dispatcher`;
  }
  return null;
};

const onPath = (bin) =>
  env("PATH").split(":").some((dir) => {
    try {
      accessSync(path.join(dir, bin), constants.X_OK);
      return true;
    } catch {
      return false;
    }
  });

const helpText = (bin) => {
  const r = spawnSync(bin, ["--help"], {
    encoding: "utf8",
    env: {...process.env, SYSTEMD_PAGER: "cat", PAGER: "cat"},
  });
  return `${r.stdout}${r.stderr}`;
};

test("lists the five session actions in order", () => {
  assert.deepEqual(
    loadActions().map((a) => a.label),
    ["Lock", "Suspend", "Log out", "Reboot", "Shut down"],
  );
});

test("every entry has an icon, a Theme colour and an argv", () => {
  const colours = themeColours();
  for (const a of loadActions()) {
    assert.ok(typeof a.icon === "string" && a.icon.length > 0, `${a.label}: icon`);
    assert.ok(colours.has(a.colour), `${a.label}: no Theme colour "${a.colour}"`);
    assert.ok(Array.isArray(a.exec) && a.exec.length >= 2, `${a.label}: exec`);
    for (const arg of a.exec) {
      assert.ok(typeof arg === "string" && arg.length > 0, `${a.label}: empty arg`);
    }
  }
});

test("every command is on PATH", () => {
  for (const a of loadActions()) {
    assert.ok(onPath(a.exec[0]), `${a.label}: ${a.exec[0]} not found`);
  }
});

test("every subcommand is one its tool documents", () => {
  for (const a of loadActions()) {
    const [bin, sub] = a.exec;
    const listed = new RegExp(`^\\s+${sub}\\b`, "m");
    assert.match(helpText(bin), listed, `${a.label}: ${bin} has no "${sub}"`);
  }
});

test("hyprctl dispatches are Lua dispatchers Hyprland knows", () => {
  const known = dispatchers();
  const hypr = loadActions().filter((a) => a.exec[0] === "hyprctl");
  assert.ok(hypr.length > 0, "no hyprctl action (Log out) to check");
  for (const a of hypr) {
    assert.equal(a.exec[1], "dispatch", `${a.label}: hyprctl ${a.exec[1]}`);
    assert.equal(a.exec.length, 3, `${a.label}: one Lua expression after dispatch`);
    assert.equal(dispatchProblem(a.exec[2], known), null);
  }
});

// The regression this suite was written for: the pre-Lua syntax must fail.
test("the dispatcher check rejects the pre-Lua syntax", () => {
  const known = dispatchers();
  assert.notEqual(dispatchProblem("exit", known), null);
  assert.notEqual(dispatchProblem("hl.dsp.logout()", known), null);
  assert.equal(dispatchProblem("hl.dsp.window.close()", known), null);
});
