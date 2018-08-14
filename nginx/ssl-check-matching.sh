#!/bin/bash
#
# Script:       ssl-check-matching.sh
# Source:       https://github.com/o-pod/security
#
# Description:  Checking public and private keys for valid and matching
# Version:      0.1.0
# Date:         Jun 2018
# Depends:      OpenSSL
#
# Author:       Oleg Podgaisky (o-pod)
# E-mail:       oleg-podgaisky@yandex.ru
#
# Usage:        ssl-check-matching.sh <certificate> <private key> [-v]
# Output:       0 - certificate and private key are match
#               1 - certificate and private key are NOT match
#               2 - error
#==============================================================================

params=$(echo "${*}" | sed 's/[\t ]\{1,\}/ /g' | sed 's/^[ ]\{1,\}//' | sed 's/[ ]\{1,\}$//')
verbose=$(echo " "${params}" " | grep -o " \-v ")


### Test parameters of the commandline
#
files=$(echo " "${params}" " | sed ' s/-[a-z] / /gi' | sed 's/[\t ]\{1,\}/ /g')
file1=$(echo ${files} | cut -d" " -f1)
file2=$(echo ${files} | cut -d" " -f2)

if [ "${file1}" == "${file2}" ]; then
  if [ -n "${verbose}" ]; then
    echo "ERROR: You should specify 2 not same files as parameters"
  else
    echo 2
  fi
  exit 2
fi


### Test the files for exist
#
if [ ! -f "${file1}" ]; then
  if [ -n "${verbose}" ]; then
    echo "ERROR: File ${file1} is not exist or access denied"
  else
    echo 2
  fi
  exit 2
fi
if [ ! -f "${file2}" ]; then
  if [ -n "${verbose}" ]; then
    echo "ERROR: File ${file2} is not exist or access denied"
  else
    echo 2
  fi
  exit 2
fi


### Validate the certificate and the private key
#
cert_from_file=$(openssl x509 -noout -modulus -in ${file1} 2>&1)
cert_from_file_test=$(echo ${cert_from_file} | grep "unable to load certificate")
if [ -n "${cert_from_file_test}" ]; then
  cert_from_file=$(openssl x509 -noout -modulus -in ${file2} 2>&1)
  cert_from_file_test=$(echo ${cert_from_file} | grep "unable to load certificate")
  if [ -n "${cert_from_file_test}" ]; then
    if [ -n "${verbose}" ]; then
      echo "ERROR: Not the ${file1} nor the ${file2} are valid certificate"
    else
      echo 2
    fi
    exit 2
  fi
fi

key_from_file=$(openssl rsa -noout -modulus -in ${file1} 2>&1)
key_from_file_test=$(echo ${key_from_file} | grep "unable to load Private Key")
if [ -n "${key_from_file_test}" ]; then
  key_from_file=$(openssl rsa -noout -modulus -in ${file2} 2>&1)
  key_from_file_test=$(echo ${key_from_file} | grep "unable to load Private Key")
  if [ -n "${key_from_file_test}" ]; then
    if [ -n "${verbose}" ]; then
      echo "ERROR: Not the ${file1} nor the ${file2} are valid private key"
    else
      echo 2
    fi
    exit 2
  fi
fi


### Test matching certificate and private key
#
cert_md5=$(echo ${cert_from_file} | openssl md5)
key_md5=$(echo ${key_from_file} | openssl md5)
if [ "${cert_md5}" != "${key_md5}" ]; then
  if [ -n "${verbose}" ]; then
    echo "The certificate and the private key are NOT matching"
  else
    echo 1
    exit 1
  fi
else
  if [ -n "${verbose}" ]; then
    echo "The certificate and the private key are matching"
  else
    echo 0
    exit 0
  fi
fi

