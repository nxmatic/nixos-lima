{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./git-clone-repo.nix
    ./lima-cloud-init.nix
    ./lima-guest-agent.nix
    ./openssh.nix
    ./rescue.nix
  ];
}
