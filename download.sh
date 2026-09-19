#!/bin/bash

TARGET_VERSION="${TARGET_VERSION:-20260509}"
RELEASE_URL="https://github.com/Ananda-Aropa/aaropa_rootfs_installer_blissos/releases/download/${TARGET_VERSION}"
VERSION_FILE="version.txt"

# Get the script's directory and change to it
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR" || exit

# If install.sfs and initrd_lib already exist, keep existing files and exit cleanly
if [[ -f "iso/install.sfs" && -d "initrd_lib" && -f "boot_hybrid.img" && -f "$VERSION_FILE" ]]; then
  echo "Aaropa files (including install.sfs) already exist. Skipping download."
  exit 0
fi

# Files to download (excluding install.sfs to protect existing install.sfs)
FILES=(
  "initrd_lib.tar.gz"
  "grub-rescue.iso"
  "boot_hybrid.img"
)

# Function to get the target version
get_latest_version() {
  echo "$TARGET_VERSION"
}

# Function to check version and optionally exit
check_version() {
  echo "Checking for the version..."
  LATEST_VERSION=$(get_latest_version)

  if [[ -f "$VERSION_FILE" ]]; then
    LOCAL_VERSION=$(cat "$VERSION_FILE")
    if [[ "$LATEST_VERSION" == "$LOCAL_VERSION" && -f "iso/install.sfs" && -d "initrd_lib" ]]; then
      echo "You already have version ($LATEST_VERSION). Skipping download."
      exit 0
    fi
  fi

  echo "Target version: $LATEST_VERSION (Current: ${LOCAL_VERSION:-None})"
}

# Function to update the version file
update_version() {
  if [[ -n "$LATEST_VERSION" ]]; then
    echo "$LATEST_VERSION" > "$VERSION_FILE"
    echo "Updated $VERSION_FILE to $LATEST_VERSION."
  fi
}

# Function to remove existing files from the FILES list and directories
# Note: Never removes or overwrites iso/install.sfs
remove_existing_files() {
  # Backup existing install.sfs if present
  if [[ -f "iso/install.sfs" ]]; then
    cp -p "iso/install.sfs" "install.sfs.bak"
  fi

  for FILE in "${FILES[@]}"; do
    if [[ -f "$FILE" ]]; then
      echo "Removing existing file: $FILE"
      rm -f "$FILE"*
    fi
  done

  # Remove initrd_lib directory
  if [[ -d "initrd_lib" ]]; then
    echo "Removing existing directory: initrd_lib"
    rm -rf initrd_lib
  fi

  if [[ -d "iso" ]]; then
    echo "Cleaning iso directory (preserving install.sfs)..."
    find iso -mindepth 1 ! -name "install.sfs" -delete 2>/dev/null || true
  fi
}

# Function to download files using aria2c
download_with_aria2() {
  local file="$1"
  echo "Downloading $file using aria2c..."
  aria2c -x 16 -s 16 "$RELEASE_URL/$file"
}

# Function to download files using wget
download_with_wget() {
  local file="$1"
  echo "Downloading $file using wget..."
  wget "$RELEASE_URL/$file"
}

# Function to extract grub-rescue.iso to the iso directory and delete the iso file
extract_grub_rescue_iso() {
  echo "Extracting grub-rescue.iso to iso directory..."
  mkdir -p iso
  # Extract the contents of the ISO into the "iso" folder
  7z x grub-rescue.iso -oiso
  # Restore backup of install.sfs if needed
  if [[ -f "install.sfs.bak" ]]; then
    mv -f "install.sfs.bak" "iso/install.sfs"
  fi
  # Delete the ISO after extracting
  rm -f grub-rescue.iso
}

# Function to extract initrd_lib.tar.gz and move the content to the initrd folder
extract_initrd_lib() {
  echo "Extracting initrd_lib.tar.gz..."
  tar -xzf initrd_lib.tar.gz
  echo "Setting permissions for initrd_lib..."
  chmod -R 755 initrd_lib/*
  # Remove the extracted tar.gz file
  rm -f initrd_lib.tar.gz
}

# Function to display the help message
show_help() {
  cat << EOF
Copyright (C) 2026 BlissLabs

Usage: ./download.sh [OPTION]

Options:
  --initrd-only    Download and extract only the initrd_lib.tar.gz file.
  --help           Show this help message and exit.
EOF
}

# Handle the command line argument using a case statement
case "$1" in
  --help)
    show_help
    ;;

  --initrd-only)
    # Check the version first
    check_version

    # Remove existing files before starting the download
    remove_existing_files

    # Download only initrd_lib.tar.gz
    if command -v aria2c &> /dev/null; then
      download_with_aria2 "initrd_lib.tar.gz"
    else
      download_with_wget "initrd_lib.tar.gz"
    fi

    extract_initrd_lib

    # Save the new version
    update_version
    echo "Script execution complete!"
    ;;

  *)
    # Check the version first
    check_version

    # Remove existing files before starting the download
    remove_existing_files

    # Check if aria2c is installed
    if command -v aria2c &> /dev/null; then
      echo "aria2c found, using aria2c for download."
      for FILE in "${FILES[@]}"; do
        download_with_aria2 "$FILE"
      done
    else
      echo "aria2c not found, falling back to wget."
      for FILE in "${FILES[@]}"; do
        download_with_wget "$FILE"
      done
    fi

    # Process the downloaded files
    extract_grub_rescue_iso
    extract_initrd_lib

    # Save the new version
    update_version
    echo "Script execution complete!"
    ;;
esac
exit 0
