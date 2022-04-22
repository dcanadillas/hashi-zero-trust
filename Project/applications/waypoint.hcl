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
    payments = "v0.0.12"
    postgres = "v0.0.17"
    product-api = "v0.0.11"
    public-api = "v0.0.4"
    frontend = "v0.0.5"
  }
}
# variable "docker_creds" {
#   type = object({
#     username = string
#     password = string
#   })
# }

variable "registry" {
}

variable "platform" {
  default = "linux/amd64"
}

variable "k8s_namespace" {
  default = "apps"
}



project = "hashidemo-dcanadillas"
runner {
  enabled = true

  # data_source "git" {
  #   url  = "https://gitlab.com/dcanadillas/hashidemo-dcanadillas.git"
  # }
}

app "redis" {
  path = "${path.project}/redis"
  build {
    ## Use the stanza below if we want to inject the entrypoint manually
    # use "docker" {
    #   context = "${path.project}"
    #   dockerfile = templatefile("${path.project}/dockerfiles/Dockerfile.redis",{
    #     version = var.versions.redis
    #   })
    #   buildkit = true
    #   platform = var.platform
    #   disable_entrypoint = true
    # }
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

      set {
        name  = "deployment.name"
        value = "redis"
      }

      # We use a values file so we can set the entrypoint environment
      # variables into a rich YAML structure. This is easier than --set
      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl")),
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
    ## Use the stanza below if we want to inject the entrypoint manually
    # use "docker" {
    #   context = "${path.project}"
    #   dockerfile = templatefile("${path.project}/dockerfiles/Dockerfile.postgres",{
    #     version = var.versions.postgres
    #   })
    #   disable_entrypoint = true
    # }
    use "docker-pull" {
      image = "hashicorpdemoapp/product-api-db"
      tag   = var.versions.postgres
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

      set {
        name  = "deployment.name"
        value = app.name
      }
      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl")),
      ]
    }
  }
}

app "payments" {
  path = "${path.project}/payments/application"
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
      command = ["make", "-C", "${path.app}", "clean"]
    }
    hook {
      when = "before"
      command = ["make", "-C", "${path.app}", "build"]
    }
    use "docker" {
      buildkit = true
      platform = var.platform
      dockerfile = "${path.app}/Dockerfile.${regex("[^/]+$",var.platform)}"
      disable_entrypoint = true
    }
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
      chart = "${path.app}/../helm"
      namespace = var.k8s_namespace

      set {
        name  = "deployment.name"
        value = app.name
      }
      values = [
        file(templatefile("${path.project}/payments/helm/values.yaml.tpl",)),
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

      set {
        name  = "deployment.name"
        value = app.name
      }
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
      tag   = var.versions.public-api
      disable_entrypoint = false
    }
    ## Use the stanza below if we want to inject the entrypoint manually
    # use "docker" {
    #   context = "${path.project}"
    #   dockerfile = templatefile("${path.project}/dockerfiles/Dockerfile.public-api",{
    #     version = var.versions.public-api
    #   })
    #   disable_entrypoint = true
    # }
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
      namespace = var.k8s_namespace

      set {
        name  = "deployment.name"
        value = app.name
      }
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
      tag   = var.versions.frontend
      disable_entrypoint = false
    }
    ## Use the stanza below if we want to inject the entrypoint manually
    # use "docker" {
    #   context = "${path.project}"
    #   dockerfile = templatefile("${path.project}/dockerfiles/Dockerfile.frontend",{
    #     version = var.versions.frontend,
    #   })
    #   disable_entrypoint = true
    # }
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
      namespace = var.k8s_namespace

      set {
        name  = "deployment.name"
        value = app.name
      }
      values = [
        file(templatefile("${path.app}/helm/values.yaml.tpl",)),
      ]
    }
  }
}
