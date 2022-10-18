#!/bin/bash
# Script to generate private/public keypair

# PEM
openssl x509 -noout -text -in "${1}"

# Java keystore
# keytool -v -list -storepass $keystore_passwd -keystore keystore.jks