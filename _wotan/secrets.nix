let
  # User SSH keys for encryption/decryption
  amadeus-wotan = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan";

  # System SSH host keys for decryption
  wotan-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIB+ZFy9VtNhNzlpUg0tNqMPZFj3kCt50wvXD7aw88MZ root@wotan";

  # Define which keys can access which secrets
  allUsers = [amadeus-wotan];
  allKeys = [amadeus-wotan wotan-host];
in {
  # CONTEXT7 API key for OpenCode MCP server
  "secrets/context7-api-key.age".publicKeys = allKeys;

  # HuggingFace read-only token for vLLM (gated models like Llama-3.1).
  # Content must be a systemd EnvironmentFile line:
  #   HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  # Edit with: agenix -e secrets/hf-token.age
  "secrets/hf-token.age".publicKeys = allKeys;
  # Format AXON_GATEWAY_TOKEN=ABC123
  "secrets/axon-gateway-env.age".publicKeys = allKeys;
  # Basic-auth password for opencode-serve (server EnvironmentFile + clients).
  # Format OPENCODE_SERVER_PASSWORD=xxxx
  # Edit with: agenix -e secrets/opencode-server-password.age
  "secrets/opencode-server-password.age".publicKeys = allKeys;
  # Nebula host private keys for wotan, one per tenant overlay (raw
  # nebula-cert PEM, as written by `nebula-cert sign -out-key`). The matching
  # public certs live in hosts/wotan/nebula/. See todo/nebula-clients.md.
  "secrets/nebula-amartum-wotan.age".publicKeys = allKeys;
  "secrets/nebula-mozart409-wotan.age".publicKeys = allKeys;
}
