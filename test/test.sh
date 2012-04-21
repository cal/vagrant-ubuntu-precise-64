#!/bin/bash

if ! vagrant box list | grep ubuntu-precise-64 >/dev/null; then
  vagrant box add ubuntu-precise-64 ../package.box
fi

vagrant up
vagrant ssh
