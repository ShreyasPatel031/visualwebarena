#!/bin/bash
# Run all 910 VisualWebArena tasks with Gemini
# This script sets up environment, resets between tasks, and tracks costs

set -e

# Configuration
VM_IP="${VM_IP:-34.66.226.4}"
RESULT_DIR="${RESULT_DIR:-/tmp/vwa_gemini_baseline}"
MAX_STEPS="${MAX_STEPS:-30}"
COST_LOG="${COST_LOG:-/tmp/gemini_cost.log}"

# Export environment variables
export DATASET=visualwebarena
export CLASSIFIEDS="http://${VM_IP}:9980"
export CLASSIFIEDS_RESET_TOKEN="4b61655535e7ed388f0d40a93600254c"
export SHOPPING="http://${VM_IP}:7770"
export REDDIT="http://${VM_IP}:9999"
export WIKIPEDIA="http://${VM_IP}:8888"
export HOMEPAGE="http://${VM_IP}:4399"
export GEMINI_COST_LOG="${COST_LOG}"

echo "=========================================="
echo "VisualWebArena Full Evaluation with Gemini"
echo "=========================================="
echo "VM IP: ${VM_IP}"
echo "Result directory: ${RESULT_DIR}"
echo "Max steps: ${MAX_STEPS}"
echo "Cost log: ${COST_LOG}"
echo "Total tasks: 910 (234 classifieds + 466 shopping + 210 reddit)"
echo ""

# Clear previous results and cost log
echo "Clearing previous results..."
rm -rf "${RESULT_DIR}"
rm -f "${COST_LOG}"
mkdir -p "${RESULT_DIR}"
touch "${COST_LOG}"
echo "✓ Previous results cleared"
echo ""

# Verify Google Cloud authentication
echo "Verifying Google Cloud authentication..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "ERROR: No active Google Cloud authentication found"
    echo "Run: gcloud auth login && gcloud config set project <your-project>"
    exit 1
fi

PROJECT=$(gcloud config get-value project 2>/dev/null)
echo "✓ Authenticated to project: ${PROJECT}"
echo ""

# Verify VM services are accessible
echo "Verifying VM services are accessible..."
ALL_ACCESSIBLE=true
for service in "${CLASSIFIEDS}" "${SHOPPING}" "${REDDIT}" "${WIKIPEDIA}" "${HOMEPAGE}"; do
    if curl -s --max-time 5 "${service}" > /dev/null 2>&1; then
        echo "✓ ${service} is accessible"
    else
        echo "✗ ${service} is NOT accessible"
        ALL_ACCESSIBLE=false
    fi
done

if [ "$ALL_ACCESSIBLE" = false ]; then
    echo ""
    echo "WARNING: Some services are not accessible. Please check VM setup."
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# Function to calculate costs from log
calculate_costs() {
    if [ ! -f "${COST_LOG}" ]; then
        echo "No cost log found"
        return
    fi
    
    # Gemini pricing (approximate): $0.25/1M input chars, $0.50/1M output chars
    # Rough conversion: 1 token ≈ 4 characters
    local total_input_chars=0
    local total_output_chars=0
    
    while IFS=',' read -r input_chars output_chars; do
        total_input_chars=$((total_input_chars + input_chars))
        total_output_chars=$((total_output_chars + output_chars))
    done < "${COST_LOG}"
    
    local input_cost=$(echo "scale=4; $total_input_chars / 1000000 * 0.25" | bc)
    local output_cost=$(echo "scale=4; $total_output_chars / 1000000 * 0.50" | bc)
    local total_cost=$(echo "scale=2; $input_cost + $output_cost" | bc)
    
    echo "Cost Summary:"
    echo "  Input characters: ${total_input_chars:,}"
    echo "  Output characters: ${total_output_chars:,}"
    echo "  Input cost: \$${input_cost}"
    echo "  Output cost: \$${output_cost}"
    echo "  TOTAL COST: \$${total_cost}"
}

# Function to run evaluation for a category
run_category() {
    local category=$1
    local category_dir=$2
    local start_idx=$3
    local end_idx=$4
    
    echo "=========================================="
    echo "Running ${category} tasks (${start_idx} to ${end_idx})"
    echo "=========================================="
    echo "Start time: $(date)"
    
    python run.py \
      --instruction_path agent/prompts/jsons/p_cot_id_actree_3s.json \
      --test_start_idx "${start_idx}" \
      --test_end_idx "${end_idx}" \
      --result_dir "${RESULT_DIR}/${category}" \
      --test_config_base_dir "${category_dir}" \
      --provider google \
      --model gemini \
      --mode completion \
      --max_obs_length 15360 \
      --max_steps "${MAX_STEPS}" \
      --observation_type accessibility_tree \
      --temperature 1.0 \
      --top_p 0.9 \
      --max_tokens 384
    
    echo "End time: $(date)"
    echo "✓ ${category} evaluation complete"
    echo ""
}

# Trap to calculate costs on exit
trap 'echo ""; echo "=========================================="; calculate_costs; echo "=========================================="' EXIT

# Run all categories
echo "Starting evaluation..."
echo "This will run all 910 tasks. It may take several hours."
echo "Press Ctrl+C to stop (costs will be calculated on exit)"
echo ""

# Classifieds: 234 tasks (0-233)
run_category "classifieds" "config_files/vwa/test_classifieds" 0 234

# Shopping: 466 tasks (0-465)
run_category "shopping" "config_files/vwa/test_shopping" 0 466

# Reddit: 210 tasks (0-209)
run_category "reddit" "config_files/vwa/test_reddit" 0 210

echo "=========================================="
echo "All evaluations complete!"
echo "Results saved to: ${RESULT_DIR}"
echo "=========================================="
