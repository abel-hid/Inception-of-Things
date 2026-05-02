#!/bin/bash

# === CONFIG ===
GOINFRE="$HOME/goinfre"
VAGRANT_HOME_PATH="$GOINFRE/.vagrant.d"
VB_VM_PATH="$GOINFRE/VirtualBoxVMs"

echo "🚀 Setting up Vagrant + VirtualBox to use goinfre..."

# === CREATE DIRECTORIES ===
mkdir -p "$VAGRANT_HOME_PATH"
mkdir -p "$VB_VM_PATH"

# === EXPORT VAGRANT HOME ===
export VAGRANT_HOME="$VAGRANT_HOME_PATH"

# Persist in zshrc if not already there
if ! grep -q "VAGRANT_HOME" "$HOME/.zshrc"; then
    echo 'export VAGRANT_HOME=$HOME/goinfre/.vagrant.d' >> "$HOME/.zshrc"
    echo "✅ Added VAGRANT_HOME to ~/.zshrc"
fi

# === SET VIRTUALBOX MACHINE FOLDER ===
VBoxManage setproperty machinefolder "$VB_VM_PATH"
echo "✅ VirtualBox machine folder set to $VB_VM_PATH"

# === CLEAN OLD STATE ===
echo "🧹 Cleaning old Vagrant state..."
rm -rf .vagrant

# Optional: remove old default VirtualBox VMs
if [ -d "$HOME/VirtualBox VMs" ]; then
    echo "⚠️ Removing old VirtualBox VMs folder..."
    rm -rf "$HOME/VirtualBox VMs"
fi

# === VERIFY SETTINGS ===
echo "🔍 Verifying setup..."
echo "VAGRANT_HOME = $VAGRANT_HOME"
VBoxManage list systemproperties | grep "Default machine folder"

# === RUN VAGRANT ===
echo "🚀 Starting Vagrant in current directory..."
vagrant up

echo "✅ Done!"