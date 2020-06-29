#!/bin/bash

configdir="$1/config"
mkdir -p "$configdir"

# create test folder structure in configdir
torrcd="$configdir/torrc.d"
mkdir -p "$torrcd"
mkdir -p "$torrcd/folder"
mkdir -p "$torrcd/empty_folder"
echo "NodeFamily 1" > "$torrcd/01_one.conf"
echo "NodeFamily 2" > "$torrcd/02_two.conf"
echo "NodeFamily 3" > "$torrcd/aa_three.conf"
echo "NodeFamily 6" > "$torrcd/.hidden.conf"
touch "$torrcd/empty.conf"
echo "# comment" > "$torrcd/comment.conf"
echo "NodeFamily 4" > "$torrcd/folder/04_four.conf"
echo "NodeFamily 5" > "$torrcd/folder/05_five.conf"
torrc="$configdir/torrc"
echo "Sandbox 1" > "$torrc"
echo "
%include $torrcd/
%include $torrcd/folder/04_four.conf
%include $torrcd/empty_folder
%include $torrcd/empty.conf
%include $torrcd/comment.conf
%include $torrcd/.hidden.conf
" >> "$torrc"
