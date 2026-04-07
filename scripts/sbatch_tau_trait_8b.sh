#!/bin/bash
#SBATCH --partition=public
#SBATCH --qos=class
#SBATCH -t 0-08:00:00
#SBATCH -c 8
#SBATCH --mem=40GB
#SBATCH --gres=gpu:a100:1
#SBATCH -J ttrait_8b
#SBATCH -o /scratch/ckurian/tau-trait/logs/slurm/ttrait_%j.out
#SBATCH -e /scratch/ckurian/tau-trait/logs/slurm/ttrait_%j.err

set -euo pipefail

# SLURM batch wrapper for τ-trait experiments.
# Starts vLLM server, runs experiment, cleans up on exit.
#
# Usage:
#   sbatch scripts/sbatch_tau_trait_8b.sh
#   sbatch --export=ALL,DOMAIN=airline,TRAIT=skeptical,NUM_TRIALS=5 scripts/sbatch_tau_trait_8b.sh
#   sbatch --export=ALL,DOMAIN=retail,TRAIT=baseline scripts/sbatch_tau_trait_8b.sh
#
# Environment variable overrides (via --export):
#   DOMAIN=airline          Domain to run
#   TRAIT=baseline          Trait to apply (or "baseline" for no trait)
#   NUM_TRIALS=5            Number of trials
#   PORT_AGENT=8005         vLLM agent port
#   USE_STEER=true          Use Steer API for user model
#   MAX_CONCURRENCY=1       Max parallel tasks in tau-trait

# ── Ensure log directory exists ─────────────────────────────────────────
mkdir -p /scratch/ckurian/tau-trait/logs/slurm /scratch/ckurian/tau-trait/logs/vllm

# ── Defaults ─────────────────────────────────────────────────────────────
SCRIPT_DIR="/scratch/ckurian/tau-trait/scripts"
PID_FILE="/scratch/ckurian/tau-trait/logs/vllm/pids_${SLURM_JOB_ID:-$$}.txt"

DOMAIN="${DOMAIN:-airline}"
TRAIT="${TRAIT:-baseline}"
NUM_TRIALS="${NUM_TRIALS:-5}"
PORT_AGENT="${PORT_AGENT:-8005}"
USE_STEER="${USE_STEER:-true}"
MAX_CONCURRENCY="${MAX_CONCURRENCY:-1}"
MAX_WAIT_SEC="${MAX_WAIT_SEC:-600}"

# ── Cleanup trap ─────────────────────────────────────────────────────────
cleanup() {
    echo ""
    echo "Cleaning up..."
    if [ -f "${PID_FILE}" ]; then
        echo "Killing vLLM servers from ${PID_FILE}..."
        while read -r pid; do
            kill "${pid}" 2>/dev/null && echo "  Killed PID ${pid}" || true
        done < "${PID_FILE}"
        rm -f "${PID_FILE}"
    fi
    echo "Cleanup complete."
}
trap cleanup EXIT

# ── Wait helper ──────────────────────────────────────────────────────────
wait_for_health() {
    local name="$1"
    local port="$2"
    local waited=0
    while ! curl -sf "http://127.0.0.1:${port}/health" >/dev/null 2>&1; do
        sleep 5
        waited=$((waited + 5))
        if [ "${waited}" -ge "${MAX_WAIT_SEC}" ]; then
            echo "ERROR: Timed out waiting for ${name} on port ${port} (${MAX_WAIT_SEC}s)"
            exit 1
        fi
    done
    echo "${name} ready on port ${port}."
}

# ── Job info ─────────────────────────────────────────────────────────────
echo "============================================"
echo "SLURM Job: ${SLURM_JOB_ID:-N/A}"
echo "Node:      $(hostname)"
echo "GPUs:      $(nvidia-smi -L 2>/dev/null | wc -l) available"
echo "============================================"
echo "τ-trait Qwen3-8B experiment"
echo "  Domain:     ${DOMAIN}"
echo "  Trait:      ${TRAIT}"
echo "  Trials:     ${NUM_TRIALS}"
echo "  Steer API:  ${USE_STEER}"
echo "  Port:       ${PORT_AGENT}"
echo "============================================"
echo ""

# ── Start vLLM server ────────────────────────────────────────────────────
echo "Starting vLLM server..."
PORT_AGENT="${PORT_AGENT}" \
PID_FILE="${PID_FILE}" \
    bash "${SCRIPT_DIR}/start_vllm_tau_trait.sh"

echo ""
echo "Verifying health endpoint..."
wait_for_health "Agent server" "${PORT_AGENT}"
echo ""

# ── Run experiment ───────────────────────────────────────────────────────
echo "Running τ-trait experiment..."
PORT_AGENT="${PORT_AGENT}" \
USE_STEER="${USE_STEER}" \
MAX_CONCURRENCY="${MAX_CONCURRENCY}" \
TAU_TRAIT_DIR="/scratch/ckurian/tau-trait" \
    bash "${SCRIPT_DIR}/run_tau_trait_8b.sh" "${DOMAIN}" "${TRAIT}" "${NUM_TRIALS}"

echo ""
echo "============================================"
echo "Job complete: ${DOMAIN} × ${TRAIT} × ${NUM_TRIALS} trials"
echo "SLURM Job ID: ${SLURM_JOB_ID:-N/A}"
echo "Check outputs:"
echo "  /scratch/ckurian/tau-trait/logs/slurm/ttrait_${SLURM_JOB_ID:-N/A}.out"
echo "  /scratch/ckurian/tau-trait/logs/slurm/ttrait_${SLURM_JOB_ID:-N/A}.err"
echo "  /scratch/ckurian/tau-trait/results/fc_${DOMAIN}_${TRAIT}_8b/"
echo "============================================"
