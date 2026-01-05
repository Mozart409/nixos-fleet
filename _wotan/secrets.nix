let
  # User SSH keys for encryption/decryption
  amadeus-wotan = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan";
  
  # Define which keys can access which secrets
  allUsers = [amadeus-wotan];
in {
  # CONTEXT7 API key for OpenCode MCP server
  "secrets/context7-api-key.age".publicKeys = allUsers;
}
