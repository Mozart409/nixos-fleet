{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
# Multica CLI + daemon (the per-zone agent runtime). The server and web UI
# run as pinned OCI images (infra/modules/multica-server.nix), so only
# cmd/multica is built here; cmd/server + cmd/migrate stay upstream-packaged
# until a native backend is worth it.
#
# Upstream pins Go 1.26.6 in server/go.mod; nixpkgs' default `go` (1.26.8)
# satisfies that. Bump `version` deliberately -- Multica releases near-daily
# and the backend runs DB migrations on every start (dump the database
# before bumping the server image tag too).
buildGoModule {
  pname = "multica";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "multica-ai";
    repo = "multica";
    rev = "v0.6.1";
    hash = "sha256-I8aD9pyeTuuU2EPn2IwKomWmeAjHxdT0HmEwvo4hVSc=";
  };

  # The Go module is github.com/multica-ai/multica/server; apps/web is a
  # pnpm/Next.js monorepo this package does not touch.
  modRoot = "server";

  subPackages = ["cmd/multica"];

  env.CGO_ENABLED = 0;

  vendorHash = "sha256-b6elV4j+7R6L29q8tbCI3MAOY8X63ndzlmCMv7jo7mM=";

  # Same stamping as upstream's goreleaser builds.
  ldflags = [
    "-s"
    "-w"
    "-X main.version=0.6.1"
    "-X main.commit=2ea01ae"
    "-X main.date=2026-10-04"
  ];

  # The server tests want a Postgres; nothing here exercises them.
  doCheck = false;

  meta = {
    description = "Multica CLI and daemon (agent runtime)";
    homepage = "https://github.com/multica-ai/multica";
    # Apache-2.0 + additional conditions (no hosted service for third
    # parties, branding preserved). Personal self-hosting is fine.
    license = lib.licenses.unfree;
    mainProgram = "multica";
    platforms = ["x86_64-linux" "aarch64-linux"];
  };
}
