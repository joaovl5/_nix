{lib, ...}: {
  flake-file = let
    forgejo_url = "git+ssh://git@git.trll.ing";
    forgejo = user: repo: ref: "${forgejo_url}/${user}/${repo}.git?shallow=1&ref=${ref}";
    mirror = repo: ref: (forgejo "mirrors" repo ref);
  in {
    description = "lav nixos config";
    intoPath = lib.mkDefault (toString ./.);

    inputs = {
      all-systems = {
        url = mirror "default" "main";
        flake = false;
      };
      degoog-src = {
        url = mirror "degoog" "0.18.0";
        flake = false;
      };
      deploy-rs.url = mirror "deploy-rs" "master";
      disko.url = mirror "disko" "master";
      emacs-bleeding-edge.url = mirror "emacs-overlay" "master";
      fenix.url = mirror "fenix" "main";
      fennel-ls-nvim-docs = {
        url = "git+https://git.sr.ht/~micampe/fennel-ls-nvim-docs?ref=main";
        flake = false;
      };
      flake-file.url = mirror "flake-file" "main";
      fup.url = mirror "flake-utils-plus" "master";
      hermes-agent.url = "git+ssh://git@git.trll.ing/lav/hermes-agent.git?ref=main";
      hexecute.url = mirror "hexecute" "main";
      hister.url = mirror "hister" "master";
      hm.url = mirror "home-manager" "master";
      jcode.url = "git+ssh://git@git.trll.ing/lav/jcode?ref=master";
      kaneo-src = {
        url = mirror "kaneo" "main";
        flake = false;
      };
      llm-agents.url = mirror "llm-agents.nix" "main";
      mardi-gras-src = {
        url = mirror "mardi-gras" "v0.22.0";
        flake = false;
      };
      microvm.url = mirror "microvm.nix" "main";
      musnix.url = mirror "musnix" "master";
      mysecrets = {
        url = "git+ssh://git@github.com/joaovl5/__secrets.git?ref=main";
        flake = false;
      };
      niri.url = mirror "niri-flake" "main";
      nix-flatpak.url = mirror "nix-flatpak" "v0.7.0";
      nixarr.url = mirror "nixarr" "main";
      nixcord.url = mirror "nixcord" "main";
      nixos-dns.url = mirror "nixos-dns" "main";
      nixpkgs.follows = "unstable";
      nur.url = mirror "NUR" "main";
      octodns-pihole-src = {
        url = mirror "octodns-pihole" "main";
        flake = false;
      };
      optnix.url = "git+https://git.sr.ht/~watersucks/optnix?ref=main";
      pihole6api-src = {
        url = mirror "pihole6api" "main";
        flake = false;
      };
      rumdl-src = {
        url = mirror "rumdl" "v0.1.95";
        flake = false;
      };
      sane-fnlfmt-src = {
        url = "git+ssh://git@git.trll.ing/lav/sane_fnlfmt.git?ref=main";
        flake = false;
      };
      sops-nix.url = mirror "sops-nix" "master";
      stable.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-25.11";
      superpowers = {
        url = mirror "superpowers" "main";
        flake = false;
      };
      tree-sitter-kanata = {
        url = mirror "tree-sitter-kanata" "master";
        flake = false;
      };
      treefmt-nix.url = mirror "treefmt-nix" "main";
      unstable.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-unstable";
      unstable-small.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-unstable-small";
      whisper-overlay.url = "git+https://github.com/joaovl5/whisper-overlay.git?ref=main";
      zjstatus.url = mirror "zjstatus" "main";
    };

    preProcess = inputs:
      inputs
      // {
        _unflake.dedupRules = let
          github_git = owner: repo: ref:
            {
              type = "git";
              url = "https://github.com/${owner}/${repo}.git";
            }
            // lib.optionalAttrs (ref != null) {inherit ref;};
        in [
          {
            when = {
              type = "github";
              owner = "nixos";
              repo = "flake-compat";
            };
            replace = github_git "nixos" "flake-compat" "master";
          }
          {
            when = {
              type = "github";
              owner = "edolstra";
              repo = "flake-compat";
            };
            replace = github_git "edolstra" "flake-compat" "master";
          }
          {
            when = {
              type = "github";
              owner = "rust-lang";
              repo = "rust-analyzer";
            };
            replace = github_git "rust-lang" "rust-analyzer" "nightly";
          }
          {
            when = {
              type = "github";
              owner = "stoeffel";
              repo = "nix-test-runner";
            };
            replace = github_git "stoeffel" "nix-test-runner" "master";
          }
          {
            when = {
              type = "github";
              owner = "yalter";
              repo = "niri";
              ref = "v25.08";
            };
            replace = github_git "YaLTeR" "niri" "v25.08";
          }
          {
            when = {
              type = "github";
              owner = "yalter";
              repo = "niri";
              ref = "main";
            };
            replace = github_git "YaLTeR" "niri" "main";
          }
          {
            when = {
              type = "github";
              owner = "yalter";
              repo = "niri";
            };
            replace = github_git "YaLTeR" "niri" "main";
          }
          {
            when = {
              type = "github";
              owner = "supreeeme";
              repo = "xwayland-satellite";
              ref = "v0.7";
            };
            replace = github_git "Supreeeme" "xwayland-satellite" "v0.7";
          }
          {
            when = {
              type = "github";
              owner = "supreeeme";
              repo = "xwayland-satellite";
              ref = "main";
            };
            replace = github_git "Supreeeme" "xwayland-satellite" "main";
          }
          {
            when = {
              type = "github";
              owner = "supreeeme";
              repo = "xwayland-satellite";
            };
            replace = github_git "Supreeeme" "xwayland-satellite" "main";
          }
        ];
      };
  };
}
