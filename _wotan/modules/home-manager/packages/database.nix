{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # keep-sorted start
    dbeaver-bin
    duckdb
    postgresql_18
    sqlite
    # keep-sorted end
  ];
}
