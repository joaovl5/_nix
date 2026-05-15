{
  inputs,
  lib,
  lua,
  luaPackages,
  stdenv,
  ...
}: let
  src_pin = inputs."sane-fnlfmt-src";
in
  stdenv.mkDerivation {
    pname = "sane-fnlfmt";
    version = "0.3.3-dev";

    src = src_pin.outPath;

    nativeBuildInputs = [luaPackages.fennel];
    buildInputs = [lua];

    makeFlags = [
      "PREFIX=$(out)"
      "FENNEL=${luaPackages.fennel}/bin/fennel"
    ];

    doCheck = true;
    checkTarget = "test";

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck

      $out/bin/fnlfmt --help > /dev/null
      $out/bin/fnlfmt --version | grep -F 0.3.3-dev > /dev/null

      sample="$TMPDIR/sample.fnl"
      printf '%s\n' \
        '(keys (bind (l :cv)' \
        '            (cmd :VenvSelect)' \
        '            (desc "Pick virtual env")))' \
        > "$sample"

      $out/bin/fnlfmt "$sample" > /dev/null 2> stderr
      if [ -s stderr ]; then
        echo "fnlfmt emitted stderr during install check:" >&2
        while IFS= read -r line; do
          echo "$line" >&2
        done < stderr
        exit 1
      fi

      runHook postInstallCheck
    '';

    meta = {
      description = "Formatter for Fennel with sane line-break behavior";
      homepage = "https://git.trll.ing/lav/sane_fnlfmt";
      license = lib.licenses.mit;
      mainProgram = "fnlfmt";
      inherit (lua.meta) platforms;
    };
  }
