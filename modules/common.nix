# Every fleet host imports this: what all machines share (base.nix, also
# used by wotan) plus the server-only layer (server.nix). Kept as one entry
# point so the ~20 host configs do not each list both.
{...}: {
  imports = [
    ./base.nix
    ./server.nix
  ];
}
