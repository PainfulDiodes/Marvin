#!/usr/bin/env bash

# Build every firmware image. Run from the repo root.

set -e

./build.sh beanzee
./build.sh beanzee_minimal
./build.sh beanboard
./build.sh beanboard_minimal
./build.sh beandeck
./build.sh beandeck_minimal
./build.sh beandeck_reva
./build.sh beandeck_reva_minimal
