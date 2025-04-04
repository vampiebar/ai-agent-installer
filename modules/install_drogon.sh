#!/bin/bash

set -e

echo "🔧 Installing Drogon for Ubuntu 24.04..."

sudo apt update
sudo apt install -y git cmake g++ libjsoncpp-dev libssl-dev zlib1g-dev uuid-dev libsqlite3-dev libmariadb-dev libpq-dev libhiredis-dev libcurl4-openssl-dev

git clone https://github.com/drogonframework/drogon.git
cd drogon
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install

echo "✅ Drogon installation complete!"
