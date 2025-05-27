{ config, modulesPath, pkgs, lib, ... }:

let
  dollar = "$";

  LIMA_CIDATA_MNT = "/mnt/lima-cidata";
  LIMA_CIDATA_DEV = "/dev/disk/by-label/cidata";

  script = ''
    set -xe -o pipefail

    : Systemd service to reconfigure the system from lima-cloud-init userdata on startup using $PATH

    : Attempting to fetch configuration from LIMA user data...
    if [ -f ${LIMA_CIDATA_MNT}/lima.env ]; then
        echo "storage exists";
    else
        echo "storage not exists";
        exit 2
    fi

    : Extend path with required binaries
    export PATH=${
      pkgs.lib.makeBinPath [
        pkgs.bash
        pkgs.mount
        pkgs.rsync
        pkgs.shadow
        pkgs.sudo
        pkgs.util-linux
        pkgs.yq-go
        pkgs.zfs
        pkgs.zsh
      ]
    }:$PATH

    : Remount lima-cidata as overlay
    mkdir -p ${LIMA_CIDATA_MNT}-upper ${LIMA_CIDATA_MNT}-work
    mount -t overlay overlay -o lowerdir=${LIMA_CIDATA_MNT},upperdir=${LIMA_CIDATA_MNT}-upper,workdir=${LIMA_CIDATA_MNT}-work ${LIMA_CIDATA_MNT}
    trap "PATH=$PATH; umount ${LIMA_CIDATA_MNT}; rm -fr ${LIMA_CIDATA_MNT}-*" EXIT

    : Enforce plain mode and load lima.env
    yq --inplace --input-format=props --output-format=props eval '.LIMA_CIDATA_PLAIN=1' "${LIMA_CIDATA_MNT}"/lima.env
    sed --in-place 's/ = /=/' "${LIMA_CIDATA_MNT}"/lima.env
    source <( yq --input-format=props --output-format=shell ${LIMA_CIDATA_MNT}/lima.env )

    : Create user
    LIMA_CIDATA_HOMEDIR="/home/$LIMA_CIDATA_USER.linux"
    id -u "$LIMA_CIDATA_USER" >/dev/null 2>&1 || useradd --home-dir "$LIMA_CIDATA_HOMEDIR" --create-home --uid "$LIMA_CIDATA_UID" "$LIMA_CIDATA_USER"

    : Add user to sudoers
    usermod -a -G wheel $LIMA_CIDATA_USER
    usermod -a -G users $LIMA_CIDATA_USER

    : Fix symlink for /bin/bash
    ln -fs /run/current-system/sw/bin/bash /bin/bash

    : Create authorized_keys
    LIMA_CIDATA_SSHDIR="$LIMA_CIDATA_HOMEDIR"/.ssh
    mkdir -p -m 700 "$LIMA_CIDATA_SSHDIR"

    : Using yq to extract SSH keys and create authorized_keys file
    ${pkgs.yq-go}/bin/yq --from-file=<( cat <<EoF
    .users[] |
      select(.name == "$LIMA_CIDATA_USER") |
      .ssh-authorized-keys[]
    EoF
    ) "${LIMA_CIDATA_MNT}/user-data" > "$LIMA_CIDATA_SSHDIR/authorized_keys"
    LIMA_CIDATA_GID=$(id -g "$LIMA_CIDATA_USER")
    chown -R "$LIMA_CIDATA_UID:$LIMA_CIDATA_GID" "$LIMA_CIDATA_SSHDIR"
    chmod 600 "$LIMA_CIDATA_SSHDIR"/authorized_keys
    LIMA_SSH_KEYS_CONF=/etc/ssh/authorized_keys.d
    mkdir -p -m 700 "$LIMA_SSH_KEYS_CONF"
    cp "$LIMA_CIDATA_SSHDIR"/authorized_keys "$LIMA_SSH_KEYS_CONF/$LIMA_CIDATA_USER"

    : Add mounts to /etc/fstab
    sed -i '/#LIMA-START/,/#LIMA-END/d' /etc/fstab
    cat <<EOS >> /etc/fstab
    #LIMA-START
    $( ${pkgs.yq-go}/bin/yq '.mounts[] | @tsv' "${LIMA_CIDATA_MNT}/user-data" )
    #LIMA-END
    EOS

    : Launch the boot script
    env -S LIMA_CIDATA_MNT=${LIMA_CIDATA_MNT} bash -ex -o pipefail ${LIMA_CIDATA_MNT}/boot.sh
  '';
in {
  imports = [ ];

  systemd.services.lima-cloud-init = {
    inherit script;
    description =
      "Reconfigure the system from lima-cloud-init userdata on startup";

    after = [ "network-pre.target" ];
    before = [ "zfs-import.target" ];

    restartIfChanged = true;

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    unitConfig = { X-StopOnRemoval = false; };
  };

  fileSystems = {
    "${LIMA_CIDATA_MNT}" = {
      device = "${LIMA_CIDATA_DEV}";
      fsType = "auto";
      options =
        [ "ro" "mode=0700" "dmode=0700" "overriderockperm" "exec" "uid=0" ];
    };
  };

  environment.etc = {
    environment.source = "${LIMA_CIDATA_MNT}/etc_environment";
  };

  networking.nat.enable = true;

  environment.systemPackages = with pkgs; [ bash sshfs fuse3 git ];

  boot.kernel.sysctl = {
    "kernel.unprivileged_userns_clone" = 1;
    "net.ipv4.ping_group_range" = "0 2147483647";
    "net.ipv4.ip_unprivileged_port_start" = 0;
  };
}
