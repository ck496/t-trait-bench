#!/bin/bash
set -euo pipefail

# Submits 4 domain-sweep sbatch jobs (one per domain).
# Each job starts vLLM once and runs all 5 trait configs sequentially.
#
# Usage:
#   ./run_all_domains_pathb.sh              # submit all 4 jobs (general + h100)
#   ./run_all_domains_pathb.sh --dry-run    # print commands only
#   NUM_TRIALS=3 ./run_all_domains_pathb.sh # override trials
#
# Override partition/GPU (no script edits needed):
#   PARTITION=public GPU_GRES=gpu:a100:3 ./run_all_domains_pathb.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SBATCH_SCRIPT="${SCRIPT_DIR}/sbatch_domain_sweep_pathb.sh"

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
    echo "DRY RUN — commands printed, nothing submitted"
    echo ""
fi

DOMAINS=(airline retail telecom telehealth)
NUM_TRIALS="${NUM_TRIALS:-5}"
PARTITION="${PARTITION:-}"
GPU_GRES="${GPU_GRES:-}"

echo "============================================"
echo "τ-trait: Submit 4 Domain Sweep Jobs (Path B)"
echo "============================================"
echo "Domains:    ${DOMAINS[*]}"
echo "Traits/job: baseline skeptical confused impatient incoherent"
echo "Trials:     ${NUM_TRIALS}"
echo "Partition:  ${PARTITION:-general (default in script)}"
echo "GPU GRES:   ${GPU_GRES:-gpu:h100:3 (default in script)}"
echo "Walltime:   8 hours per job"
echo "Script:     ${SBATCH_SCRIPT}"
echo "============================================"
echo ""

if [ ! -f "${SBATCH_SCRIPT}" ]; then
    echo "ERROR: ${SBATCH_SCRIPT} not found"
    exit 1
fi

job_count=0
for domain in "${DOMAINS[@]}"; do
    job_count=$((job_count + 1))
    job_name="sweep_${domain}"

    printf "[%d/4] %-12s : " "${job_count}" "${domain}"

    # Build optional overrides for partition/GPU
    SBATCH_OVERRIDES=()
    [ -n "${PARTITION}" ] && SBATCH_OVERRIDES+=(--partition="${PARTITION}")
    [ -n "${GPU_GRES}" ] && SBATCH_OVERRIDES+=(--gres="${GPU_GRES}")

    if [ "${DRY_RUN}" = "true" ]; then
        echo "sbatch ${SBATCH_OVERRIDES[*]+"${SBATCH_OVERRIDES[*]}"} --export=ALL,DOMAIN=${domain},NUM_TRIALS=${NUM_TRIALS} -J ${job_name} ${SBATCH_SCRIPT}"
    else
        output=$(sbatch ${SBATCH_OVERRIDES[@]+"${SBATCH_OVERRIDES[@]}"} \
            --export=ALL,DOMAIN="${domain}",NUM_TRIALS="${NUM_TRIALS}" \
            -J "${job_name}" "${SBATCH_SCRIPT}" 2>&1)
        job_id=$(echo "${output}" | awk '{print $NF}')
        echo "Submitted (Job ID: ${job_id})"
    fi
done

echo ""
if [ "${DRY_RUN}" = "true" ]; then
    echo "DRY RUN: ${job_count} commands printed"
else
    echo "Submitted ${job_count} jobs!"
    echo ""
    echo "Monitor:  squeue -u \$USER"
    echo "Cancel:   scancel -u \$USER --state=PENDING"
    echo "Results:  ls /scratch/ckurian/tau-trait/results/fc_*_8b*/"
fi