{ config, pkgs, lib, containerRegistryConfiguration, ... }:

let
  isX86_64 = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  isAarch64 = pkgs.stdenv.hostPlatform.system == "aarch64-linux";
  user = "nixos";
  keyType = "ed25519";
  keysDirectory = "/etc/ssh/authorized_keys.d";
  kernelModules = [ "ext4" "overlay" ];
  supportedFilesystems = {
    ext4 = true;
    overlay = true;
  };
  # Generate a hostId (should be a 4-byte hex string, e.g. from `head -c4 /dev/urandom | od -A none -t x4`)
  hostId = "deadbeef";
in {
  imports = [
    (import ./code-server.nix { inherit config pkgs lib user; })

    (import ./container-host.nix { inherit config pkgs lib user; })
    (import ./containers {
      inherit config pkgs lib user containerRegistryConfiguration;
      hostId = hostId;
    })
    (import ./disko.nix { inherit config pkgs lib user; })
    (import ./incus.nix { inherit config pkgs lib user; })
    (import ./lima-host.nix { inherit config pkgs lib user; })
    (import ./networking-mammoth-skate.nix { inherit config pkgs lib user; })
    (import ./systemd { inherit config pkgs lib user; })
    (import ./tailscale.nix { inherit config pkgs lib user; })
    (import ./zfs.nix { inherit config pkgs lib user hostId; })
    #(import ./remote-nix-store.nix { inherit config pkgs lib; })
    #(import ./nix-snapshotter.nix { inherit config pkgs lib user; })
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

    inherit kernelModules supportedFilesystems;

    binfmt.emulatedSystems = lib.mkMerge [
      (lib.mkIf isX86_64 [ "aarch64-linux" ])
      (lib.mkIf isAarch64 [ "x86_64-linux" ])
    ];

    loader = {
      grub = {
        device = "nodev";
        efiSupport = true;
        efiInstallAsRemovable = true;
      };
      timeout = lib.mkForce 0;
    };

    kernelParams = [
      "console=hvc0"
      "loglevel=7"
      "systemd.log_level=debug"
      "systemd.log_target=console"
      "udev.log_priority=debug"
      "boot.trace"
      "rd.systemd.unit=rescue.target"
      "rd.systemd.debug_shell=1"
    ];

    kernel.sysctl = {
      "net.bridge.bridge-nf-call-ip6tables" = 1;
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-arptables" = 1;
    };

    loader.systemd-boot.enable = true; # (for UEFI systems only)

    # verbosity
    consoleLogLevel = 7;
    initrd = {
      inherit kernelModules supportedFilesystems;

      enable = true;
      verbose = true;
    };

    postBootCommands = ''
      chmod 755 /boot || true
      chmod 600 /boot/loader/.#bootctlrandom-seed* 2>/dev/null || true
    '';
  };

  system.stateVersion = "25.05"; # Update this when upgrading NixOS

  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-label/ESP";
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
  } // lib.mkIf (!config.disko.enableConfig) {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      autoResize = true;
      fsType = "ext4";
      options = [ "noatime" "nodiratime" "discard" ];
    };
    "/tmp" = {
      device = "/var/tmp";
      options = [ "bind" ];
    };
  };

  networking.mammoth-skate.enable = true;

  # Remove or comment out the old networking block to avoid conflicts:
  # networking = { ... }

  # Services
  services = {
    getty.autologinUser = user;
    openssh = {
      enable = true;
      settings = {
        AllowGroups = [ "wheel" "ssh" ];
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
    extraGroups = [ "wheel" "ssh" ];
  };

  # Environment
  environment.systemPackages = with pkgs; [
    bash
    disko
    emacs-nox
    flox
    git
    yq-go
    zfs
  ];
}
