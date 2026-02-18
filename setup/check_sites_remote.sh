#!/bin/bash

# Script to check Docker containers and services on the remote VM
# This should be run ON the GCP VM itself (via SSH)
# Usage: ssh into your VM and run this script

echo "========================================="
echo "VisualWebArena Docker Container Check"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is installed and running
echo "=== Docker Status ==="
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Docker is installed${NC}"
    if docker ps &> /dev/null; then
        echo -e "${GREEN}✓ Docker daemon is running${NC}"
    else
        echo -e "${RED}✗ Docker daemon is not running${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Docker is not installed${NC}"
    exit 1
fi
echo ""

# Check running containers
echo "=== Running Containers ==="
containers=("shopping" "forum" "wikipedia" "classifieds_db" "classifieds_web" "classifieds_php")
all_running=true

for container in "${containers[@]}"; do
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        status=$(docker ps --format "{{.Status}}" --filter "name=^${container}$")
        echo -e "${GREEN}✓${NC} $container: $status"
    else
        echo -e "${RED}✗${NC} $container: NOT RUNNING"
        all_running=false
    fi
done
echo ""

# Check container ports
echo "=== Container Port Mappings ==="
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "NAMES|shopping|forum|wikipedia|classifieds"
echo ""

# Check if services are listening
echo "=== Listening Ports ==="
ports=(7770 9999 8888 9980 4399)
for port in "${ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}✓${NC} Port $port is listening"
    else
        echo -e "${RED}✗${NC} Port $port is NOT listening"
    fi
done
echo ""

# Check container logs for errors (last 5 lines)
echo "=== Recent Container Logs (checking for errors) ==="
for container in "${containers[@]}"; do
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        errors=$(docker logs --tail 5 "$container" 2>&1 | grep -i "error\|fatal\|exception" | head -3)
        if [ -n "$errors" ]; then
            echo -e "${YELLOW}⚠${NC} $container has recent errors:"
            echo "$errors" | sed 's/^/  /'
        fi
    fi
done
echo ""

# Check classifieds database
echo "=== Classifieds Database Check ==="
if docker ps --format "{{.Names}}" | grep -q "classifieds_db"; then
    table_count=$(docker exec classifieds_db mysql -u root -ppassword osclass -e "SHOW TABLES;" 2>/dev/null | wc -l)
    if [ "$table_count" -gt 1 ]; then
        echo -e "${GREEN}✓${NC} Classifieds database has tables ($((table_count-1)) tables)"
    else
        echo -e "${YELLOW}⚠${NC} Classifieds database may be empty (run the SQL import)"
    fi
else
    echo -e "${RED}✗${NC} Classifieds database container not running"
fi
echo ""

# Summary
echo "=== Summary ==="
if [ "$all_running" = true ]; then
    echo -e "${GREEN}All containers appear to be running!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Test from your local machine: ./check_sites.sh <your-vm-ip>"
    echo "2. Make sure GCP firewall rules allow traffic on ports: 7770, 9999, 8888, 9980, 4399"
else
    echo -e "${YELLOW}Some containers are not running.${NC}"
    echo "To start VisualWebArena containers, run:"
    echo "  docker start shopping"
    echo "  docker start forum"
    echo "  docker start wikipedia"
    echo "  cd classifieds_docker_compose && docker compose up -d"
fi
