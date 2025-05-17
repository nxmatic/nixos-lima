{
  config,
  pkgs,
  lib,
  user,
  ...
}: {
  imports = [ 
    ( import ./containerd.nix { inherit config pkgs lib user; } )
    ./lima-cloud-init.nix
    # ./lima-guest-agent.nix
    ./lima-zfs-boot.nix
    ./openssh.nix
    ./rescue.nix
  ];
}
