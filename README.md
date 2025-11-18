# Rising World Dedicated Docker Server

This is a base image for `Rising World` dedicated Server.

## Usage

### docker-compose example

```yml
services:
  rw-server:
    image: devidian/rising-world-docker:latest
    container_name: rw-docker
    restart: unless-stopped
    volumes:
      # left side: your docker-host machine
      # right side: the paths in the image (!!do not change!!)
      - /appdata/rising-world/dedicated-server:/appdata/rising-world/dedicated-server
    ports:
      - "4254-4259:4254-4259/udp"
      - "4254-4259:4254-4259/tcp"
```
