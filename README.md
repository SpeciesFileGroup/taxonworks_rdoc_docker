# TaxonWorks RDoc Docker image

This repository builds the Docker image that generates and serves the latest
[TaxonWorks](https://github.com/SpeciesFileGroup/taxonworks) Ruby API
documentation with YARD.

The image clones TaxonWorks and generates the documentation when the container
starts. It does not accept HTTP connections until that initial build succeeds.
On the current TaxonWorks development branch, startup takes approximately six
minutes, uses less than 512 MiB of memory, and produces roughly 110 MB of HTML.

## Build and run

```sh
docker build --build-arg BUNDLER_WORKERS=3 -t taxonworks-rdoc-server .
docker run --rm \
  -p 4567:4567 \
  -e REBUILD_TOKEN=replace-with-a-random-secret \
  taxonworks-rdoc-server
```

Once startup completes, documentation is available at
<http://localhost:4567/>.

`REBUILD_TOKEN` is required and must not be empty. To rebuild the documentation
without restarting the container, use either of the existing endpoints:

```sh
curl http://localhost:4567/rebuild/replace-with-a-random-secret
curl -X POST http://localhost:4567/rebuild/replace-with-a-random-secret
```

The request returns immediately after queuing the rebuild. The existing
documentation remains available until the replacement has been generated and
verified. Multiple requests are coalesced into at most one active and one
pending rebuild.

The token remains part of the URL for compatibility with the existing webhook.
It can therefore appear in access logs and should be treated as a secret.

## Configuration

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `REBUILD_TOKEN` | Yes | — | Token used by the existing rebuild URLs. |
| `TAXONWORKS_REPOSITORY_URL` | No | TaxonWorks GitHub repository | Git repository to document. |
| `TAXONWORKS_REF` | No | `development` | Branch or tag cloned with a shallow checkout. |
| `PORT` | No | `4567` | HTTP listening port. |
| `DOCS_ROOT` | No | `/var/lib/taxonworks-rdoc` | Writable work and generated-documentation directory. |

Initial clone or generation failures terminate the container with a non-zero
status so an orchestrator can restart it. Runtime failures are logged, leave the
current documentation untouched, and do not stop later rebuild requests.

## Kubernetes

The image continues to support startup and liveness probes against `/`. Since
the HTTP server starts only after the initial documentation is ready, the
existing startup probe should allow enough time for generation. A 20-minute
startup budget and a 512 MiB memory limit have been validated for the current
development branch.

The container runs as the non-root user and group `10001` and needs write access
to `DOCS_ROOT`. No persistent volume is required; documentation is regenerated
after every pod restart.

## Continuous integration

GitHub Actions tests the Ruby code, audits Ruby dependencies, builds the image,
and performs a real TaxonWorks generation under the 512 MiB limit. Successful
pushes to `main` are published as the amd64 image
`sfgrp/taxonworks_rdoc_docker:latest` using the existing
`DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets. Dependency updates are
managed by the repository's existing Dependabot configuration.
