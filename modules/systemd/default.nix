{
  config, pkgs, user, ...
}: {
  imports = [ 
    (import ./containerd.nix { inherit config pkgs user; })
    ./lima-cloud-init.nix
    # ./lima-guest-agent.nix
    ./lima-mount-config.nix
    ./openssh.nix
    ./rescue.nix
  ];
}
