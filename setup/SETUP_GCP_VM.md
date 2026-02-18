# VisualWebArena GCP VM Setup Guide

## Your VM Details
- **External IP**: 34.70.239.56
- **Internal IP**: 10.128.0.69
- **Zone**: us-central1-a

## Step 1: Check Docker Containers on VM

SSH into your GCP VM and run the remote check script:

```bash
# Copy the check script to your VM
scp check_sites_remote.sh <your-username>@34.70.239.56:~/

# SSH into the VM
ssh <your-username>@34.70.239.56

# Run the check script
chmod +x check_sites_remote.sh
./check_sites_remote.sh
```

Or manually check:

```bash
# Check running containers
docker ps

# Check specific containers
docker ps | grep -E "shopping|forum|wikipedia|classifieds"

# Check if ports are listening
sudo netstat -tuln | grep -E "7770|9999|8888|9980|4399"
```

## Step 2: Configure GCP Firewall Rules

Your GCP VM needs firewall rules to allow inbound traffic on these ports:

**Required Ports:**
- 7770 (Shopping)
- 9999 (Reddit/Forum)
- 8888 (Wikipedia)
- 9980 (Classifieds)
- 4399 (Homepage)

### Create Firewall Rules via gcloud CLI:

```bash
# Create firewall rule for VisualWebArena ports
gcloud compute firewall-rules create visualwebarena-ports \
    --allow tcp:7770,tcp:9999,tcp:8888,tcp:9980,tcp:4399 \
    --source-ranges 0.0.0.0/0 \
    --description "VisualWebArena website ports" \
    --target-tags visualwebarena

# Apply the tag to your VM
gcloud compute instances add-tags webarena \
    --tags visualwebarena \
    --zone us-central1-a
```

### Or via GCP Console:
1. Go to **VPC Network** → **Firewall**
2. Click **Create Firewall Rule**
3. Name: `visualwebarena-ports`
4. Direction: **Ingress**
5. Targets: **All instances in the network** (or specific tags)
6. Source IP ranges: `0.0.0.0/0` (or restrict to your IP)
7. Protocols and ports: **Specified protocols and ports** → **TCP** → `7770,9999,8888,9980,4399`
8. Click **Create**

## Step 3: Start Services on VM (if not running)

SSH into your VM and start the containers:

```bash
# Start VisualWebArena containers
docker start shopping
docker start forum
docker start wikipedia

# For Classifieds (if using docker-compose)
cd classifieds_docker_compose
docker compose up -d

# Check all are running
docker ps
```

## Step 4: Test Connectivity from Local Machine

From your local machine (where you have the codebase):

```bash
# Run the health check script
./check_sites.sh 34.70.239.56

# Or test manually
curl -I http://34.70.239.56:7770      # Shopping
curl -I http://34.70.239.56:9999       # Reddit
curl -I http://34.70.239.56:8888       # Wikipedia
curl -I http://34.70.239.56:9980       # Classifieds
curl -I http://34.70.239.56:4399       # Homepage
```

## Step 5: Set Environment Variables

Once all sites are accessible, set these in your local shell or add to `~/.bashrc`/`~/.zshrc`:

```bash
export DATASET=visualwebarena
export CLASSIFIEDS="http://34.70.239.56:9980"
export CLASSIFIEDS_RESET_TOKEN="4b61655535e7ed388f0d40a93600254c"
export SHOPPING="http://34.70.239.56:7770"
export REDDIT="http://34.70.239.56:9999"
export WIKIPEDIA="http://34.70.239.56:8888"
export HOMEPAGE="http://34.70.239.56:4399"
```

## Step 6: Verify Setup

Test that the environment variables work:

```bash
# Verify environment variables
python -c "
import os
print('DATASET:', os.environ.get('DATASET'))
print('SHOPPING:', os.environ.get('SHOPPING'))
print('REDDIT:', os.environ.get('REDDIT'))
print('WIKIPEDIA:', os.environ.get('WIKIPEDIA'))
print('CLASSIFIEDS:', os.environ.get('CLASSIFIEDS'))
"

# Try importing the modules (should work now)
python -c "from browser_env import ScriptBrowserEnv; print('✓ Import successful!')"
```

## Troubleshooting

### Ports not accessible from outside:
1. Check GCP firewall rules (see Step 2)
2. Check if VM has external IP assigned
3. Verify containers are running: `docker ps` on VM
4. Check if services are listening: `netstat -tuln` on VM

### Containers not running:
```bash
# Check container status
docker ps -a

# Check container logs
docker logs shopping
docker logs forum
docker logs wikipedia

# Restart containers
docker restart shopping forum wikipedia
```

### Classifieds not working:
```bash
# Check if database is populated
docker exec classifieds_db mysql -u root -ppassword osclass -e "SHOW TABLES;"

# If empty, populate it
docker exec classifieds_db mysql -u root -ppassword osclass -e 'source docker-entrypoint-initdb.d/osclass_craigslist.sql'
```

## Quick Health Check Commands

**On VM:**
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**From Local:**
```bash
./check_sites.sh 34.70.239.56
```
