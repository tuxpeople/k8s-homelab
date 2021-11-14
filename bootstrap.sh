#!/usr/bin/env bash
step "Pull the git repo"
git pull

task infrastructure:create
task pre-commit:init
task ansible:deps
task ansible:clean-cache
task ansible:playbook:ubuntu-prepare
task ansible:playbook:k3s-install
