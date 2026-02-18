#!/bin/bash
# Setup script following official VisualWebArena README
# https://github.com/web-arena-x/visualwebarena/blob/main/environment_docker/README.md
# Run this ON your GCP VM

set -e

VM_IP="${1:-34.70.239.56}"

echo "========================================="
echo "VisualWebArena Setup (Official)"
echo "========================================="
echo "VM IP: $VM_IP"
echo ""

# Step 1: Verify firewall rules (ports accessible)
echo "=== Step 1: Verifying Firewall Rules ==="
REQUIRED_PORTS=(7770 9999 8888 9980 4399)
ALL_PORTS_OPEN=true

for port in "${REQUIRED_PORTS[@]}"; do
    # Check if port is listening locally
    if ss -tuln 2>/dev/null | grep -q ":$port " || netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo "✓ Port $port is listening locally"
    else
        echo "⚠ Port $port is NOT listening locally (service may not be running)"
    fi
    
    # Try to verify external accessibility (requires curl from external source)
    # Note: This is a basic check - full verification needs external test
    echo "  Note: Full firewall verification requires testing from external machine"
done

echo ""
echo "To verify firewall from local machine, run:"
echo "  for port in 7770 9999 8888 9980 4399; do curl -I --max-time 3 http://$VM_IP:\$port 2>&1 | head -1; done"
echo ""

# Step 2: Verify VM instance exists
echo "=== Step 2: Verifying VM Instance ==="
VM_NAME=$(hostname)
if [ -n "$VM_NAME" ]; then
    echo "✓ VM hostname: $VM_NAME"
    # Try to get VM details via metadata service (works on GCP)
    VM_ZONE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone 2>/dev/null | awk -F'/' '{print $NF}' || echo "unknown")
    VM_MACHINE_TYPE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/machine-type 2>/dev/null | awk -F'/' '{print $NF}' || echo "unknown")
    if [ "$VM_ZONE" != "unknown" ]; then
        echo "✓ VM zone: $VM_ZONE"
        echo "✓ VM machine type: $VM_MACHINE_TYPE"
    else
        echo "⚠ Could not retrieve VM metadata (may not be on GCP or metadata service unavailable)"
    fi
else
    echo "⚠ Could not determine VM hostname"
fi
echo ""

# Step 3: Verify External IP
echo "=== Step 3: Verifying External IP ==="
CURRENT_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null || echo "")
if [ -n "$CURRENT_IP" ]; then
    echo "✓ Current external IP: $CURRENT_IP"
    if [ "$CURRENT_IP" != "$VM_IP" ]; then
        echo "⚠ WARNING: External IP has changed!"
        echo "  Expected: $VM_IP"
        echo "  Current:  $CURRENT_IP"
        echo "  Update your environment variables and configuration files."
    else
        echo "✓ External IP matches expected: $VM_IP"
    fi
else
    echo "⚠ Could not retrieve external IP from metadata service"
    echo "  Using provided IP: $VM_IP"
    echo "  Note: IP may have changed if VM was stopped/restarted"
fi
echo ""

# Step 4: Start all containers
echo "=== Step 4: Starting Docker Containers ==="
echo "Starting VWA containers (per README):"
echo "  - shopping"
echo "  - forum"
echo "  - kiwix33 (Wikipedia)"
echo "  - classifieds (from docker-compose)"
echo ""

docker start shopping || echo "⚠ shopping container not found"
docker start forum || echo "⚠ forum container not found"
docker start kiwix33 || echo "⚠ kiwix33 container not found, trying wikipedia..." && docker start wikipedia || echo "⚠ Neither kiwix33 nor wikipedia container found"

if [ -d "classifieds_docker_compose" ]; then
    cd classifieds_docker_compose
    docker compose up -d || echo "⚠ classifieds compose failed"
    cd ..
else
    echo "⚠ classifieds_docker_compose directory not found"
fi

echo "⏳ Waiting 60 seconds for services to start..."
sleep 60
echo ""

# Verify all containers are running
echo "=== Step 4b: Verifying Required VWA Containers Are Running ==="
echo "Required for VWA (per README): shopping, forum, kiwix33, classifieds"
echo ""
ALL_RUNNING=true

# Check shopping
if docker ps --format "{{.Names}}" | grep -q "^shopping$"; then
    echo "✓ shopping container is running"
else
    echo "✗ shopping container is NOT running (REQUIRED)"
    ALL_RUNNING=false
fi

# Check forum
if docker ps --format "{{.Names}}" | grep -q "^forum$"; then
    echo "✓ forum container is running"
else
    echo "✗ forum container is NOT running (REQUIRED)"
    ALL_RUNNING=false
fi

# Check kiwix33 (Wikipedia) - README says kiwix33, but some setups use "wikipedia"
if docker ps --format "{{.Names}}" | grep -q "^kiwix33$"; then
    echo "✓ kiwix33 container is running (correct per README)"
