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

  # Environment
  environment.systemPackages = with pkgs; [
    containerd
    nerdctl
  ];

  systemd.services = {
    containerd = {
      serviceConfig = {
        SupplementaryGroups = [ "containerd" ];
        # Optionally, ensure the socket has the right group and permissions
        # This is usually handled by the containerd service, but you can enforce it:
        #
        # ExecStartPost = [
        #   "${pkgs.coreutils}/bin/chmod 0660 /run/containerd/containerd.sock"
        #   "${pkgs.coreutils}/bin/chown root:containerd /run/containerd/containerd.sock"
        # ];
      };
    };
  };

}
