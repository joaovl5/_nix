{
  hm = {pkgs, ...}: {
    hybrid-links.links.macchina = {
      from = ./macchina;
      to = "~/.config/macchina";
    };
    home.packages = with pkgs; [
      chafa

      macchina
    ];
  };
}
