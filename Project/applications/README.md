# Build the Zero Trust images

Please, read first the initial [README file](../../README.md) explaining this Zero Trust demo use case

You can pull the packages from the standard Hashi demo containers and push to your registry from the Waypoint configuration in this folder. Also, the `payments` application is built from source, so you can modify the configuration application to not use some integrations like Vault Transit engine.

## Pushing images to your own registry

You need to have Docker credentials configured from your Waypoint local runner:

```bash
docker login -u <username> -p <password/token> <your_docker_registry>
```

And then execute Waypoint to push the images:
```bash
waypoint build -var registry=<your_docker_registry> -var platform=<linux/amd64_or_linux/arm64>
```

> NOTE: If you want to make this repo work in an Apple M1 computer you need to build with `platform="linux/arm64"`

Instead of defining the variables in the CLI you can use a `waypoint.auto.wpvars` with the parameters values:
```
versions = {
    redis = "latest"
    payments = "v0.0.16"
    postgres = "v0.0.22"
    product-api = "v0.0.22"
    public-api = "v0.0.7"
    frontend = "v1.0.4"
}
registry = "<your_registry>"
platform = "linux/amd64"
```

So you build easily with:
```bash
waypoint build
```

> NOTE: Please, check the versions available at [HashiCorp Demoapp Docker registry](https://hub.docker.com/search?q=hashicorpdemoapp), and also in the [GitHub repo](https://github.com/hashicorp-demoapp). Read it carefully because some of the versions deprecates some functionality.
> This Waypoint project takes into account the changes made from `frontend` version `v0.0.8`. This means that if you want the old look&feel from HashiCups you need to select `v0.0.7` for the `frontend`, and if you want the new UI just select the latest (currently `v1.0.4`).

## Build and deploy

You can also deploy from here, building and pushing the images first in your registry

```bash
waypoint up -var registry=<your_docker_registry> -var platform=<linux/amd64_or_linux/arm64>
```

