# surrealkit: SurrealDB schema sync, rollouts and typegen, used by the
# `engram-db-*` recipes (rust/surrealdb-engram). Not in nixpkgs.
{
  rustPlatform,
  fetchCrate,
}:
rustPlatform.buildRustPackage rec {
  pname = "surrealkit";
  version = "0.7.0";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-05TCIbtdcJB/HduBtMwZOYgO0D1Ktje+Gkk4lJGFbCE=";
  };

  cargoHash = "sha256-mtQbBmJLDsDr166WVqRsF/f1DmCTS+52lCfxNJplCDU=";

  # The test suite wants a running SurrealDB.
  doCheck = false;

  meta = {
    description = "Schema sync, rollouts and typegen for SurrealDB";
    homepage = "https://github.com/surrealdb/surrealkit";
    mainProgram = "surrealkit";
  };
}
