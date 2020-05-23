## MIT Scheme

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
