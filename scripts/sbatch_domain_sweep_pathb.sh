#!/bin/bash
#SBATCH --partition=public
#SBATCH --qos=class
#SBATCH -t 0-08:00:00
#SBATCH -c 16
#SBATCH --mem=80GB
#SBATCH --gres=gpu:a100:3
#SBATCH -J ttrait_sweep
#SBATCH -o /scratch/ckurian/tau-trait/logs/slurm/sweep_%j.out
#SBATCH -e /scratch/ckurian/tau-trait/logs/slurm/sweep_%j.err

set -euo pipefail

# Domain sweep: runs ALL 5 configs (baseline + 4 traits) for one domain
# in a single SLURM job. Starts vLLM once, runs experiments sequentially.
#
# Usage:
#   sbatch --export=ALL,DOMAIN=airline scripts/sbatch_domain_sweep_pathb.sh
#   sbatch --export=ALL,DOMAIN=retail,NUM_TRIALS=3 scripts/sbatch_domain_sweep_pathb.sh

mkdir -p /scratch/ckurian/tau-trait/logs/slurm /scratch/ckurian/tau-trait/logs/vllm

# ── Defaults ─────────────────────────────────────────────────────────────
SCRIPT_DIR="/scratch/ckurian/tau-trait/scripts"
PID_FILE="/scratch/ckurian/tau-trait/logs/vllm/pids_sweep_${SLURM_JOB_ID:-$$}.txt"

DOMAIN="${DOMAIN:?ERROR: DOMAIN not set. Use --export=ALL,DOMAIN=airline}"
NUM_TRIALS="${NUM_TRIALS:-5}"
PORT_AGENT="${PORT_AGENT:-8005}"
PORT_USER="${PORT_USER:-8006}"
MAX_CONCURRENCY="${MAX_CONCURRENCY:-1}"

TRAITS=(baseline skeptical confused impatient incoherent)

# ── Cleanup trap ─────────────────────────────────────────────────────────
cleanup() {
    echo ""
    echo "[$(date '+%H:%M:%S')] Cleaning up..."
    if [ -f "${PID_FILE}" ]; then
        while read -r pid; do
            kill "${pid}" 2>/dev/null && echo "  Killed PID ${pid}" || true
        done < "${PID_FILE}"
        rm -f "${PID_FILE}"
    fi
    echo "Cleanup complete."
}
trap cleanup EXIT

# ── Job info ─────────────────────────────────────────────────────────────
echo "============================================"
echo "τ-trait Domain Sweep (Path B)"
echo "============================================"
echo "SLURM Job:  ${SLURM_JOB_ID:-N/A}"
echo "Node:       $(hostname)"
echo "Domain:     ${DOMAIN}"
echo "Traits:     ${TRAITS[*]}"
echo "Trials:     ${NUM_TRIALS}"
echo "GPUs:       $(nvidia-smi -L 2>/dev/null | wc -l)"
echo "============================================"
echo ""

# ── Start both vLLM servers ─────────────────────────────────────────────
echo "[$(date '+%H:%M:%S')] Starting vLLM servers..."
PORT_AGENT="${PORT_AGENT}" \
PORT_USER="${PORT_USER}" \
PID_FILE="${PID_FILE}" \
    bash "${SCRIPT_DIR}/start_vllm_tau_trait_pathb.sh"

echo ""
echo "[$(date '+%H:%M:%S')] Both servers ready. Starting experiments."
echo ""

# ── Run all 5 configs sequentially ──────────────────────────────────────
SWEEP_START="$(date +%s)"
completed=0
failed=0

for trait in "${TRAITS[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[$(date '+%H:%M:%S')] Running: ${DOMAIN} × ${trait} (${NUM_TRIALS} trials)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if PORT_AGENT="${PORT_AGENT}" \
       PORT_USER="${PORT_USER}" \
       USE_STEER=false \
       MAX_CONCURRENCY="${MAX_CONCURRENCY}" \
       TAU_TRAIT_DIR="/scratch/ckurian/tau-trait" \
           bash "${SCRIPT_DIR}/run_tau_trait_8b.sh" "${DOMAIN}" "${trait}" "${NUM_TRIALS}"; then
        completed=$((completed + 1))
        echo "[$(date '+%H:%M:%S')] PASSED: ${DOMAIN} × ${trait}"
    else
        failed=$((failed + 1))
        echo "[$(date '+%H:%M:%S')] FAILED: ${DOMAIN} × ${trait} (continuing...)"
    fi
    echo ""
done

SWEEP_END="$(date +%s)"
SWEEP_DURATION=$(( (SWEEP_END - SWEEP_START) / 60 ))

echo "============================================"
echo "Domain Sweep Complete: ${DOMAIN}"
echo "  Completed: ${completed}/5"
echo "  Failed:    ${failed}/5"
echo "  Duration:  ${SWEEP_DURATION} min"
echo "  Results:   /scratch/ckurian/tau-trait/results/fc_${DOMAIN}_*_8b/"
echo "============================================"

# Exit with error if any experiment failed
[ "${failed}" -eq 0 ] || exit 1