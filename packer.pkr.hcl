# Packer template for the patroni-enabled
packer {
  required_plugins {
    docker = {
      version = "~> 1"
      source = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "patroni" {
  image = "postgres:16-alpine"
  commit = true
  run_command = ["-d", "-i", "-t", "--entrypoint=/bin/bash", "--", "{{.Image}}"]
  changes = [

  ]
}

build {
  name = "posgres-patroni"
  sources = ["docker.docker.patroni"]
  provisioner "shell" {
      inline = [
        "apk update",
        "apk add pipx build-base linux-headers py3-virtualenv python3-dev",
        "pipx install patroni[consul,raft]"
      ]
  }
}
