variable "versions" {
  type = object({
    redis = string
    payments = string
    postgres = string
    product-api = string
    public-api = string
    frontend = string
  })
  default = {
    redis = "latest"
    payments = "v0.0.16"
    postgres = "v0.0.22"
    product-api = "v0.0.22"
    public-api = "v0.0.7"
    frontend = "v0.0.7"
  }
}

variable "encryption" {
  type = object({
    enabled = string
    engine = string
  })
  default = {
    enabled = "true"
    engine = "transit"
  }
}

variable "registry" {
  default = "ghcr.io/dcanadillas/hashicups"
}

variable "k8s_namespace" {
  default = "apps"
}

variable "platform" {
  default = "linux/amd64"
}

project = "hashicafe-dcanadillas"
runner {
  enabled = true

  # data_source "git" {
  #   url  = "https://gitlab.com/dcanadillas/hashidemo-dcanadillas.git"
  # }
}

app "redis" {
  path = "${path.project}/applications/redis"
  build {
    use "docker-pull" {
      image = "${var.registry}/hashicups-redis"
      tag = "${var.versions.redis}-waypoint-${regex("[^/]+$",var.platform)}"
      disable_entrypoint = true
    }
  }
  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = var.k8s_namespace

      set {
        name  = "deployment.name"
        value = "redis"
      }
      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",{
          artifact = {
            image = "${var.registry}/hashicups-redis",
            tag = "${var.versions.redis}-waypoint-${regex("[^/]+$",var.platform)}"
          },
        })),
      ]
    }
  }
}

app "postgres" {
  url {
    auto_hostname = false
  }
  path = "${path.project}/applications/postgres"
  
  config {
    env = {
      "POSTGRES_USER" = dynamic("vault", {
        path = "kv/data/hashicups-db"
        key = "data/username"
      })
      "POSTGRES_PASSWORD" = dynamic("vault", {
        path = "kv/data/hashicups-db"
        key = "data/password"
      })
    }
  }
  build {
    use "docker-pull" {
      image = "${var.registry}/hashicups-db"
      tag   = "${var.versions.postgres}-waypoint-${regex("[^/]+$",var.platform)}"
      disable_entrypoint = true
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = var.k8s_namespace

      set {
        name  = "deployment.name"
        value = app.name
      }
      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",{
          artifact = {
            image = "${var.registry}/hashicups-db",
            tag = "${var.versions.postgres}-waypoint-${regex("[^/]+$",var.platform)}"
          },
        })),
      ]
    }
  }
}

app "payments" {
  path = "${path.project}/applications/payments"
  labels = {
    "service" = "payments",
    "env"     = "dev"
  }

  url {
    auto_hostname = false
  }

  build {
    use "docker-pull" {
      image = "${var.registry}/hashicups-payments"
      tag   = "${var.versions.payments}-waypoint-${regex("[^/]+$",var.platform)}"
      disable_entrypoint = true
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = "apps"

      set {
        name  = "deployment.name"
        value = app.name
      }
      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",{
          artifact = {
            image = "${var.registry}/hashicups-payments",
            tag   = "${var.versions.payments}-waypoint-${regex("[^/]+$",var.platform)}"
          },
        })),
      ]
    }
  }
}

app "product-api" {
  path = "${path.project}/applications/product-api"

  build {
    use "docker-pull" {
      image = "${var.registry}/hashicups-product-api"
      tag = "${var.versions.product-api}-waypoint-${regex("[^/]+$",var.platform)}"
      disable_entrypoint = true
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = var.k8s_namespace

      set {
        name  = "deployment.name"
        value = app.name
      }
      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",{
          artifact = {
            image = "${var.registry}/hashicups-product-api",
            tag   = "${var.versions.product-api}-waypoint-${regex("[^/]+$",var.platform)}"
          },
        })),
      ]
    }
  }
}

app "public-api" {
  path = "${path.project}/applications/public-api"
  labels = {
    "service" = "public-api",
    "env"     = "dev"
  }

  url {
    auto_hostname = false
  }

  build {
    use "docker-pull" {
      image = "${var.registry}/hashicups-public-api"
      tag   = "${var.versions.public-api}-waypoint-${regex("[^/]+$",var.platform)}"
      disable_entrypoint = true
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = "apps"

      set {
        name  = "deployment.name"
        value = app.name
      }
      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",{
          artifact = {
            image = "${var.registry}/hashicups-public-api",
            tag   = "${var.versions.public-api}-waypoint-${regex("[^/]+$",var.platform)}"
          },
        })),
      ]
    }
  }
}


app "frontend" {
  path = "${path.project}/applications/frontend"
  labels = {
    "service" = "frontend",
    "env"     = "dev"
  }

  url {
    auto_hostname = false
  }

  build {
    use "docker-pull" {
      image = "${var.registry}/hashicups-frontend"
      tag   = "${var.versions.frontend}-waypoint-${regex("[^/]+$",var.platform)}"
      disable_entrypoint = true
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = "apps"

      set {
        name  = "deployment.name"
        value = app.name
      }
      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",{
          artifact = {
            image = "${var.registry}/hashicups-frontend",
            tag   = "${var.versions.frontend}-waypoint-${regex("[^/]+$",var.platform)}"
          },
        })),
      ]
    }
  }
}
