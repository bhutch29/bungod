tailscale_ip := `tailscale ip --4`
default: run

run:
  mix phx.server

debug:
  iex --name bungod@{{tailscale_ip}} --cookie secret_cookie -S mix phx.server

debug_attach:
  iex --name debug@{{tailscale_ip}} --cookie secret_cookie --remsh bungod@{{tailscale_ip}}

one-time-setup:
  mix deps.get
  mix phx.gen.release

release:
  mix release

release_prod:
  env MIX_ENV=prod mix release

run_release:
  _build/dev/rel/bungod/bin/bungod start

run_release_prod:
  _build/prod/rel/bungod/bin/bungod start

install_service:
  sudo cp bungod.service /etc/systemd/system
  systemctl --user enable --now bungod

reinstall_service:
  sudo cp bungod.service /etc/systemd/system
  systemctl --user daemon-reload
  systemctl --user restart bungod

restart_service:
  systemctl --user restart bungod

monitor_service:
  journalctl -u bungod --follow

code:
  zellij attach --create bungod







docker_login:
  docker login gitea.bunny-godzilla.ts.net

docker_build:
  docker build -t gitea.bunny-godzilla.ts.net/bhutch/bungod .

docker_push:
  docker push gitea.bunny-godzilla.ts.net/bhutch/bungod:latest

docker_pull:
  docker pull gitea.bunny-godzilla.ts.net/bhutch/bungod:latest

docker_run:
  docker run --network host -e RELEASE_COOKIE=secret_cookie -e RELEASE_NODE=bungod@{{tailscale_ip}} -e RELEASE_DISTRIBUTION=name gitea.bunny-godzilla.ts.net/bhutch/bungod:latest
