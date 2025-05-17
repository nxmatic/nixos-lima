let
  disks = {
    tank1 = "/dev/vdb";
    tank2 = "/dev/vdc";
    tank3 = "/dev/vdd";
    recover = "/dev/vde";
  };
in {
  disko = {
    enableConfig = false;
    devices = {
      disk = {
        tank1 = {
          type = "disk";
          device = disks.tank1;
          content = {
            type = "gpt";
            partitions = {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "tank";
                };
              };
            };
          };
        };
        tank2 = {
          type = "disk";
          device = disks.tank2;
          content = {
            type = "gpt";
            partitions = {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "tank";
                };
              };
            };
          };
        };
        tank3 = {
          type = "disk";
          device = disks.tank3;
          content = {
            type = "gpt";
            partitions = {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "tank";
                };
              };
            };
          };
        };
        recover = {
          type = "disk";
          device = disks.recover;
          content = {
            type = "gpt";
            partitions = {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "recover";
                };
              };
            };
          };
        };
      };

      zpool = {
        tank = {
          type = "zpool";
          mode = "raidz1";
          rootFsOptions = {
            acltype = "posixacl";
            atime = "off";
            compression = "zstd";
            mountpoint = "none";
            xattr = "sa";
          };
          options = { ashift = "12"; };
          datasets = {
            "nerd" = {
              type = "zfs_fs";
              options.mountpoint = "none";
            };
            "nerd/nixos" = {
              type = "zfs_fs";
              mountpoint = "/";
            };
            "nerd/nix" = {
              type = "zfs_fs";
              mountpoint = "/nix";
            };
            "nerd/var/tmp" = {
              type = "zfs_fs";
              mountpoint = "/var/tmp";
            };
            "nerd/var/log" = {
              type = "zfs_fs";
              mountpoint = "/var/log";
            };
            "nerd/var/lib/buildkit" = {
              type = "zfs_fs";
              mountpoint = "/var/lib/buildkit";
            };
            "nerd/var/lib/containerd" = {
              type = "zfs_fs";
              mountpoint = "/var/lib/containerd";
            };
            "nerd/var/lib/incus" = {
              type = "zfs_fs";
              mountpoint = "/var/lib/incus";
            };
            "nerd/var/lib/lxc" = {
              type = "zfs_fs";
              mountpoint = "/var/lib/lxc";
            };
            "nerd/var/lib/nix-snapshotter" = {
              type = "zfs_fs";
              mountpoint = "/var/lib/nix-snapshotter";
            };
            "nerd/persist" = {
              type = "zfs_fs";
              mountpoint = "/persist";
              options = {
                "com.sun:auto-snapshot" = "false";
                "needForBoot" = "true";
              };
            };
          };
        };
        recover = {
          type = "zpool";
          mode = "";
          rootFsOptions = {
            acltype = "posixacl";
            atime = "off";
            compression = "zstd";
            mountpoint = "none";
            xattr = "sa";
          };
          options = { ashift = "12"; };
          datasets = {
            "recover" = {
              type = "zfs_fs";
              mountpoint = "/recover";
            };
          };
        };
      };
    };
  };
}

