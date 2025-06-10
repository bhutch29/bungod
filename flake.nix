{
  description = "A Nix-flake-based Elixir development environment";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        erl = pkgs.beam.interpreters.erlang_27;
        erlangPackages = pkgs.beam.packagesWith erl;
        elixir = erlangPackages.elixir;
      in
      {
        devShells = {
          default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                elixir
                git
                nodejs_20 # probably needed for your Phoenix assets
              ]
              ++ pkgs.lib.optionals pkgs.stdenv.isLinux (
                with pkgs;
                [
                  gigalixir
                  inotify-tools
                  libnotify
                ]
              );
          };
        };

        packages =
          let
            version = "0.1.0";
            src = pkgs.nix-gitignore.gitignoreSource [] ./.;
            # src = pkgs.lib.cleanSourceWith {
            #   src = ./.;
            #   name = "bungod-source";
            #   filter = pkgs.lib.cleanSourceFilter;
            # };
            # src = builtins.fetchGit {
            #   url = "https://github.com/bhutch29/bungod.git";
            #   ref = "master";
            #   rev = "8b6b5e3d8bf103c6450ac9259341fc9f1946e77a";
            # };
            mixFodDeps = erlangPackages.fetchMixDeps {
              inherit version src;
              pname = "elixir-deps";
              sha256 = "sha256-Gq+SPLQ2dzvqc5VCHMobDCWDi5cUsY2bqTVub4DSGdU=";
            };
            translatedPlatform =
              {
                aarch64-darwin = "macos-arm64";
                aarch64-linux = "linux-arm64";
                armv7l-linux = "linux-armv7";
                x86_64-darwin = "macos-x64";
                x86_64-linux = "linux-x64";
              }
              .${system};
          in
          rec {
            default = erlangPackages.mixRelease {
              inherit version src mixFodDeps;
              pname = "bungod";

              MIX_ENV = "prod";

              preInstall = ''
                ln -s ${pkgs.tailwindcss}/bin/tailwindcss _build/tailwind-${translatedPlatform}
                ln -s ${pkgs.esbuild}/bin/esbuild _build/esbuild-${translatedPlatform}

                ${elixir}/bin/mix assets.deploy
              '';
            };
            nixosModule =
              {
                config,
                lib,
                ...
              }:
              let
                cfg = config.services.bungod;
                bungodPkg = self.packages.${system}.default;
              in
              {
                options.services.bungod = {
                  enable = lib.mkEnableOption "bungod";
                  port = lib.mkOption {
                    type = lib.types.port;
                    default = 4000;
                    description = "Port to listen on, 4000 by default";
                  };
                };
                config = lib.mkIf cfg.enable {
                  environment.systemPackages = [ bungodPkg ];

                  systemd.user.services = {
                    bungod = {
                      description = "Bungod daemon";
                      wantedBy = [ "graphical-session.target" ];
                      after = [ "sys-subsystem-net-devices-tailscale0.device" "graphical-session.target" ];
                      partOf = [ "graphical-session.target" ];
                      requisite = [ "graphical-session.target" ];
                      environment = {
                        PORT = toString cfg.port;
                        MIX_ENV = "prod";
                        PHX_SERVER = "true";
                        LANG = "en_US.UTF-8";
                        DISPLAY = ":0";
                        XAUTHORITY = "/home/bhutch/.Xauthority";
                        WAYLAND_DISPLAY = "wayland-1";
                      };
                      serviceConfig = {
                        Type = "simple";
                        Restart = "on-failure";
                        Environment = "PATH=${pkgs.tailscale}/bin:/etc/profiles/per-user/bhutch/bin:$PATH";
                        # WorkingDirectory = "/home/bhutch/projects/elixir/bungod";
                        ExecStart = "${bungodPkg}/bin/bungod start";
                        ExecStop = "${bungodPkg}/bin/bungod stop";
                      };
                    };
                  };
                };
              };
          };
      }
    );
}
