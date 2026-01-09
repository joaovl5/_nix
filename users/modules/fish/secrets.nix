{
  hm = {lib, ...}: let
    var = name: value: "set -gx ${name} ${lib.escapeShellArg value}";
  in {
    programs.fish.shellInitLast = ''
      ${var "TEST" "this is a sample test 'testing' \"aadajida\" "}
    '';
  };
}
