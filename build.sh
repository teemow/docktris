#!/bin/sh

cd game-actions/create
docker build -t teemow/docktris-game-create .
cd ../..

cd piece-actions/create
docker build -t teemow/docktris-piece-create .
cd ../..

cd block-actions/create
docker build -t teemow/docktris-block-create .
cd ../..

cd reader/
docker build -t teemow/docktris-reader .
cd ../

