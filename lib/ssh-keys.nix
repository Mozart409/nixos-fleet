# Public keys allowed to log in as amadeus. Shared by modules/server.nix (the
# fleet) and modules/pi/base.nix (the Pis) so the lists cannot drift apart.
[
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMPJIxb+FNkiFtPB/9eUenHa1RCWLBI0ia7KN/nFIdGH iPhone"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH/HCRJuzlIbgcWk68ehApZl6kN+7PnKIgYSLRZ5IjzQ amadeus@Amadeuss-MacBook-Pro.local"
  # Colmena deploys launched from the `development` host. Its private half
  # is passphrase-protected and pinned with `IdentityAgent none` (see
  # hosts/development/configuration.nix), so the unattended agent sessions
  # running as amadeus on that host cannot use it without a human typing
  # the passphrase. Do not add an agent-forwarded or unencrypted copy of
  # this key anywhere — that silently removes the only real gate.
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGVzXv+1p2UmSUDBtTw5sSFnz7sY3q86Vb/8GVhKKxo4 amadeus@development-colmena"
]
