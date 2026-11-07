# Local CA distrust, shared by base.nix (fleet, wotan, Pis, installer images)
# and the agent microVM guests (hosts/agents/zones.nix), which import neither.
#
# This goes beyond upstream nixpkgs, which deliberately keeps emSign Root CA - G1
# trusted. Decided on OYA-104 (Zero Wire, "eMudhra certificate compromise"):
# Mozilla only blocks the compromised intermediates through OneCRL, which
# curl, rustls and certifi never consult.
#
# Exit: once NSS drops G1, the bundle build fails with
# "Certs in blocklist but not in cert store". Remove this module, its imports
# and the row in infra/AGENTS.md "Temporary workarounds".
{...}: {
  security.pki.caCertificateBlacklist = ["emSign Root CA - G1"];
}
