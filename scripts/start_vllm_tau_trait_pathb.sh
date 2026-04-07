#!/bin/bash
set -euo pipefail

# Start Qwen3-8B (agent) + Qwen3-32B (user) vLLM servers for τ-trait Path B.
# Requires 3x A100 GPUs: 1 for 8B agent, 2 for 32B user (tensor-parallel).
#
# Override defaults via env vars:
#   PORT_AGENT=8005  PORT_USER=8006  GPU_AGENT=0  GPU_USER=1,2
#
# Usage:
#   ./start_vllm_tau_trait_pathb.sh
#   PORT_AGENT=8010 PORT_USER=8011 ./start_vllm_tau_trait_pathb.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# ── Log directory ────────────────────────────────────────────────────────
# Use SLURM_JOB_ID if in a batch job, otherwise timestamp
RUN_ID="${SLURM_JOB_ID:-$(date +%Y%m%d_%H%M%S)}"
VLLM_LOG_DIR="${VLLM_LOG_DIR:-${PROJECT_DIR}/logs/vllm}"
mkdir -p "${VLLM_LOG_DIR}"

# ── Configurable ─────────────────────────────────────────────────────────
PORT_AGENT="${PORT_AGENT:-8005}"
PORT_USER="${PORT_USER:-8006}"
GPU_AGENT="${GPU_AGENT:-0}"
GPU_USER="${GPU_USER:-1,2}"
PID_FILE="${PID_FILE:-${PROJECT_DIR}/logs/vllm/pids_${RUN_ID}.txt}"
MODEL_8B_PATH="${MODEL_8B_PATH:-Qwen/Qwen3-8B-Instruct-2507}"
MODEL_32B_PATH="${MODEL_32B_PATH:-Qwen/Qwen3-32B-Instruct-2507}"

# ── Environment ──────────────────────────────────────────────────────────
export HF_HOME="${HF_HOME:-/scratch/ckurian/.cache/huggingface}"

echo "============================================"
echo "Starting vLLM servers for τ-trait Path B"
echo "  (8B agent + 32B user)"
echo "============================================"
echo "Agent:    ${MODEL_8B_PATH}"
echo "  Port:   ${PORT_AGENT}, GPU: ${GPU_AGENT}"
echo "User:     ${MODEL_32B_PATH}"
echo "  Port:   ${PORT_USER}, GPU: ${GPU_USER}, TP=2"
echo "Logs:     ${VLLM_LOG_DIR}/agent_${RUN_ID}.log"
echo "          ${VLLM_LOG_DIR}/user_${RUN_ID}.log"
echo "PID file: ${PID_FILE}"
echo "HF cache: ${HF_HOME}"
echo "============================================"
echo ""

# ── Activate vLLM environment ────────────────────────────────────────────
if [ -f ~/vllm-upgrade-venv/bin/activate ]; then
    source ~/vllm-upgrade-venv/bin/activate
    echo "Activated: ~/vllm-upgrade-venv"
elif command -v mamba >/dev/null 2>&1 || module load mamba/latest 2>/dev/null; then
    source activate qwen3-fa2 2>/dev/null || true
    echo "Activated: qwen3-fa2 (mamba)"
else
    echo "WARNING: No vLLM environment found. Using system Python."
fi

echo ""
echo "Checking GPU availability..."
nvidia-smi --query-gpu=index,name,memory.free,memory.total --format=csv
echo ""

# ── Start Qwen3-8B agent server (GPU 0) ─────────────────────────────────
echo "Starting Qwen3-8B vLLM server (agent) on GPU ${GPU_AGENT}, port ${PORT_AGENT}..."
CUDA_VISIBLE_DEVICES="${GPU_AGENT}" vllm serve "${MODEL_8B_PATH}" \
    --host 127.0.0.1 \
    --port "${PORT_AGENT}" \
    --dtype bfloat16 \
    --max-model-len 32768 \
    --gpu-memory-utilization 0.9 \
    --tensor-parallel-size 1 \
    --enable-auto-tool-choice \
    --tool-call-parser hermes \
    --served-model-name Qwen3-8B \
