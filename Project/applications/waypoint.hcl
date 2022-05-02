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
}

variable "k8s_namespace" {
  default = "apps"
}

variable "platform" {
  default = "linux/amd64"
}

project = "hashicups-build-dcanadillas"
runner {
  enabled = true

  # data_source "git" {
  #   url  = "https://gitlab.com/dcanadillas/hashidemo-dcanadillas.git"
  # }
}

app "redis" {
  path = "${path.project}/redis"
  build {
    use "docker-pull" {
      image = "redis"
      tag = var.versions.redis
      disable_entrypoint = false
    }
    registry {
     use "docker" {
      image = "${var.registry}/hashicups-${app.name}"
      tag = "${var.versions.redis}-waypoint-${regex("[^/]+$",var.platform)}"
      #  username = var.docker_creds.username
      #  password = var.docker_creds.password
      # local = true
     }
    }
  }
  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = var.k8s_namespace

      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",)),
      ]
    }
  }
}

app "postgres" {
  url {
    auto_hostname = false
  }
  path = "${path.project}/postgres"
  
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
      image = "hashicorpdemoapp/product-api-db"
      tag   = "${var.versions.postgres}"
      disable_entrypoint = false
    }
    registry {
      use "docker" {
        image = "${var.registry}/hashicups-db"
        tag   = "${var.versions.postgres}-waypoint-${regex("[^/]+$",var.platform)}"
        # local = true
      }
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = var.k8s_namespace

      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",)),
      ]
    }
  }
}

app "payments" {
  path = "${path.project}/payments"
  labels = {
    "service" = "payments",
    "env"     = "dev"
  }

  url {
    auto_hostname = false
  }

  build {
    hook {
      when = "before"
      command = ["echo", "${trimprefix(var.versions.payments,"v")}"]
    }
    use "docker" {
      buildkit = true
      platform = var.platform
      dockerfile = templatefile("${path.app}/dockerfiles/Dockerfile.${regex("[^/]+$",var.platform)}", {
        version = var.versions.payments,
        jversion = "${trimprefix(var.versions.payments,"v")}"
      })
      disable_entrypoint = true
    }
    # use "docker-pull" {
    #   image = "hashicorpdemoapp/payments"
    #   tag   = var.versions.payments
    #   disable_entrypoint = false
    # }
    # use "pack" {
    #   builder = "gcr.io/buildpacks/builder:v1"
    #   # disable_entrypoint = true
    # }
    registry {
      use "docker" {
        image = "${var.registry}/hashicups-${app.name}"
        tag   = "${var.versions.payments}-waypoint-${regex("[^/]+$",var.platform)}"
        # local = true
      }
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = "apps"

      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",)),
      ]
    }
  }
}

app "product-api" {
  path = "${path.project}/product-api"

  build {
    use "docker-pull" {
      image = "hashicorpdemoapp/product-api"
      tag   = var.versions.product-api
      disable_entrypoint = false
    }
    ## Use the stanza below if we want to inject the entrypoint manually
    # use "docker" {
    #   context = "${path.project}"
    #   dockerfile = templatefile("${path.project}/dockerfiles/Dockerfile.product-api",{
    #     version = var.versions.product-api
    #   })
    #   buildkit = true
    #   platform = var.platform
    #   disable_entrypoint = true
    # }
    registry {
     use "docker" {
      image = "${var.registry}/hashicups-${app.name}"
      tag = "${var.versions.product-api}-waypoint-${regex("[^/]+$",var.platform)}"
      #  username = var.docker_creds.username
      #  password = var.docker_creds.password
      # local = true
     }
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = var.k8s_namespace

      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl")),
      ]
    }
  }
}

app "public-api" {
  path = "${path.project}/public-api"
  labels = {
    "service" = "public-api",
    "env"     = "dev"
  }

  url {
    auto_hostname = false
  }

  build {
    use "docker-pull" {
      image = "hashicorpdemoapp/public-api"
      tag   = "${var.versions.public-api}"
      disable_entrypoint = true
    }
    registry {
      use "docker" {
        image = "${var.registry}/hashicups-${app.name}"
        tag   = "${var.versions.public-api}-waypoint-${regex("[^/]+$",var.platform)}"
        # local = true
      }
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = "apps"

      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",)),
      ]
    }
  }
}


app "frontend" {
  path = "${path.project}/frontend"
  labels = {
    "service" = "frontend",
    "env"     = "dev"
  }

  url {
    auto_hostname = false
  }

  build {
    use "docker-pull" {
      image = "hashicorpdemoapp/frontend"
      tag   = "${var.versions.frontend}"
      disable_entrypoint = false
    }
    registry {
      use "docker" {
        image = "${var.registry}/hashicups-${app.name}"
        tag   = "${var.versions.frontend}-waypoint-${regex("[^/]+$",var.platform)}"
        # local = true
      }
    }
  }

  deploy {
    use "helm" {
      name  = app.name
      chart = "${path.app}/helm"
      namespace = "apps"

      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",{
          version = "${trimprefix(var.versions.frontend,"v")}"
        })),
      ]
    }
  }
}

# app "nginx" {
#   path = "${path.project}/nginx"
#   labels = {
#     "service" = "nginx",
#     "env"     = "dev"
#   }

#   url {
#     auto_hostname = false
#   }

#   build {
#     use "docker-pull" {
#       image = "nginx"
#       tag   = "alpine"
#       disable_entrypoint = false
#     }
#     registry {
#       use "docker" {
#         image = "${var.registry}/hashicups-${app.name}"
#         tag   = "${var.versions.nginx}-waypoint-${regex("[^/]+$",var.platform)}"
#         # local = true
#       }
#     }
#   }

#   deploy {
#     use "helm" {
#       name  = app.name
#       chart = "${path.app}/helm"
#       namespace = "apps"
#       values = [
#         file(templatefile("${path.app}/helm/values.yaml.tpl",)),
#       ]
#     }
#   }
# }
