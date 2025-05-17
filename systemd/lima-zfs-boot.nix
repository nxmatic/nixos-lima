{ config, pkgs, ... }: let

  dollar = "$";

in {    

  systemd.services.lima-zfs-boot = {

    description = "Clone Git Repository if not already cloned";

    after = [ "network.target" "resolvconf.service" "lima-cloud-init.service" ];  # Ensure network is available before cloning

    requires = [ "network.target" "resolvconf.service" "lima-cloud-init.service" ];  # Ensure these services are available

    wantedBy = [ "multi-user.target" ];  # Specify when this service should be started

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;  # Keep the service active after execution
      Environment = "PATH=${ pkgs.lib.makeBinPath [ pkgs.git pkgs.bash pkgs.stdenv ] }";  # Use specific binaries
    };

    unitConfig = {
      X-StopOnRemoval = false;
    };

    script = ''
      #!/usr/bin/env -S bash -e -x -o pipefail

      shopt -s nullglob
      declare -a files=( /etc/nixos/* )
      [[ ${dollar}{#files[@]} -gt 0 ]] &&
        exit 0

      git clone --single-branch --branch zfs-boot \
        https://github.com/nxmatic/nixos-lima.git /etc/nixos
    '';
  };

}
