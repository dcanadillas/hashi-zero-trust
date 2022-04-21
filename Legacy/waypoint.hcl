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
  default = "dcanadillas"
}

variable "platform" {
  default = "linux/amd64"
}

variable "k8s_namespace" {
  default = "apps"
}



project = "hashidemo-dcanadillas-legacy"
runner {
  enabled = true

  # data_source "git" {
  #   url  = "https://gitlab.com/dcanadillas/hashidemo-dcanadillas.git"
  # }
}



app "frontend" {
  path = "${path.project}/front"

  build {
    use "docker-pull" {
      image = "${var.registry}/frontend"
      tag   = var.versions.frontend
    }
    registry {
      use "docker" {
        image = "${var.registry}/hashicups-frontend"
        tag   = var.versions.frontend
        # local = true
      }
    }
  }

  deploy {
    use "kubernetes-apply" {
      path        = templatedir("${path.app}/k8s")
      prune_label = "app=frontend"
    }
  }
}

app "public-api" {
  path = "${path.project}/public-api"
  url {
    auto_hostname = false
  }

  build {
    use "docker-pull" {
      image = "${var.registry}/public-api"
      tag   = var.versions.public-api
    }
    registry {
      use "docker" {
        image = "${var.registry}/hashicups-public-api"
        tag   = var.versions.public-api
        # local = true
      }
    }
  }

  deploy {
    # We need to implement the following hook in order to assure that the right service is being created to 
    # do the Consul Connect injection. This is happening because Release stage of Waypoint is changing
    # the Service selectors, so no service is recognized from Connect before the deployment.
    # We need also to be aware that this considers the first deployment and following ones (when the service 
    # already exists)
    hook {
      when    = "before"
      command = ["${path.project}/clean_service.sh", "public-api","apps"]
    }
    hook {
      when    = "before"
      command = ["kubectl","apply","-f","${path.app}/service.yaml","-n","apps"]
    }
    use "kubernetes" {
      labels = {
        "myapp" = "public-api"
      }
      annotations = {
        "consul.hashicorp.com/connect-inject" = "true"
        # "consul.hashicorp.com/connect-service" = "public-api"
        # "consul.hashicorp.com/connect-service-upstreams" = "product-api:9090,payments:9191"
        # "consul.hashicorp.com/connect-service-protocol" = "http"
      }
      service_port = "8080"
      service_account = "public-api"
      static_environment = {
        PRODUCT_API_URI = "http://product-api:9090"
        PAYMENT_API_URI = "http://payments:8080"
        BIND_ADDRESS = ":8080"
      }
      namespace = var.k8s_namespace
    }
  }

  release {
    use "kubernetes" {
      port = "8080"
      namespace = var.k8s_namespace
    }
  }
}

app "product-api" {
  path = "${path.project}/product-api"

  build {
    use "docker-pull" {
      image = "${var.registry}/product-api"
      tag   = var.versions.product-api
    }
    registry {
      use "docker" {
        image = "${var.registry}/hashicups-product-api"
        tag   = var.versions.product-api
        # local = true
      }
    }
  }

  deploy {
    use "kubernetes-apply" {
      path        = templatefile("${path.app}/product-api.yaml")
      prune_label = "app=productapi"
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
      "POSTGRES_USER" = configdynamic("vault", {
        path = "kv/data/database"
        key = "data/username"
      })
      "POSTGRES_PASSWORD" = configdynamic("vault", {
        path = "kv/data/database"
        key = "data/password"
      })
    }
  }
  build {
    use "docker-pull" {
      image = "${var.registry}/product-api-db"
      tag   = var.versions.postgres
    }
    registry {
      use "docker" {
        image = "${var.registry}/hashicups-db"
        tag   = var.versions.postgres
        # local = true
      }
    }
  }

  deploy {
    use "kubernetes-apply" {
      path = templatedir("${path.app}")
      prune_label = "app=postgres"
    }
  }
}

app "payments" {
  path = "${path.project}/payments/payments"
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
      dockerfile = "${path.app}/Dockerfile"
    }
    // use "docker-pull" {
    //   image = "${var.registry}/payments"
    //   tag   = "v0.0.12"
    // }
    registry {
      use "docker" {
        image = "${var.registry}/hashicups-payments"
        tag   = var.versions.payments
        # local = true
      }
    }
  }

  deploy {
    # We need to implement the following hook in order to assure that the right service is being created to 
    # do the Consul Connect injection. This is happening because Release stage of Waypoint is changing
    # the Service selectors, so no service is recognized from Connect before the deployment.
    # We need also to be aware that this considers the first deployment and following ones (when the service 
    # already exists)
    hook {
      when    = "before"
      command = ["${path.project}/clean_service.sh", "payments","apps"]
    }
    hook {
      when    = "before"
      command = ["kubectl","apply","-f","${path.project}/payments/k8s/service.yaml","-n","apps"]
    }
    use "kubernetes" {
      labels = {
        "myapp" = "payments"
      }
      service_port = 8080
      service_account = "payments"
      namespace = var.k8s_namespace
      annotations = {
        # "vault.hashicorp.com/agent-inject" = "true"
        # "vault.hashicorp.com/agent-inject-token"= "true"
        # "vault.hashicorp.com/role"= "hashicups"
        # "vault.hashicorp.com/agent-init-first" = "true"
        "consul.hashicorp.com/connect-inject" = "true"
        # "consul.hashicorp.com/connect-service" = "payments"
        # "consul.hashicorp.com/connect-service-protocol" = "http"
      }
    }
  }

  release {
    use "kubernetes" {
      port = 8080
      namespace = var.k8s_namespace
    }
  }
}

app "redis" {
  path = "${path.project}/redis"
  build {
    use "docker-pull" {
      image = "redis"
      tag = "latest"
      disable_entrypoint = true
    }
    # registry {
    #  use "docker" {
    #    image = "${var.registry}/hashicups-redis"
    #    tag = "latest"
    #    username = var.docker_creds.username
    #    password = var.docker_creds.password
    #    #local = true
    #  }
    # }
  }
  deploy {
    # We need to implement the following hook in order to assure that the right service is being created to 
    # do the Consul Connect injection. This is happening because Release stage of Waypoint is changing
    # the Service selectors, so no service is recognized from Connect before the deployment.
    # We need also to be aware that this considers the first deployment and following ones (when the service 
    # already exists)
    # hook {
    #   when    = "before"
    #   command = ["${path.project}/clean_service.sh", "redis","apps"]
    # }
    # hook {
    #   when = "before"
    #   command = ["kubectl", "apply", "-f", "${path.app}/serviceaccount.yaml"]
    # }
    use "kubernetes" {
      labels = {
        "myapp" = "redis"
      }
      service_port = 6379
      namespace = var.k8s_namespace
      service_account = "redis"
      annotations = {
        "consul.hashicorp.com/connect-inject" = "true"
        # "consul.hashicorp.com/connect-service" = "redis"
      }
    }
  }
  # release {
  #   use "kubernetes" {
  #     port = "6379"
  #     namespace = var.k8s_namespace
  #   }
  # }
}
