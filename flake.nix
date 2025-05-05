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
            # src = ./.;
            src = builtins.fetchGit {
              url = "https://github.com/bhutch29/bungod.git";
              ref = "master";
            };
            mixFodDeps = erlangPackages.fetchMixDeps {
              inherit version src;
              pname = "elixir-deps";
              sha256 = "sha256-qVDJB0agqIzVfV2yjZMzwVHzyR8r61OO52oh0vvBeAc=";
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
                ${elixir}/bin/mix phx.gen.release
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
                user = "bungod";
                dataDir = "/var/lib/bungod";
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
                  users.users.${user} = {
                    isSystemUser = true;
                    group = user;
                    home = dataDir;
                    createHome = true;
                  };
                  users.groups.${user} = { };

                  systemd.services = {
                    bungod = {
                      # TODO: copy config from bungod.service
                      description = "Start bungod";
                      wantedBy = [ "multi-user.target" ];
                      script = ''
                        export RELEASE_COOKIE=secret_cookie

                        ${default}/bin/migrate
                        ${default}/bin/server
                      '';
                      serviceConfig = {
                        User = user;
                        WorkingDirectory = "${dataDir}";
                        Group = user;
                      };

                      environment = {
                        RELEASE_DISTRIBUTION = "name";
                        # Home is needed to connect to the node with iex
                        HOME = "${dataDir}";
                        PORT = toString cfg.port;
                      };
                    };
                  };
                };
              };
          };
      }
    );
}
