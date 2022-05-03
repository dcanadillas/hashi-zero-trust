variable "versions" {
  type = object({
    redis = string
    payments = string
    postgres = string
    product-api = string
    public-api = string
    frontend = string
    nginx = string
  })
  default = {
    redis = "latest"
    payments = "v0.0.16"
    postgres = "v0.0.21"
    product-api = "v0.0.21"
    public-api = "v0.0.6"
    frontend = "v1.0.3"
    nginx = "alpine"
  }
}
variable "encryption" {
  type = object({
    db = string
    enabled = string
    engine = string
  })
  default = {
    db = "redis"
    enabled = "true"
    engine = "transit"
  }
}

variable "registry" {
  default = "hcdcanadillas"
}

variable "k8s_namespace" {
  default = "apps"
}

variable "platform" {
  default = "linux/amd64"
}

project = "zero-trust-dcanadillas"
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
    # use "docker-pull" {
    #   image = "redis"
    #   tag = var.versions.redis
    #   disable_entrypoint = false
    # }
  }
  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = var.k8s_namespace

      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",{
          artifact = {
            image = "${var.registry}/hashicups-${app.name}",
            tag   = "${var.versions.redis}-waypoint-${regex("[^/]+$",var.platform)}"
            # image = "redis",
            # tag = var.versions.redis
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
      # image = "hashicorpdemoapp/product-api-db"
      # tag   = "${var.versions.postgres}"
      disable_entrypoint = true
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = var.k8s_namespace

      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",{
          artifact = {
            image = "${var.registry}/hashicups-db",
            tag   = "${var.versions.postgres}-waypoint-${regex("[^/]+$",var.platform)}"
            # image = "hashicorpdemoapp/product-api-db",
            # tag   = "${var.versions.postgres}"
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
      # image = "hashicorpdemoapp/payments"
      # tag   = "${var.versions.payments}"
      disable_entrypoint = true
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = "apps"

      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",{
          artifact = {
            image = "${var.registry}/hashicups-${app.name}"
            tag   = "${var.versions.payments}-waypoint-${regex("[^/]+$",var.platform)}"
            # image = "hashicorpdemoapp/payments",
            # tag   = "${var.versions.payments}"
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
      # image = "hashicorpdemoapp/product-api"
      # tag   = "${var.versions.product-api}"
      disable_entrypoint = true
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = var.k8s_namespace

      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",{
          artifact = {
            image = "${var.registry}/hashicups-${app.name}"
            tag = "${var.versions.product-api}-waypoint-${regex("[^/]+$",var.platform)}"
            # image = "hashicorpdemoapp/product-api",
            # tag   = "${var.versions.product-api}"
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
      # image = "hashicorpdemoapp/public-api"
      # tag   = "${var.versions.public-api}"
      disable_entrypoint = true
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = "apps"

      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",{
          artifact = {
            image = "${var.registry}/hashicups-${app.name}"
            tag   = "${var.versions.public-api}-waypoint-${regex("[^/]+$",var.platform)}"
            # image = "hashicorpdemoapp/public-api",
            # tag   = "${var.versions.public-api}"
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
      # image = "hashicorpdemoapp/frontend"
      # tag   = "${var.versions.frontend}"
      disable_entrypoint = true
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = "apps"

      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",{
          version = "${trimprefix(var.versions.frontend,"v")}",
          artifact = {
            image = "${var.registry}/hashicups-frontend",
            tag   = "${var.versions.frontend}-waypoint-${regex("[^/]+$",var.platform)}"
            # image = "hashicorpdemoapp/frontend",
            # tag   = "${var.versions.frontend}"
          },
        })),
      ]
    }
  }
}

# app "nginx" {
#   path = "${path.project}/applications/nginx"
#   labels = {
#     "service" = "nginx",
#     "env"     = "dev"
#   }

#   url {
#     auto_hostname = false
#   }

#   build {
#     use "docker-pull" {
#       image = "${var.registry}/hashicups-nginx"
#       # image = "nginx"
#       tag   = "${var.versions.nginx}-waypoint-${regex("[^/]+$",var.platform)}"
#       # tag   = "alpine"
#       disable_entrypoint = true
#     }
#   }

#   deploy {
#     use "helm" {
#       name  = app.name
#       chart = "${path.app}/helm"
#       namespace = "apps"
#       values = [
#         file(templatefile("${path.app}/helm/values.yaml.tpl",{
#           artifact = {
#             image = "${var.registry}/hashicups-nginx",
#             tag   = "${var.versions.nginx}-waypoint-${regex("[^/]+$",var.platform)}"
#             # image = "hashicorpdemoapp/frontend",
#             # tag   = "${var.versions.frontend}"
#           },
#         })),
#       ]
#     }
#   }
# }
