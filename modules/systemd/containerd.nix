{ config, pkgs, user, ... }:

{
  virtualisation.containerd.enable = true;

  # virtualisation.docker.enable = true;
  # virtualisation.docker.storageDriver = "zfs";

  # Optional: For rootless or special socket permissions, see notes below.
  # services.containerd.extraArgs = "--address /run/containerd/containerd.sock";

  # Add your user to the containerd group for socket access
  users.groups.containerd = {};
  users.users.${user}.extraGroups = [ "wheel" "containerd" ];
}
