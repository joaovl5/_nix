{
  hm = {pkgs, ...}: {
    home.packages = with pkgs; [
      chafa
    ];

    programs.fastfetch = {
      enable = true;
      settings = {
        general.detectVersion = false;

        logo = {
          source = ../../../_assets/troll.gif;
          type = "kitty";
          width = 6;
          height = 3;
          padding = {
            left = 1;
            top = 3;
            bottom = 3;
          };
        };

        display = {
          key = {
            width = 10;
          };
          size = {
            binaryPrefix = "jedec";
          };
          separator = "";
        };

        modules = [
          "break"
          {
            type = "os";
            key = "os";
            keyColor = "yellow";
            format = "{name}";
          }
          {
            type = "kernel";
            key = "ker";
            keyColor = "green";
          }
          {
            type = "packages";
            key = "pkgs";
            keyColor = "cyan";
          }
          {
            type = "shell";
            key = "sh";
            keyColor = "blue";
            format = "{pretty-name}";
          }
          {
            type = "wm";
            key = "wm";
            keyColor = "red";
            format = "{pretty-name}";
          }
          {
            type = "uptime";
            key = "up";
            keyColor = "green";
          }
          {
            type = "cpu";
            key = "cpu";
            keyColor = "red";
            format = "{name}";
          }
          {
            type = "memory";
            key = "ram";
            keyColor = "yellow";
            format = "{used} / {total}";
          }
          {
            type = "disk";
            key = "disk";
            keyColor = "cyan";
            folders = [
              "/"
            ];
            format = "{size-used} / {size-total}";
          }
          "break"
          {
            type = "custom";
            format = "[33m󰮯 [32m󰊠 [34m󰊠 [31m󰊠 [36m󰊠 [35m󰊠 [37m󰊠 [97m󰊠";
          }
        ];
      };
    };
  };
}
