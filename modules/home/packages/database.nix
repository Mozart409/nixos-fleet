{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # keep-sorted start
    duckdb
    postgresql_18
    sqlite
    # keep-sorted end
  ];
}
