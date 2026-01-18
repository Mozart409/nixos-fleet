{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    duckdb
    sqlite
    postgresql_16
    dbeaver-bin
  ];
}
