default: run

run:
  mix phx.server

debug:
  iex -S mix phx.server

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
  docker run -p 4000:4000 gitea.bunny-godzilla.ts.net/bhutch/bungod:latest
