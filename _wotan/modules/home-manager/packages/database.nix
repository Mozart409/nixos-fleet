{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    duckdb
    sqlite
    postgresql_18
    dbeaver-bin
  ];
}
