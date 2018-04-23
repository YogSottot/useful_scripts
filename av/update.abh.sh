#!/usr/bin/env bash

path="/opt/av/abh/"
if [ ! -d  ${path} ]; then mkdir -p ${path}; fi

rm -f ${path}ai.zip
wget http://bit.ly/2GRX3zL -O /opt/av/abh/ai.zip
unzip -o ${path}ai.zip -d $path

exit 0
