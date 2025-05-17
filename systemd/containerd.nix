{ config, pkgs, lib, user, ... }:

{
  imports = [
    # Import the buildkitd module
    ./buildkitd.nix
  ];
  # Create the group
  users.groups.containerd = { };

  # Add your user to the group
  users.users.${user}.extraGroups = [ "wheel" "containerd" ];

  # Optionally, ensure the socket has the right group and permissions
  # This is usually handled by the containerd service, but you can enforce it:

  systemd.services = {
    containerd = {
      serviceConfig = {
        SupplementaryGroups = [ "containerd" ];
        # Uncomment if you have socket permission issues:
        # ExecStartPost = [
        #   "${pkgs.coreutils}/bin/chmod 0660 /run/containerd/containerd.sock"
        #   "${pkgs.coreutils}/bin/chown root:containerd /run/containerd/containerd.sock"
        # ];
      };
    };
  };

}
