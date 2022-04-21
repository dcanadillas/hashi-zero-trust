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
    payments = "v0.0.15"
    postgres = "v0.0.19"
    product-api = "v0.0.19"
    public-api = "v0.0.5"
    frontend = "v0.0.7"
}
registry = "<your_registry>"
platform = "linux/amd64"
```

So you build easily with:
```bash
waypoint build
```

## Build and deploy

You can also deploy from here, building and pushing the images first in your registry

```bash
waypoint up
```



