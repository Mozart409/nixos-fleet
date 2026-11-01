/**
 * `/exit` as an alias for pi's built-in `/quit`.
 *
 * pi has no command aliases (see docs/slash-commands.md: resources add
 * commands, they do not rename built-ins), so this extension registers `/exit`
 * and calls `ctx.shutdown()`.
 *
 * `ctx.shutdown()` is the same orderly shutdown the TUI performs for `/quit`
 * and Ctrl+D: it stops the TUI, emits `session_shutdown` to the extensions,
 * disposes the runtime, prints the "To resume this session" command and exits.
 * There is nothing extra to mirror.
 *
 * Loaded by `pi.nix` as `~/.pi/agent/extensions/exit.ts`. pi uses jiti, so the
 * file runs from source; the type-only import is erased.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.registerCommand("exit", {
		description: "Quit Pi (alias for /quit)",
		handler: async (_args, ctx) => {
			ctx.shutdown();
		},
	});
}
