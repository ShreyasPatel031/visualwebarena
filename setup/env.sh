#!/bin/bash
# Source this file to set environment variables
# Usage: source setup/env.sh
# Based on official VisualWebArena setup

VM_IP="${VM_IP:-34.66.226.4}"

export DATASET=visualwebarena
export CLASSIFIEDS="http://${VM_IP}:9980"
export CLASSIFIEDS_RESET_TOKEN="4b61655535e7ed388f0d40a93600254c"
export SHOPPING="http://${VM_IP}:7770"
export REDDIT="http://${VM_IP}:9999"
export WIKIPEDIA="http://${VM_IP}:8888"
export HOMEPAGE="http://${VM_IP}:4399"
