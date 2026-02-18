#!/bin/bash

# Setup environment variables for VisualWebArena
# Usage: source setup_env.sh

export DATASET=visualwebarena
export CLASSIFIEDS="http://34.70.239.56:9980"
export CLASSIFIEDS_RESET_TOKEN="4b61655535e7ed388f0d40a93600254c"
export SHOPPING="http://34.70.239.56:7770"
export REDDIT="http://34.70.239.56:9999"
export WIKIPEDIA="http://34.70.239.56:8888"
export HOMEPAGE="http://34.70.239.56:4399"

echo "✓ Environment variables set:"
echo "  DATASET=$DATASET"
echo "  CLASSIFIEDS=$CLASSIFIEDS"
echo "  SHOPPING=$SHOPPING"
echo "  REDDIT=$REDDIT"
echo "  WIKIPEDIA=$WIKIPEDIA"
echo "  HOMEPAGE=$HOMEPAGE"
echo ""
echo "To make these permanent, add them to your ~/.zshrc or ~/.bashrc"
