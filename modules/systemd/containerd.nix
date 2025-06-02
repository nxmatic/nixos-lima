{ config, pkgs, user, ... }:

{
  imports = [
    ./buildkitd.nix
  ];
  virtualisation.containerd.enable = true;

  # Optional: For rootless or special socket permissions, see notes below.
  # services.containerd.extraArgs = "--address /run/containerd/containerd.sock";

  environment.systemPackages = with pkgs; [
    nerdctl
    buildkit
  ];

  # Add your user to the containerd group for socket access
  users.groups.containerd = {};
  users.users.${user}.extraGroups = [ "wheel" "containerd" ];
}
