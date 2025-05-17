{ config, modulesPath, pkgs, lib, hostId, ... }:

let
  isX86_64 = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  isAarch64 = pkgs.stdenv.hostPlatform.system == "aarch64-linux";
  user = "builder";
  keyType = "ed25519";
  keysDirectory = "/etc/ssh/authorized_keys.d";
in {
  imports = [
    #    (modulesPath + "/profiles/qemu-guest.nix")
    #    (modulesPath + "/profiles/nix-builder-vm.nix")
    (import ./systemd { inherit config pkgs lib user; })
    ./nix-snapshotter.nix
    ( import ./incus.nix { inherit config pkgs lib user; } )
  ];

  nix.settings = lib.mkMerge [
    {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-users = [ user "root" ];
      sandbox = false;
      extra-sandbox-paths = [ "/dev/kvm" ];

      # Flox cache settings
      extra-substituters = [ "https://cache.flox.dev" ];
      extra-trusted-public-keys =
        [ "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs=" ];
    }
    (lib.mkIf isX86_64 {
      extra-platforms = [ "aarch64-linux" ];
      extra-sandbox-paths = [ "/run/binfmt" ];
    })
    (lib.mkIf isAarch64 { extra-platforms = [ "x86_64-linux" ]; })
  ];

  # Boot configuration
  boot = {

    binfmt.emulatedSystems = lib.mkMerge [
      (lib.mkIf isX86_64 [ "aarch64-linux" ])
      (lib.mkIf isAarch64 [ "x86_64-linux" ])
    ];

    loader.grub = {
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = true;
    };

    kernelPackages =
      pkgs.linuxPackages_6_12; # zfs is broken now on latest kernel

    kernelParams = [
      "console=hvc0"
      "loglevel=7"
      "systemd.log_level=debug"
      "systemd.log_target=console"
      "udev.log_priority=debug"
      "boot.trace"
    ];

    kernel.sysctl = {
      "net.bridge.bridge-nf-call-ip6tables" = 1;
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-arptables" = 1;
    };

    supportedFilesystems = [ "ext4" "zfs" ];

    loader.systemd-boot.enable = true; # (for UEFI systems only)

    # verbosity
    consoleLogLevel = 7;
    initrd.verbose = true;
  };

  system.stateVersion = "24.11";

  fileSystems = {
    "/boot" = {
      device = lib.mkForce "/dev/disk/by-label/ESP";
      fsType = "vfat";
      options = [
        "rw"
        "relatime"
        "fmask=0022"
        "dmask=0022"
        "codepage=437"
        "iocharset=iso8859-1"
        "shortname=mixed"
        "errors=remount-ro"
      ];
    };
    "/" = {
      device = "/dev/disk/by-label/nixos";
      autoResize = true;
      fsType = "ext4";
      options = [ "noatime" "nodiratime" "discard" ];
    };
  };

  # Network configuration
  networking = {
    useDHCP = true;
    firewall.allowedTCPPorts = [ 22 2222 ];
    hostId = hostId;
    nftables.enable = true;
  };

  # Services
  services = {
    getty.autologinUser = user;
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
      authorizedKeysFiles = [ "${keysDirectory}/%u_${keyType}.pub" ];
    };
    journald.extraConfig = ''
      ForwardToConsole=yes
      TTYPath=/dev/console
      MaxLevelConsole=debug
    '';
  };

  # Security
  security.sudo.wheelNeedsPassword = false;

  # User configuration
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKk7xjKTZV4dmXx8JbNtJmjQCOoZquHVjLsaOTYnSy5Q"
    ];
  };

  # Environment
  environment.systemPackages = with pkgs; [
    bash
    containerd
    emacs-nox
    flox
    git
    nerdctl
    yq-go
    zfs
  ];

}
