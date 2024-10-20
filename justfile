tailscale_ip := `tailscale ip --4`
default: run

run:
  mix phx.server

debug:
  iex --name bungod@{{tailscale_ip}} --cookie secret_cookie -S mix phx.server

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
  docker run -p 4000:4000 -e RELEASE_COOKIE=secret_cookie -e RELEASE_NODE=bungod@{{tailscale_ip}} -e RELEASE_DISTRIBUTION=name gitea.bunny-godzilla.ts.net/bhutch/bungod:latest

docker_run_host:
  docker run --network host -e RELEASE_COOKIE=secret_cookie -e RELEASE_NODE=bungod@{{tailscale_ip}} -e RELEASE_DISTRIBUTION=name gitea.bunny-godzilla.ts.net/bhutch/bungod:latest
