#!/usr/bin/env bash

docker pull $1
echo "image: $1 pulled successfully"
echo "saving image as: $1.tar.gz ..."
docker save $1 | gzip > $1.tar.gz
echo "done"
