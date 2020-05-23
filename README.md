## Dockerfiles for MIT Scheme

### To Interact

Use this to get in and debug during installation.

```
docker build .
docker run --ipc host -it --entrypoint /bin/bash $CONTAINER_ID # that gets printed
```

Run the notebook with:
```
docker run --ipc host -it --rm -p 8888:8888 649c9549c1ec
```

## Mac Notes on how to get everything going

- Install XQuartz
- Activate the option ‘Allow connections from network clients’ in XQuartz settings

## Jupyter and Colab

I ended up stuck, here: https://github.com/joeltg/mit-scheme-kernel/issues/21
