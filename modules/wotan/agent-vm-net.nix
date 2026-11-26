# Addressing of the agent VMs, shared by agent-vm.nix and agent-egress.nix.
# Plain data: `vm` is a wotan.agentVm.<name> value.
{
  hostAddr = "10.200.0.1";
  guestAddr = vm: "10.200.0.${toString vm.index}";
  tap = name: "avm-${name}";
}
