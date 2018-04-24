#!/usr/bin/env bash

path="/opt/av/"
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/.adirignore -O ${path}.adirignore
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/.aurlignore -O ${path}.aignore
wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/av/.aignore -O ${path}.aurlignore

cat ${path}.adirignore >> ${path}abh/ai-bolit/.adirignore
cat ${path}.adirignore_usr >> ${path}abh/ai-bolit/.adirignore
cat ${path}.aignore >> ${path}abh/ai-bolit/.aignore
cat ${path}.aignore_usr >> ${path}abh/ai-bolit/.aignore
cat ${path}.aurlignore >> ${path}abh/ai-bolit/.aurlignore
cat ${path}.aurlignore_usr >> ${path}abh/ai-bolit/.aurlignore
