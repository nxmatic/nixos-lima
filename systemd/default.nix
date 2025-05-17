{
  config,
  pkgs,
  lib,
  user,
  ...
}: {
  imports = [ 
    ( import ./containerd.nix { inherit config pkgs lib user; } )
    ./git-clone-repo.nix
    ./lima-cloud-init.nix
    ./lima-guest-agent.nix
    ./openssh.nix
    ./rescue.nix
  ];
}
