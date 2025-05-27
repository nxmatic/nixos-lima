{ config, modulesPath, pkgs, lib, ... }: {
  environment.systemPackages = with pkgs; [
    bash
    bat
    fd
    htop
    lsd
    lsof
    fzf
    starship
    yq-go
    zoxide
    zsh
  ];

  programs = { zsh.enable = true; };

  users.users = {
    nxmatic = {
      shell = "/run/current-system/sw/bin/zsh";
      isNormalUser = true;
      group = "users";
      extraGroups = [ "wheel" "ssh" "incus-admin" ];
      home = "/home/nxmatic.linux";

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKk7xjKTZV4dmXx8JbNtJmjQCOoZquHVjLsaOTYnSy5Q"
      ];
    };
  };

  services.openssh = {
    enable = true;
    authorizedKeysFiles =
      [ "/etc/ssh/authorized_keys.d/%u" "%h/.ssh/authorized_keys" ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      AllowGroups = [ "ssh" "nixbld" ];
    };
  };
}
