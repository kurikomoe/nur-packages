#!/usr/bin/env bash

set -ex

nix-update --flake goctl &
nix-update --flake kratos &
nix-update --flake trzsz &
nix-update --flake trzsz-ssh &

wait
