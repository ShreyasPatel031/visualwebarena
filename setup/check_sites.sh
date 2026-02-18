#!/bin/bash

# Script to check if VisualWebArena sites are properly set up
# Usage: ./check_sites.sh <your-server-hostname-or-ip>

SERVER_HOST="${1:-34.70.239.56}"

echo "========================================="
echo "VisualWebArena Site Health Check"
echo "========================================="
echo "Server: $SERVER_HOST"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a URL is accessible
check_url() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    
    echo -n "Checking $name ($url)... "
    
    # Use curl with timeout
    response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null)
    
    if [ "$response" = "$expected_status" ] || [ "$response" = "000" ]; then
        if [ "$response" = "$expected_status" ]; then
            echo -e "${GREEN}✓ OK${NC} (HTTP $response)"
            return 0
        else
            echo -e "${RED}✗ FAILED${NC} (Connection timeout/refused)"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ WARNING${NC} (HTTP $response, expected $expected_status)"
        return 1
    fi
}

# Function to check if port is open
check_port() {
    local name=$1
    local port=$2
    
    echo -n "Checking $name port $port... "
    
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$SERVER_HOST/$port" 2>/dev/null; then
        echo -e "${GREEN}✓ OPEN${NC}"
        return 0
    else
        echo -e "${RED}✗ CLOSED${NC}"
        return 1
    fi
}

echo "=== Port Connectivity Check ==="
check_port "Shopping" 7770
check_port "Reddit/Forum" 9999
check_port "Wikipedia" 8888
check_port "Classifieds" 9980
check_port "Homepage" 4399
echo ""

echo "=== Website Accessibility Check ==="
check_url "Shopping" "http://$SERVER_HOST:7770"
check_url "Reddit/Forum" "http://$SERVER_HOST:9999"
check_url "Wikipedia" "http://$SERVER_HOST:8888/wikipedia_en_all_maxi_2022-05/A/User:The_other_Kiwix_guy/Landing"
check_url "Classifieds" "http://$SERVER_HOST:9980"
check_url "Homepage" "http://$SERVER_HOST:4399"
echo ""

echo "=== Summary ==="
echo "If all checks pass, you can set these environment variables:"
echo ""
echo "export DATASET=visualwebarena"
echo "export CLASSIFIEDS=\"http://$SERVER_HOST:9980\""
echo "export CLASSIFIEDS_RESET_TOKEN=\"4b61655535e7ed388f0d40a93600254c\""
echo "export SHOPPING=\"http://$SERVER_HOST:7770\""
echo "export REDDIT=\"http://$SERVER_HOST:9999\""
echo "export WIKIPEDIA=\"http://$SERVER_HOST:8888\""
echo "export HOMEPAGE=\"http://$SERVER_HOST:4399\""
echo ""
