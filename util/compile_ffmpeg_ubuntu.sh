#!/bin/bash

# Set non-interactive frontend for apt-get to avoid prompts
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical

# Update the package list
sudo apt-get update

# Clone the Xilinx video SDK repository
git clone https://github.com/Xilinx/video-sdk

# Change directory to the cloned repository
cd video-sdk

# Initialize and update the submodules recursively
git submodule update --init --recursive

# Change directory to the specific app-ffmpeg4-xma source directory
cd sources/app-ffmpeg4-xma

# Install necessary dependencies without prompts
sudo apt-get install -y libgnutls28-dev libx264-dev

# Configure the build with specified options
./configure --enable-x86asm \
            --enable-libxma2api \
            --disable-doc \
            --enable-libxvbm \
            --enable-libxrm \
            --extra-cflags=-I/opt/xilinx/xrt/include/xma2 \
            --extra-ldflags=-L/opt/xilinx/xrt/lib \
            --extra-libs=-lxma2api \
            --extra-libs=-lxrt_core \
            --extra-libs=-lxrt_coreutil \
            --extra-libs=-lpthread \
            --extra-libs=-ldl \
            --disable-static \
            --enable-static \
            --enable-gnutls \
            --enable-libx264 \
            --enable-gpl \
            --disable-shared

# Compile the source code using all available CPU cores
make -j$(nproc)

# Install the compiled binaries
sudo make install

# Define the new directory to be added to /etc/ld.so.conf
NEW_DIR="/opt/xilinx/xrt/lib"

# Check if the directory is already present in /etc/ld.so.conf and add it if not
if ! grep -q "^${NEW_DIR}$" /etc/ld.so.conf; then
  echo "Adding ${NEW_DIR} to /etc/ld.so.conf"
  echo "${NEW_DIR}" | sudo tee -a /etc/ld.so.conf
else
  echo "${NEW_DIR} is already present in /etc/ld.so.conf"
fi

# Update the shared library cache
sudo ldconfig
