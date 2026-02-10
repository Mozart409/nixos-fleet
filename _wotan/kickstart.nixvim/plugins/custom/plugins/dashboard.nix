{
  programs.nixvim = {
    # Dashboard plugin - DISABLED in favor of snacks.dashboard
    # Using snacks.dashboard instead (configured in snacks.nix)
    # Having both enabled causes E141 errors on exit
    plugins.dashboard = {
      enable = false;
    };
  };
}
