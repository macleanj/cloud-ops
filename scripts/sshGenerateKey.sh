#!/bin/bash
# Script to generate private/public keypair

METHOD="rsa"

echo "Please enter the keyname"
read NAME

echo "Proceed [y/n]?"
read YN
[ $YN != "y" ] && echo "Aborted. No changed made" && exit 5

KEYNAME="$NAME-$METHOD"

mkdir $KEYNAME
cd $KEYNAME
ssh-keygen -m PEM -t rsa -f $KEYNAME
chmod 400 *
chmod 700 .