> "${VLLM_LOG_DIR}/agent_${RUN_ID}.log" 2>&1 &
PID_AGENT=$!
echo "Agent PID: ${PID_AGENT}"

# ── Start Qwen3-32B user server (GPUs 1,2) ──────────────────────────────
echo "Starting Qwen3-32B vLLM server (user) on GPUs ${GPU_USER}, port ${PORT_USER}..."
CUDA_VISIBLE_DEVICES="${GPU_USER}" vllm serve "${MODEL_32B_PATH}" \
    --host 127.0.0.1 \
    --port "${PORT_USER}" \
    --dtype bfloat16 \
    --max-model-len 16384 \
    --gpu-memory-utilization 0.9 \
    --tensor-parallel-size 2 \
    --served-model-name Qwen3-32B \
> "${VLLM_LOG_DIR}/user_${RUN_ID}.log" 2>&1 &
PID_USER=$!
echo "User PID: ${PID_USER}"

# Save PIDs for cleanup
echo "${PID_AGENT}" > "${PID_FILE}"
echo "${PID_USER}" >> "${PID_FILE}"
echo "PIDs saved to ${PID_FILE} (kill with: kill \$(cat ${PID_FILE}))"
echo ""

# ── Wait for agent server ────────────────────────────────────────────────
MAX_WAIT=600
echo "Waiting for Qwen3-8B (agent) server..."
waited=0
while ! curl -sf "http://127.0.0.1:${PORT_AGENT}/health" >/dev/null 2>&1; do
    sleep 5
    waited=$((waited + 5))
    if ! kill -0 "${PID_AGENT}" 2>/dev/null; then
        echo "ERROR: Agent server crashed! Last 30 lines:"
        tail -30 "${VLLM_LOG_DIR}/agent_${RUN_ID}.log"
        kill "${PID_USER}" 2>/dev/null || true
        exit 1
    fi
    if [ "${waited}" -ge "${MAX_WAIT}" ]; then
        echo "ERROR: Agent server timed out (${MAX_WAIT}s)"
        tail -20 "${VLLM_LOG_DIR}/agent_${RUN_ID}.log"
        kill "${PID_AGENT}" "${PID_USER}" 2>/dev/null || true
        exit 1
    fi
    echo "  Still waiting for agent... (${waited}s)"
done
echo "Agent (8B) server ready!"

# ── Wait for user server ─────────────────────────────────────────────────
echo "Waiting for Qwen3-32B (user) server..."
waited=0
while ! curl -sf "http://127.0.0.1:${PORT_USER}/health" >/dev/null 2>&1; do
    sleep 5
    waited=$((waited + 5))
    if ! kill -0 "${PID_USER}" 2>/dev/null; then
        echo "ERROR: User server crashed! Last 30 lines:"
        tail -30 "${VLLM_LOG_DIR}/user_${RUN_ID}.log"
        kill "${PID_AGENT}" 2>/dev/null || true
        exit 1
    fi
    if [ "${waited}" -ge "${MAX_WAIT}" ]; then
        echo "ERROR: User server timed out (${MAX_WAIT}s)"
        tail -20 "${VLLM_LOG_DIR}/user_${RUN_ID}.log"
        kill "${PID_AGENT}" "${PID_USER}" 2>/dev/null || true
        exit 1
    fi
    echo "  Still waiting for user... (${waited}s)"
done
echo "User (32B) server ready!"

echo ""
echo "============================================"
echo "Both vLLM servers are running!"
echo "  Agent: http://127.0.0.1:${PORT_AGENT} (Qwen3-8B)"
echo "  User:  http://127.0.0.1:${PORT_USER} (Qwen3-32B)"
echo "  To stop: kill \$(cat ${PID_FILE})"
echo "============================================"