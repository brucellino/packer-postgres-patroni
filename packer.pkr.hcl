# Packer template for the patroni-enabled
packer {
  required_plugins {
    docker = {
      version = "~> 1"
      source  = "github.com/hashicorp/docker"
    }
  }
}

variable "pkg_deps_apk" {
  type = list(string)
  default = [
    "build-base",    # Required for compilers
    "musl-locales", # Required for locales
    "linux-headers", # Required for building the pip packages
    "python3-dev",   # Required for building some pip packages
    "py3-pip",   #
    "py3-psycopg2", # Required for patroni
    "pipx",          # Required for installation
  ]
}

variable "patroni_pkgs" {
  description = "Patroni extras you want in the deployment"
  type        = list(string)
  default = [
    "consul",
    "raft"
  ]
}


locals {
  github = vault("hashiatho.me-v2/data/github", "packer_token")
}

source "docker" "patroni-amd64" {
  image       = "postgres:17-alpine"
  commit      = true
  run_command = ["-d", "-i", "-t", "--entrypoint=/bin/bash", "--", "{{.Image}}"]
  changes = [
    "LABEL org.opencontainers.image.source=https://github.com/brucellino/packer-postgres-patroni",
    "LABEL org.opencontainers.image.description='Patroni-managed postgres image'",
    "USER postgres",
    "WORKDIR /patroni",
    "ENTRYPOINT [\"/patroni/bin/patroni\"]"
  ]
}

source "docker" "patroni-arm64" {
  image       = "arm64v8/postgres:17-alpine"
  platform    = "linux/arm64"
  commit      = true
  run_command = ["-d", "-i", "-t", "--entrypoint=/bin/bash", "--", "{{.Image}}"]
  changes = [
    "LABEL org.opencontainers.image.source=https://github.com/brucellino/packer-postgres-patroni",
    "LABEL org.opencontainers.image.description='Patroni-managed postgres image'",
    "USER postgres",
    "WORKDIR /usr/bin",
    "ENTRYPOINT [\"/usr/bin/patroni\"]"
  ]
}

build {
  name    = "postgres-patroni-amd64"
  sources = ["docker.docker.patroni-amd64"]
  provisioner "shell" {
    inline = [
      "apk update",
      "apk add ${join(" ", var.pkg_deps_apk)}"
    ]
  }
  # Create virtualenv and add dependencies
  provisioner "shell" {
    inline = [
      "python3 -m venv /patroni",
      "source /patroni/bin/activate",
      "pip install psycopg2 patroni[${join(",", var.patroni_pkgs)}]"
    ]

  }
  post-processors {
    post-processor "docker-tag" {
      repository = "ghcr.io/brucellino/postgres-patroni"
      tags       = ["17.9-alpine"]
    }
    post-processor "docker-push" {
      login = true
      login_server = "ghcr.io"
      login_username = "brucellino"
      login_password = "${local.github}"
    }
  }
}

build {
  name    = "posgtres-patroni-arm64"
  sources = ["docker.patroni-arm64"]
  provisioner "shell" {
    inline = [
      "apk update",
      "apk add ${join(" ", var.pkg_deps_apk)}"
    ]
  }
  # Create virtualenv and add dependencies
  provisioner "shell" {
    inline = [
      "python3 -m venv /patroni",
      "source /patroni/bin/activate",
      "pip install psycopg2 patroni[${join(",", var.patroni_pkgs)}]"
    ]

  }
  post-processors {
    post-processor "docker-tag" {
      repository = "ghcr.io/brucellino/postgres-patroni"
      tags       = ["17.9"]
    }
    post-processor "docker-push" {
      login = true
      login_server = "ghcr.io"
      login_username = "brucellino"
      login_password = "${local.github}"
    }
  }
}
