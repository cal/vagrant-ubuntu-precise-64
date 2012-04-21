#!/bin/bash

vagrant box add ubuntu-precise-64 ../package.box
vagrant init ubuntu-precise-64
vagrant up
vagrant ssh
