#!/bin/bash
set -euo pipefail

# Master orchestrator for Path B: submits all 20 τ-trait experiments using
# local Qwen3-32B as user model (3x A100 per job).
#
# 4 domains × (1 baseline + 4 traits) × 5 trials = 100 total runs
#
# Usage:
#   ./run_all_tau_trait_8b_pathb.sh              # submit all 20 jobs
#   ./run_all_tau_trait_8b_pathb.sh --dry-run    # print commands only

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SBATCH_SCRIPT="${SCRIPT_DIR}/sbatch_tau_trait_8b_pathb.sh"

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
    echo "DRY RUN MODE — commands will be printed but NOT submitted"
    echo ""
fi

# ── Experiment matrix ────────────────────────────────────────────────────
DOMAINS=(airline retail telecom telehealth)
TRAITS=(baseline skeptical confused impatient incoherent)
NUM_TRIALS=5

echo "============================================"
echo "τ-trait Full Experiment Submission (PATH B)"
echo "  User model: Qwen3-32B (local, 3x A100)"
echo "============================================"
echo "Domains:  ${DOMAINS[*]}"
echo "Traits:   ${TRAITS[*]}"
echo "Trials:   ${NUM_TRIALS}"
echo "Total:    $(( ${#DOMAINS[@]} * ${#TRAITS[@]} )) jobs"
echo "GPUs/job: 3x A100"
echo "Script:   ${SBATCH_SCRIPT}"
echo "============================================"
echo ""

# ── Validate ─────────────────────────────────────────────────────────────
if [ ! -f "${SBATCH_SCRIPT}" ]; then
    echo "ERROR: sbatch script not found at ${SBATCH_SCRIPT}"
    exit 1
fi

# ── Submit jobs ──────────────────────────────────────────────────────────
job_count=0
job_ids=()

# Run baselines first, then traits
for trait in "${TRAITS[@]}"; do
    for domain in "${DOMAINS[@]}"; do
        job_count=$((job_count + 1))
        job_name="ttpb_${domain}_${trait}"

        printf "[%2d/20] %-12s × %-12s : " "${job_count}" "${domain}" "${trait}"

        if [ "${DRY_RUN}" = "true" ]; then
            echo "sbatch --export=ALL,DOMAIN=${domain},TRAIT=${trait},NUM_TRIALS=${NUM_TRIALS} -J ${job_name} ${SBATCH_SCRIPT}"
        else
            output=$(sbatch --export=ALL,DOMAIN="${domain}",TRAIT="${trait}",NUM_TRIALS="${NUM_TRIALS}" \
                -J "${job_name}" "${SBATCH_SCRIPT}" 2>&1)
            job_id=$(echo "${output}" | awk '{print $NF}')
            job_ids+=("${job_id}")
            echo "Submitted (Job ID: ${job_id})"
        fi
    done
done

echo ""
echo "============================================"
if [ "${DRY_RUN}" = "true" ]; then
    echo "DRY RUN: ${job_count} commands printed (nothing submitted)"
else
    echo "Submitted ${job_count} jobs! (Path B: 3x A100 each)"
    echo ""
    echo "Monitor with:"
    echo "  squeue -u \$USER"
    echo "  watch -n 30 'squeue -u \$USER -o \"%.10i %.25j %.2t %.10M %R\"'"
    echo ""
    echo "Cancel all pending:"
    echo "  scancel -u \$USER --state=PENDING"
    echo ""
    echo "Check results:"
    echo "  ls /scratch/ckurian/tau-trait/results/fc_*_8b*/"
fi
echo "============================================"