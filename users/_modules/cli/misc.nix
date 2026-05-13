{
  hm = {pkgs, ...}: {
    home.packages = with pkgs; [
      ouch-rar

      # searching-related
      ast-grep

      just
    ];
  };
}
