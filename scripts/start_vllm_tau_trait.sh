#!/bin/bash
set -euo pipefail

# Start Qwen3-8B vLLM server for τ-trait agent model.
# With Steer API, only 1 GPU is needed (user model is remote).
#
# Override defaults via env vars:
#   PORT_AGENT=8005  GPU_AGENT=0  PID_FILE=...  MODEL_8B_PATH=...
#
# Usage:
#   ./start_vllm_tau_trait.sh              # defaults
#   PORT_AGENT=8010 ./start_vllm_tau_trait.sh  # custom port

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# ── Configurable ─────────────────────────────────────────────────────────
PORT_AGENT="${PORT_AGENT:-8005}"
GPU_AGENT="${GPU_AGENT:-0}"
PID_FILE="${PID_FILE:-${SCRIPT_DIR}/vllm_tau_trait_pids.txt}"
MODEL_8B_PATH="${MODEL_8B_PATH:-Qwen/Qwen3-8B-Instruct-2507}"

# ── Environment ──────────────────────────────────────────────────────────
export HF_HOME="${HF_HOME:-/scratch/ckurian/.cache/huggingface}"

echo "============================================"
echo "Starting vLLM server for τ-trait (8B agent)"
echo "============================================"
echo "Model:    ${MODEL_8B_PATH}"
echo "Port:     ${PORT_AGENT}"
echo "GPU:      ${GPU_AGENT}"
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

# ── Start Qwen3-8B agent server ─────────────────────────────────────────
echo "Starting Qwen3-8B vLLM server on GPU ${GPU_AGENT}, port ${PORT_AGENT}..."
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
> "${SCRIPT_DIR}/vllm_agent.log" 2>&1 &
PID_AGENT=$!
echo "Agent PID: ${PID_AGENT}"

# Save PID for cleanup
echo "${PID_AGENT}" > "${PID_FILE}"
echo "PID saved to ${PID_FILE} (kill with: kill \$(cat ${PID_FILE}))"
echo ""

# ── Wait for server to be healthy ────────────────────────────────────────
echo "Waiting for vLLM server to start (may take several minutes)..."

MAX_WAIT=600  # 10 minutes max
waited=0
while ! curl -sf "http://127.0.0.1:${PORT_AGENT}/health" >/dev/null 2>&1; do
    sleep 5
    waited=$((waited + 5))

    # Check if process crashed
    if ! kill -0 "${PID_AGENT}" 2>/dev/null; then
        echo ""
        echo "ERROR: vLLM server crashed! Last 30 lines of log:"
        tail -30 "${SCRIPT_DIR}/vllm_agent.log"
        exit 1
    fi

    # Check timeout
    if [ "${waited}" -ge "${MAX_WAIT}" ]; then
        echo ""
        echo "ERROR: Timed out waiting for vLLM server (${MAX_WAIT}s)"
        echo "Last 20 lines of log:"
        tail -20 "${SCRIPT_DIR}/vllm_agent.log"
        kill "${PID_AGENT}" 2>/dev/null || true
        exit 1
    fi

    echo "  Still waiting... (${waited}s elapsed)"
done

echo ""
echo "============================================"
echo "vLLM server is ready!"
echo "  Agent: http://127.0.0.1:${PORT_AGENT}"
echo "  Model: Qwen3-8B"
echo "  To stop: kill \$(cat ${PID_FILE})"
echo "============================================"