elif docker ps --format "{{.Names}}" | grep -q "^wikipedia$"; then
    echo "⚠ wikipedia container is running (README expects 'kiwix33', but 'wikipedia' is acceptable)"
else
    echo "✗ kiwix33/wikipedia container is NOT running (REQUIRED)"
    ALL_RUNNING=false
fi

# Check classifieds (both classifieds and classifieds_db)
CLASSIFIEDS_COUNT=$(docker ps --format "{{.Names}}" | grep -c "classifieds" || echo "0")
if [ "$CLASSIFIEDS_COUNT" -ge 1 ]; then
    CLASSIFIEDS_CONTAINERS=$(docker ps --format "{{.Names}}" | grep "classifieds")
    echo "✓ classifieds containers are running ($CLASSIFIEDS_COUNT found):"
    echo "$CLASSIFIEDS_CONTAINERS" | sed 's/^/  - /'
    # Specifically check for classifieds_db
    if docker ps --format "{{.Names}}" | grep -q "^classifieds_db$"; then
        echo "  ✓ classifieds_db is running"
    else
        echo "  ⚠ classifieds_db is NOT running (needed for database)"
    fi
else
    echo "✗ classifieds containers are NOT running"
    ALL_RUNNING=false
fi

# Check for extra containers that shouldn't be running for VWA
echo ""
echo "Checking for extra containers (WebArena containers that shouldn't be running for VWA):"
EXTRA_CONTAINERS=("shopping_admin" "gitlab" "tile" "nominatim" "osrm")
HAS_EXTRA=false
for container in "${EXTRA_CONTAINERS[@]}"; do
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        echo "⚠ $container is running (this is for WebArena, not VWA)"
        HAS_EXTRA=true
    fi
done
if [ "$HAS_EXTRA" = false ]; then
    echo "✓ No extra WebArena containers running"
fi

if [ "$ALL_RUNNING" = false ]; then
    echo ""
    echo "✗ WARNING: Some required VWA containers are not running. Please check and restart them."
    echo "  Run: docker ps -a to see all containers"
else
    echo ""
    echo "✓ All required VWA containers are running"
fi
echo ""

# Step 5: Populate Classifieds DB
echo "=== Step 5: Populating Classifieds Database ==="
if docker ps --format "{{.Names}}" | grep -q "classifieds_db"; then
    docker exec classifieds_db mysql -u root -ppassword osclass -e 'source docker-entrypoint-initdb.d/osclass_craigslist.sql' 2>/dev/null || echo "⚠ DB may already be populated or SQL file missing"
    echo "✓ Classifieds DB populated"
else
    echo "⚠ classifieds_db container not running"
fi
echo ""

# Step 6: Configure Shopping base URL
echo "=== Step 6: Configuring Shopping Base URL ==="
docker exec shopping /var/www/magento2/bin/magento setup:store-config:set --base-url="http://$VM_IP:7770"
docker exec shopping mysql -u magentouser -pMyPassword magentodb -e "UPDATE core_config_data SET value='http://$VM_IP:7770/' WHERE path = 'web/secure/base_url';"
docker exec shopping /var/www/magento2/bin/magento cache:flush
echo "✓ Shopping base URL configured"
echo ""

# Step 7: Disable re-indexing (as per README)
echo "=== Step 7: Disabling Product Re-indexing ==="
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule catalogrule_product
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule catalogrule_rule
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule catalogsearch_fulltext
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule catalog_category_product
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule customer_grid
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule design_config_grid
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule inventory
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_category
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_attribute
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_price
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule cataloginventory_stock
echo "✓ Re-indexing disabled"
echo ""

# Step 8: Setup Homepage
echo "=== Step 8: Setting up Homepage ==="
if [ -d "webarena-homepage" ]; then
    cd webarena-homepage
    # Update hostname in index.html (per README)
    perl -pi -e "s|<your-server-hostname>|$VM_IP|g" templates/index.html 2>/dev/null || echo "⚠ Could not update templates/index.html"
    
    # Check if homepage is already running
    if ! pgrep -f "flask.*4399" > /dev/null; then
        echo "Starting homepage on port 4399..."
        nohup flask run --host=0.0.0.0 --port=4399 > /tmp/homepage.log 2>&1 &
        echo "✓ Homepage started (logs: /tmp/homepage.log)"
    else
        echo "✓ Homepage already running"
    fi
    cd ..
else
    echo "⚠ webarena-homepage directory not found"
    echo "  You may need to clone/download it first"
fi
echo ""

# Summary
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Services should be available at:"
echo "  Shopping:    http://$VM_IP:7770"
echo "  Reddit:      http://$VM_IP:9999"
echo "  Wikipedia:   http://$VM_IP:8888"
echo "  Classifieds: http://$VM_IP:9980"
echo "  Homepage:    http://$VM_IP:4399"
echo ""
echo "Test from local machine:"
echo "  curl http://$VM_IP:7770"
echo "  curl http://$VM_IP:9999"
echo ""
