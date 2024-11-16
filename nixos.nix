{ config, modulesPath, pkgs, lib, ... }:

let
  isX86_64 = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  isAarch64 = pkgs.stdenv.hostPlatform.system == "aarch64-linux";
  user = "builder";
  keyType = "ed25519";
  keysDirectory = "/etc/ssh/authorized_keys.d";
in 
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/profiles/nix-builder-vm.nix")
    ./systemd
  ];

  nix.settings = lib.mkMerge [
    {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-users = [ user "root" ];
      sandbox = false;
      extra-sandbox-paths = [ "/dev/kvm" ];
    }
    (lib.mkIf isX86_64 {
      extra-platforms = [ "aarch64-linux" ];
      extra-sandbox-paths = [ "/run/binfmt" ];
    })
    (lib.mkIf isAarch64 {
      extra-platforms = [ "x86_64-linux" ];
    })
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
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "console=hvc0"
      "loglevel=7"
      "systemd.log_level=debug"
      "systemd.log_target=console"
      "udev.log_priority=debug"
      "boot.trace"
    ];
    consoleLogLevel = 7;
    initrd.verbose = true;
  };

  system.stateVersion = "24.11";

  fileSystems = {
    "/boot" = {
      device = lib.mkForce "/dev/disk/by-label/ESP";
      fsType = "vfat";
      options = [ "rw" "relatime" "fmask=0022" "dmask=0022" "codepage=437" "iocharset=iso8859-1" "shortname=mixed" "errors=remount-ro" ];
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
    firewall.allowedTCPPorts = [ 22 ];
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
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKk7xjKTZV4dmXx8JbNtJmjQCOoZquHVjLsaOTYnSy5Q" ];
  };

  # Environment
  environment.systemPackages = with pkgs; [
    bash
    qemu
    yq-go
  ];

  # Nix builder configuration
  nix = {
    buildMachines = [{
      hostName = "localhost";
      systems = [ "x86_64-linux" "aarch64-linux" ];
      supportedFeatures = [ "kvm" "big-parallel" ];
      maxJobs = 4;
    }];
    distributedBuilds = true;
    extraOptions = ''
        builders-use-substitutes = true
      '';
    channel.enable = lib.mkForce true;
  };
  documentation.enable = lib.mkForce true;
  system = {
    disableInstallerTools = lib.mkForce false;
  };
  virtualisation.fileSystems = {
    "/etc/ssl/certs" = {
      device = lib.mkForce "certs";
      fsType = lib.mkForce "virtiofs";
      options = lib.mkForce [ "ro"  ];
    };
    "/etc/ssl/cert.pem" = {
      device = lib.mkForce "certs";
      fsType = lib.mkForce "virtiofs";
      options = lib.mkForce [ "ro"  ];
    };
    "/tmp/shared" = {
      device = lib.mkForce "shared";
      fsType = lib.mkForce "virtiofs";
      options = lib.mkForce [ "rw"  ];
    };
    "/tmp/xchg" = {
      device = lib.mkForce "xchg";
      fsType = lib.mkForce "virtiofs";
      options = lib.mkForce [ "rw"  ];
    };
    "/var/keys" = {
      device = lib.mkForce "keys";
      fsType = lib.mkForce "virtiofs";
      options = lib.mkForce [ "rw"  ];
    };
  };
}
