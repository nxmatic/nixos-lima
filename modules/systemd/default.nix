{
  config, pkgs, user, ...
}: {
  imports = [ 
    (import ./buildkitd.nix { inherit config pkgs user; })
    ./lima-cloud-init.nix
    ./nixos-mount-config.nix
    ./openssh.nix
    ./rescue.nix
  ];
}
