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
  # Format AXON_GATEWAY-TOKEN=ABC123
  "secrets/axon-gateway-env.age".publicKeys = allKeys;
}
