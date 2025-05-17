{ config, pkgs, ... }: let

  dollar = "$";

in {    

  systemd.services.clone-nixos-repo = {

    description = "Clone Git Repository if not already cloned";

    after = [ "network.target" ];  # Ensure network is available before cloning

    requires = [ "network.target" ];

    wantedBy = [ "multi-user.target" ];  # Specify when this service should be started

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;  # Keep the service active after execution
      Environment = "PATH=${pkgs.git}/bin:${pkgs.bash}/bin:${pkgs.stdenv}/bin";  # Use specific binaries
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

      git clone --single-branch --branch develop \
        https://github.com/nxmatic/nixos-lima.git /etc/nixos
    '';
  };

}
