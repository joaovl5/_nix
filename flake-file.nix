{lib, ...}: {
  flake-file = {
    description = "lav nixos config";
    intoPath = lib.mkDefault (toString ./.);

    inputs = {
      all-systems = {
        type = "github";
        owner = "nix-systems";
        repo = "default";
        rev = "da67096a3b9bf56a91d16901293e51ba5b49a27e";
        narHash = "sha256-Vy1rq5AaRuLzOxct8nz4T6wlgyUR7zLU309k9mBC768=";
        flake = false;
      };
      degoog-src = {
        type = "tarball";
        url = "https://api.github.com/repos/degoog-org/degoog/tarball/refs/tags/0.18.0";
        narHash = "sha256-aY5srxyBhcjNWZjilrcr3NrZmyn7cvJZNPAumbBTzp0=";
        flake = false;
      };
      deploy-rs = {
        type = "github";
        owner = "serokell";
        repo = "deploy-rs";
        rev = "77c906c0ba56aabdbc72041bf9111b565cdd6171";
        narHash = "sha256-hwsYgDnby50JNVpTRYlF3UR/Rrpt01OrxVuryF40CFY=";
      };
      disko = {
        type = "github";
        owner = "nix-community";
        repo = "disko";
        rev = "65fb947964bd44fc0008faf77d1fcb7a9f40bb32";
        narHash = "sha256-wuOkjI6pRiN4sEn/EPBRnNW5cmcpvd7xtIM8y5LooAs=";
      };
      emacs-bleeding-edge = {
        type = "github";
        owner = "nix-community";
        repo = "emacs-overlay";
        rev = "5f8f3a12b25e29c1dd0a6363b61eba7d2f9944fe";
        narHash = "sha256-QrHi1w+g7p58wMxcK9jOXr3oi2PRWQ+i4Sw38sL3dB4=";
      };
      fenix = {
        type = "github";
        owner = "nix-community";
        repo = "fenix";
        rev = "848395a91def85c11694587636151d89555f1ddb";
        narHash = "sha256-r60KTphdevmdIDz1iJ529HvcpOq082ZZ1OnN3jDnrqk=";
      };
      fennel-ls-nvim-docs = {
        type = "git";
        url = "https://git.sr.ht/~micampe/fennel-ls-nvim-docs";
        rev = "a072d3f5d2dd98cf0411cd16446a0f3c96ee7938";
        narHash = "sha256-DpLNcaH3JRrXO8Ds0ZlzoBQFSaOD8xK5+iYZSICBqao=";
        flake = false;
      };
      flake-file.url = "github:vic/flake-file";
      fup = {
        type = "github";
        owner = "gytis-ivaskevicius";
        repo = "flake-utils-plus";
        rev = "afcb15b845e74ac5e998358709b2b5fe42a948d1";
        narHash = "sha256-4WNeriUToshQ/L5J+dTSWC5OJIwT39SEP7V7oylndi8=";
      };
      hermes-agent = {
        type = "git";
        url = "ssh://git@git.trll.ing/lav/hermes-agent.git";
        rev = "db84a78e618bf973ffc403ed2e1f8162f2591daa";
        narHash = "sha256-wJoPWAInmXL5Lu0wLL3eaqdddqFOHP+92NZI7zgSAwI=";
      };
      hexecute = {
        type = "github";
        owner = "ThatOtherAndrew";
        repo = "Hexecute";
        rev = "df00365964ed2f7144f364ee1bdbefec81334583";
        narHash = "sha256-hiLMu/3QznCgKcfhS1E4JzbIe3XP2/c90eWssum3qhE=";
      };
      hister = {
        type = "github";
        owner = "asciimoo";
        repo = "hister";
        rev = "43f0f83b8e95db093750b01bcf67339ed836610c";
        narHash = "sha256-6ikVTpBynzZZVK3lK/qbabFdx3tOcpDdt3F5723j0Og=";
      };
      hm = {
        type = "github";
        owner = "nix-community";
        repo = "home-manager";
        rev = "bd868f769a69d3b6091a1da68a75cb83a181033c";
        narHash = "sha256-Cf+p/T4Z3n9Sw0TiR3kQaIwQI+/hfvLJcoTzeq6yS3E=";
      };
      jandent-src = {
        type = "github";
        owner = "sogaiu";
        repo = "jandent";
        rev = "1943b1b9d8862f52f68ba63350f40a122b291eb4";
        narHash = "sha256-E1AtLmkMwkcYTO9zJNlbkl7muIM9F5a9Y9gr1HmxJZo=";
        flake = false;
      };
      janet-lsp-src = {
        type = "github";
        owner = "Blue-Berry";
        repo = "janet-lsp.nix";
        rev = "b8334a469d38f191198a20a75a6c470c2ea588d2";
        narHash = "sha256-XcIUAmfzBNcsln/XZu9dZoTCTyxoCjNeg//6IK35INs=";
        flake = false;
      };
      janet-nix = {
        type = "tarball";
        url = "https://api.github.com/repos/turnerdev/janet-nix/tarball/refs/tags/v0.2.1";
        narHash = "sha256-17D5xeTKJpv14qyrT8dssdD5Q3jw+UODBFNp2C50big=";
      };
      jcode = {
        type = "git";
        url = "ssh://git@git.trll.ing/lav/jcode";
        rev = "a8c772ca7b0a8085a5bc9eddba6561fb78e50b45";
        narHash = "sha256-Y57eDjJSW+9t4SwZ01pK2Naaw8IqrfU4c63pYFObAsI=";
      };
      kaneo-src = {
        type = "github";
        owner = "usekaneo";
        repo = "kaneo";
        rev = "0f39464f5873d0525dd29f533898ecc323431ed4";
        narHash = "sha256-MRXMFRVQjXXidfGbPZxIu9q4doMah1FdMgiBZozDfCs=";
        flake = false;
      };
      llm-agents = {
        type = "github";
        owner = "numtide";
        repo = "llm-agents.nix";
        rev = "3c69691d60d50f87cc0d5f6222992b63c90b010d";
        narHash = "sha256-pXnXgFvoFQKt4gDnOx0OjKSsv0T51QmN5thbzWf9WX0=";
      };
      mardi-gras-src = {
        type = "tarball";
        url = "https://api.github.com/repos/quietpublish/mardi-gras/tarball/refs/tags/v0.22.0";
        narHash = "sha256-JBiig+kI2X6SZhEb5mAiacLiMI5nIU0klWlBCBFshMo=";
        flake = false;
      };
      microvm = {
        type = "github";
        owner = "microvm-nix";
        repo = "microvm.nix";
        rev = "77024c22f4ddf509137fc732094888d1ffe631e2";
        narHash = "sha256-1dH6yiwEck1n3oz5TDUV5TGbwNqu46eNTVHbhFO2U5k=";
      };
      musnix = {
        type = "github";
        owner = "musnix";
        repo = "musnix";
        rev = "8548782f0d1d0928daa3fffde8a008f72219a3f3";
        narHash = "sha256-Dj51C0NWsglqRrCpdmMr2nFiYacFOid1Tor4H9yG2HY=";
      };
      mysecrets = {
        type = "git";
        url = "ssh://git@github.com/joaovl5/__secrets.git";
        ref = "main";
        flake = false;
      };
      niri = {
        type = "github";
        owner = "sodiboo";
        repo = "niri-flake";
        rev = "f4027707431220ffb660ae0da0e03fd5229ab4d9";
        narHash = "sha256-B4pOfIX6CpCD/cKckwNP3DYDxEUBG1x/K3vqwYNonx4=";
      };
      nix-flatpak = {
        type = "tarball";
        url = "https://api.github.com/repos/gmodena/nix-flatpak/tarball/refs/tags/v0.7.0";
        narHash = "sha256-7ZCulYUD9RmJIDULTRkGLSW1faMpDlPKcbWJLYHoXcs=";
      };
      nixarr = {
        type = "github";
        owner = "nix-media-server";
        repo = "nixarr";
        rev = "3bde55fe657ee3ec1c2b2c05294ff381cb8f2d43";
        narHash = "sha256-eeRN0ew1VfutaVNxoaYvua7CHoqc7gI5vLPxUL5ko7k=";
      };
      nixcord = {
        type = "github";
        owner = "FlameFlag";
        repo = "nixcord";
        rev = "658b4cfe1aa535a7a9a483503aaefcca87ec8aea";
        narHash = "sha256-8ynxFmZsbIMMOyH1BYsQeQ79rp2LH8FF129pZyInooY=";
      };
      nixos-dns = {
        type = "github";
        owner = "Janik-Haag";
        repo = "nixos-dns";
        rev = "4fd527b1bb92cff2f80b3297ae68588dbe772c49";
        narHash = "sha256-Q+s91/rtWoE3DIFf5EfNnsDplFia5sgfb/Q+CPsSy1Y=";
      };
      nixpkgs.follows = "unstable";
      nur = {
        type = "github";
        owner = "nix-community";
        repo = "NUR";
        rev = "4a2b594dd378d794372ebd7d622a984dac29bda3";
        narHash = "sha256-/LW1h4rLmdTzq6L80BQIRzyCa4Ax2Ws9R/xTWgjWXog=";
      };
      octodns-pihole-src = {
        type = "github";
        owner = "roosnic1";
        repo = "octodns-pihole";
        rev = "566a863bc67e18ced24906e7838fa6cff0f471be";
        narHash = "sha256-6pUanEEezAIfNtQB7ia0FThzMv99iI84oTtHOmcIxSE=";
        flake = false;
      };
      optnix = {
        type = "git";
        url = "https://git.sr.ht/~watersucks/optnix";
        rev = "c320dc5494c0caaca9ee4341367618c06a957709";
        narHash = "sha256-zx5O1RyRl6Fq+mvMh+JdS18aXR8644bcN9MKh2fN19M=";
      };
      pihole6api-src = {
        type = "github";
        owner = "sbarbett";
        repo = "pihole6api";
        rev = "e87c651ce0e084bc5f15c529d6103c524ee98d64";
        narHash = "sha256-8vXYZsq9x+1XIXB8c2tBSvQ0qygrwYC9ZKOOfc68apI=";
        flake = false;
      };
      rumdl-src = {
        type = "tarball";
        url = "https://api.github.com/repos/rvben/rumdl/tarball/refs/tags/v0.1.95";
        narHash = "sha256-EH5E9iBxEOik8ZibQqK8A5PeKhYbUxioY5JJlDAg6W8=";
        flake = false;
      };
      sane-fnlfmt-src = {
        type = "git";
        url = "ssh://git@git.trll.ing/lav/sane_fnlfmt.git";
        rev = "87b02d05d870c66730f9dd39f3af26a1b46f1172";
        narHash = "sha256-BTHttm/PmXdA/Lvg5io90ucqi73GFeIdEBnXHam+0wI=";
        flake = false;
      };
      sops-nix = {
        type = "github";
        owner = "Mic92";
        repo = "sops-nix";
        rev = "c591bf665727040c6cc5cb409079acb22dcce33c";
        narHash = "sha256-VfGRo1qTBKOe3s2gOv8LSoA6Fk19PvBlwQ1ECN0Evn8=";
      };
      stable = {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        rev = "687f05a9184cad4eaf905c48b63649e3a86f5433";
        narHash = "sha256-vZJZjLo513IeI8hjzHFc6TDezUd4uCE2Eq4SNO3DNNg=";
      };
      superpowers = {
        type = "github";
        owner = "obra";
        repo = "superpowers";
        rev = "f2cbfbefebbfef77321e4c9abc9e949826bea9d7";
        narHash = "sha256-3E3rO6hR87JUfS3XV1Eaoz6SDWOftleWvN9UPNFEMjw=";
        flake = false;
      };
      tree-sitter-kanata = {
        type = "github";
        owner = "postsolar";
        repo = "tree-sitter-kanata";
        rev = "af53b4c35d6faa3b4ba7c317fb795a6eb679b42a";
        narHash = "sha256-+7EiIkcSe4raApw1H1iQJC2aILLdSrM7Y3tAswbCO1o=";
        flake = false;
      };
      treefmt-nix = {
        type = "git";
        url = "ssh://git@github.com/numtide/treefmt-nix.git";
        rev = "790751ff7fd3801feeaf96d7dc416a8d581265ba";
        narHash = "sha256-pc20NRoMdiar8oPQceQT47UUZMBTiMdUuWrYu2obUP0=";
      };
      unstable = {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        rev = "d233902339c02a9c334e7e593de68855ad26c4cb";
        narHash = "sha256-30sZNZoA1cqF5JNO9fVX+wgiQYjB7HJqqJ4ztCDeBZE=";
      };
      unstable-small = {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        rev = "8e72e9888e67ce593df16546cd31e0d75544ad0d";
        narHash = "sha256-O3UFKrh5oDyOwqD4Njdf7+SIxptOl3gHZyesYvNsIbw=";
      };
      whisper-overlay = {
        type = "github";
        owner = "joaovl5";
        repo = "whisper-overlay";
        rev = "fbf0501b6a2dab1f9aa408f4b11624f58debb5da";
        narHash = "sha256-9Y3DiVQnlZr89bLb3AGgK0osaOyEGVUe69uo5FayXoA=";
      };
      zjstatus = {
        type = "github";
        owner = "dj95";
        repo = "zjstatus";
        rev = "f7f58bd3cb30352a8da85926636b8ec41770098a";
        narHash = "sha256-sjMs63OaRhwCrl46v1A+K2EJdqnw63Pc7BMnHqiU790=";
      };
    };

    preProcess = inputs:
      inputs
      // {
        _unflake.dedupRules = let
          flake_compat = {
            type = "tarball";
            url = "https://api.flakehub.com/f/pinned/edolstra/flake-compat/1.1.0/01948eb7-9cba-704f-bbf3-3fa956735b52/source.tar.gz";
            narHash = "sha256-NeCCThCEP3eCl2l/+27kNNK7QrwZB1IJCrXfrbv5oqU=";
          };
        in [
          {
            when = {
              type = "github";
              owner = "nixos";
              repo = "flake-compat";
            };
            replace = flake_compat;
          }
          {
            when = {
              type = "github";
              owner = "edolstra";
              repo = "flake-compat";
            };
            replace = flake_compat;
          }
          {
            when = {
              type = "github";
              owner = "rust-lang";
              repo = "rust-analyzer";
            };
            replace = {
              type = "git";
              url = "https://github.com/rust-lang/rust-analyzer.git";
              ref = "nightly";
            };
          }
          {
            when = {
              type = "github";
              owner = "stoeffel";
              repo = "nix-test-runner";
            };
            replace = {
              type = "git";
              url = "https://github.com/stoeffel/nix-test-runner.git";
            };
          }
          {
            when = {
              type = "github";
              owner = "yalter";
              repo = "niri";
              ref = "v25.08";
            };
            replace = {
              type = "tarball";
              url = "https://api.github.com/repos/YaLTeR/niri/tarball/refs/tags/v25.08";
              narHash = "sha256-RLD89dfjN0RVO86C/Mot0T7aduCygPGaYbog566F0Qo=";
            };
          }
          {
            when = {
              type = "github";
              owner = "yalter";
              repo = "niri";
              ref = "main";
            };
            replace = {
              type = "github";
              owner = "YaLTeR";
              repo = "niri";
              rev = "cd5ac3e5e04bb5a11276d3c755fa25242818e05f";
              narHash = "sha256-9VvAHNoi2wd0fxLfJOPChZMS7l6rhCtAJmpd59Hv5rw=";
            };
          }
          {
            when = {
              type = "github";
              owner = "supreeeme";
              repo = "xwayland-satellite";
              ref = "v0.7";
            };
            replace = {
              type = "tarball";
              url = "https://api.github.com/repos/Supreeeme/xwayland-satellite/tarball/refs/tags/v0.7";
              narHash = "sha256-m+9tUfsmBeF2Gn4HWa6vSITZ4Gz1eA1F5Kh62B0N4oE=";
            };
          }
          {
            when = {
              type = "github";
              owner = "supreeeme";
              repo = "xwayland-satellite";
              ref = "main";
            };
            replace = {
              type = "github";
              owner = "Supreeeme";
              repo = "xwayland-satellite";
              rev = "a879e5e0896a326adc79c474bf457b8b99011027";
              narHash = "sha256-wToKwH7IgWdGLMSIWksEDs4eumR6UbbsuPQ42r0oTXQ=";
            };
          }
          {
            when = {
              type = "github";
              owner = "supreeeme";
              repo = "xwayland-satellite";
            };
            replace = {
              type = "github";
              owner = "Supreeeme";
              repo = "xwayland-satellite";
              rev = "a879e5e0896a326adc79c474bf457b8b99011027";
              narHash = "sha256-wToKwH7IgWdGLMSIWksEDs4eumR6UbbsuPQ42r0oTXQ=";
            };
          }
          {
            when = {
              type = "github";
              owner = "yalter";
              repo = "niri";
            };
            replace = {
              type = "github";
              owner = "YaLTeR";
              repo = "niri";
              rev = "cd5ac3e5e04bb5a11276d3c755fa25242818e05f";
              narHash = "sha256-9VvAHNoi2wd0fxLfJOPChZMS7l6rhCtAJmpd59Hv5rw=";
            };
          }
        ];
      };
  };
}
