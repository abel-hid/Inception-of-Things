#!/bin/bash

echo "🚀 Configuring Vagrant + VirtualBox to use goinfre only..."

# === PATHS ===
GOINFRE="$HOME/goinfre"
VAGRANT_HOME_PATH="$GOINFRE/.vagrant.d"
VB_VM_PATH="$GOINFRE/VirtualBoxVMs"

# === CREATE DIRECTORIES ===
mkdir -p "$VAGRANT_HOME_PATH"
mkdir -p "$VB_VM_PATH"

# === SET VAGRANT HOME (current session) ===
export VAGRANT_HOME="$VAGRANT_HOME_PATH"

echo "✅ VAGRANT_HOME set to: $VAGRANT_HOME_PATH"

# === PERSIST VAGRANT HOME ===
if ! grep -q "VAGRANT_HOME" "$HOME/.zshrc"; then
    echo 'export VAGRANT_HOME=$HOME/goinfre/.vagrant.d' >> "$HOME/.zshrc"
    echo "✅ Added VAGRANT_HOME to ~/.zshrc"
else
    echo "ℹ️ VAGRANT_HOME already exists in ~/.zshrc"
fi

# === SET VIRTUALBOX DEFAULT MACHINE FOLDER ===
VBoxManage setproperty machinefolder "$VB_VM_PATH"

echo "✅ VirtualBox VM folder set to: $VB_VM_PATH"

# === CLEAN OLD LOCAL VM STATE (safe reset) ===
echo "🧹 Cleaning local Vagrant state..."
rm -rf ~/.vagrant.d
rm -rf .vagrant

# === REMOVE OLD DEFAULT VIRTUALBOX VMS (if exists) ===
if [ -d "$HOME/VirtualBox VMs" ]; then
    echo "⚠️ Removing old VirtualBox VMs folder..."
    rm -rf "$HOME/VirtualBox VMs"
fi

# === VERIFY ===
echo "🔍 Verification:"
echo "VAGRANT_HOME = $VAGRANT_HOME"
VBoxManage list systemproperties | grep "Default machine folder"

echo "🎉 Setup complete! Everything now uses goinfre."