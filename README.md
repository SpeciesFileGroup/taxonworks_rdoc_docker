# taxonworks_rdoc_docker
Docker environment to serve TaxonWorks RDoc pages

### Example usage
```
docker build . -t taxonworks-rdoc-server
docker run -it --rm -p 4567:4567 -e REBUILD_TOKEN=RANDOM_STRING taxonworks-rdoc-server # REBUILD_TOKEN env is optional
```

Once documentation is built you may access the docs at `http://localhost:4567/`. You may rebuild the docs by visiting `http://localhost:4567/rebuild/RANDOM_STRING` (`http://localhost:4567/rebuild/` if image is running without any `REBUILD_TOKEN`)
