#!/bin/bash

echo "args are: out dir name, min_len, max_len, count"
out_dir="out/$1/"
mkdir -p "$out_dir"

trim-n-times --in=src --out "$out_dir" --black=/tmp --black-prob=0 --min-len=$2 --max-len=$3 --count=$4
