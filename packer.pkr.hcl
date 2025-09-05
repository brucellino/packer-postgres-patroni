# Packer template for the patroni-enabled
packer {
  required_plugins {
    docker = {
      version = "~> 1"
      source  = "github.com/hashicorp/docker"
    }
  }
}

variable "pkg_deps" {
  type = list(string)
  default = [
    "build-base",    # Required for compilers
    "linux-headers", # Required for building the pip packages
    "python3-dev",   # Required for building some pip packages
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

variable "upstream_tag" {
  type        = string
  description = "Tag of the upstream tag we are building from"
  default     = "16-alpine"
}

variable "username" {
  type = string
  description = "username to log into the registry"
  default = env("GITHUB_USERNAME")
}

variable "password" {
  type = string
  sensitive = true
  description = "Password to push to the container registry"
  default = env("GITHUB_PASSWORD")
}

source "docker" "patroni" {
  image       = "postgres:${var.upstream_tag}"
  commit      = true
  run_command = ["-d", "-i", "-t", "--entrypoint=/bin/bash", "--", "{{.Image}}"]
  changes = [

  ]
}

build {
  name    = "posgres-patroni"
  sources = ["docker.docker.patroni"]
  provisioner "shell" {
    inline = [
      "apk update",
      "apk add ${join(" ", var.pkg_deps)}",
      "pipx install patroni[${join(",", var.patroni_pkgs)}]"
    ]
  }

  post-processor "docker-tag" {
    repository = "ghcr.io/brucellino/postgres-patroni"
    tags       = ["${var.upstream_tag}"]
  }

  post-processor "docker-push" {
    login = true
    login_username = "${var.username}"
    login_password = "${var.password}"
  }
}
