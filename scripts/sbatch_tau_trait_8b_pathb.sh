#!/bin/bash
#SBATCH --partition=public
#SBATCH --qos=class
#SBATCH -t 0-08:00:00
#SBATCH -c 16
#SBATCH --mem=80GB
#SBATCH --gres=gpu:a100:3
#SBATCH -J ttrait_8b_pathb
#SBATCH -o /scratch/ckurian/tau-trait/logs/slurm/ttrait_pathb_%j.out
#SBATCH -e /scratch/ckurian/tau-trait/logs/slurm/ttrait_pathb_%j.err

set -euo pipefail

# SLURM batch wrapper for τ-trait Path B experiments (local 32B user).
# Starts BOTH vLLM servers (8B agent + 32B user), runs experiment, cleans up.
#
# Usage:
#   sbatch scripts/sbatch_tau_trait_8b_pathb.sh
#   sbatch --export=ALL,DOMAIN=airline,TRAIT=skeptical,NUM_TRIALS=5 scripts/sbatch_tau_trait_8b_pathb.sh
#
# Environment variable overrides (via --export):
#   DOMAIN=airline          Domain to run
#   TRAIT=baseline          Trait to apply (or "baseline" for no trait)
#   NUM_TRIALS=5            Number of trials
#   PORT_AGENT=8005         vLLM agent port
#   PORT_USER=8006          vLLM user port
#   MAX_CONCURRENCY=1       Max parallel tasks

# ── Ensure log directory exists ─────────────────────────────────────────
mkdir -p /scratch/ckurian/tau-trait/logs/slurm /scratch/ckurian/tau-trait/logs/vllm

# ── Defaults ─────────────────────────────────────────────────────────────
SCRIPT_DIR="/scratch/ckurian/tau-trait/scripts"
PID_FILE="${SCRIPT_DIR}/vllm_tau_trait_pathb_pids.txt"

DOMAIN="${DOMAIN:-airline}"
TRAIT="${TRAIT:-baseline}"
NUM_TRIALS="${NUM_TRIALS:-5}"
PORT_AGENT="${PORT_AGENT:-8005}"
PORT_USER="${PORT_USER:-8006}"
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

# ── Job info ─────────────────────────────────────────────────────────────
echo "============================================"
echo "SLURM Job: ${SLURM_JOB_ID:-N/A}"
echo "Node:      $(hostname)"
echo "GPUs:      $(nvidia-smi -L 2>/dev/null | wc -l) available"
echo "============================================"
echo "τ-trait Qwen3-8B Path B (local 32B user)"
echo "  Domain:     ${DOMAIN}"
echo "  Trait:      ${TRAIT}"
echo "  Trials:     ${NUM_TRIALS}"
echo "  Agent:      8005 (Qwen3-8B)"
echo "  User:       8006 (Qwen3-32B)"
echo "============================================"
echo ""

# ── Start BOTH vLLM servers ─────────────────────────────────────────────
echo "Starting vLLM servers (8B agent + 32B user)..."
PORT_AGENT="${PORT_AGENT}" \
PORT_USER="${PORT_USER}" \
PID_FILE="${PID_FILE}" \
    bash "${SCRIPT_DIR}/start_vllm_tau_trait_pathb.sh"

echo ""

# ── Run experiment with USE_STEER=false ─────────────────────────────────
echo "Running τ-trait experiment (Path B)..."
PORT_AGENT="${PORT_AGENT}" \
PORT_USER="${PORT_USER}" \
USE_STEER=false \
MAX_CONCURRENCY="${MAX_CONCURRENCY}" \
TAU_TRAIT_DIR="/scratch/ckurian/tau-trait" \
    bash "${SCRIPT_DIR}/run_tau_trait_8b.sh" "${DOMAIN}" "${TRAIT}" "${NUM_TRIALS}"

echo ""
echo "============================================"
echo "Job complete: ${DOMAIN} × ${TRAIT} × ${NUM_TRIALS} trials (Path B)"
echo "SLURM Job ID: ${SLURM_JOB_ID:-N/A}"
echo "Check outputs:"
echo "  /scratch/ckurian/tau-trait/logs/ttrait_pathb_${SLURM_JOB_ID:-N/A}.out"
echo "  /scratch/ckurian/tau-trait/results/fc_${DOMAIN}_${TRAIT}_8b/"
echo "============================================"