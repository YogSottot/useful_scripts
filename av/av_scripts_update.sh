#!/usr/bin/env bash

path="/opt/av/"
wget -q https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/update.abh.sh -O ${path}update.abh.sh
wget -q https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/abh.sh -O ${path}abh.sh
wget -q https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/manual.av.check.sh -O ${path}manual.av.check.sh
wget -q https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/av_scripts_update.sh  -O ${path}av_scripts_update.sh

wget -q https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/.adirignore -O ${path}.adirignore
wget -q https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/.aurlignore -O ${path}.aignore
wget -q https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/.aignore -O ${path}.aurlignore

cat ${path}.adirignore > ${path}abh/ai-bolit/.adirignore
cat ${path}.adirignore_usr >> ${path}abh/ai-bolit/.adirignore
cat ${path}.aignore > ${path}abh/ai-bolit/.aignore
cat ${path}.aignore_usr >> ${path}abh/ai-bolit/.aignore
cat ${path}.aurlignore >> ${path}abh/ai-bolit/.aurlignore
cat ${path}.aurlignore_usr >> ${path}abh/ai-bolit/.aurlignore
