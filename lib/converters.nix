{pkgs, ...}: {
  to_yaml = path: obj:
    pkgs.runCommand "toYAML" {
      buildInputs = with pkgs; [yj];
      json = builtins.toJSON obj;
      passAsFile = ["json"]; # will be $jsonPath
    } ''
      yj -jy < "$jsonPath" > "${path}"
    '';
}
