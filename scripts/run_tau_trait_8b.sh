#!/bin/bash
set -euo pipefail

# Run a single τ-trait experiment: 1 domain × 1 trait × N trials.
# Uses Qwen3-8B as agent (via local vLLM) and gpt-4o as user (via Steer API).
#
# Usage:
#   ./run_tau_trait_8b.sh <DOMAIN> <TRAIT> [NUM_TRIALS]
#
# Examples:
#   ./run_tau_trait_8b.sh airline skeptical 5
#   ./run_tau_trait_8b.sh retail baseline 5
#   ./run_tau_trait_8b.sh telecom confused 1   # quick test
#
# DOMAIN:  airline | retail | telecom | telehealth
# TRAIT:   baseline | skeptical | confused | impatient | incoherent
#
# Environment variables (override defaults):
#   PORT_AGENT=8005           vLLM agent port
#   CONDA_ENV=tau_trait       conda environment name
#   MAX_CONCURRENCY=1         max parallel tasks
#   USE_STEER=true            use Steer API (false = local vLLM user)
#   PORT_USER=8006            vLLM user port (only if USE_STEER=false)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAU_TRAIT_DIR="$(dirname "${SCRIPT_DIR}")"

# If tau-trait repo is elsewhere (e.g., on Sol scratch), override:
TAU_TRAIT_DIR="${TAU_TRAIT_DIR:-/scratch/ckurian/tau-trait}"

# ── Arguments ────────────────────────────────────────────────────────────
DOMAIN="${1:?Usage: $0 <DOMAIN> <TRAIT> [NUM_TRIALS]}"
TRAIT="${2:?Usage: $0 <DOMAIN> <TRAIT> [NUM_TRIALS]}"
NUM_TRIALS="${3:-5}"

# ── Configuration ────────────────────────────────────────────────────────
PORT_AGENT="${PORT_AGENT:-8005}"
CONDA_ENV="${CONDA_ENV:-tau_trait}"
MAX_CONCURRENCY="${MAX_CONCURRENCY:-1}"
USE_STEER="${USE_STEER:-true}"
PORT_USER="${PORT_USER:-8006}"

# ── Trait dict mapping ───────────────────────────────────────────────────
# Map trait names to their JSON dict files.
# UPDATE THESE if the actual filenames in the repo differ!
declare -A TRAIT_DICT_MAP=(
    [skeptical]="notebooks/trait_dict_skeptical.json"
    [confused]="notebooks/trait_dict_confused.json"
    [impatient]="notebooks/trait_dict_impatient.json"
    [incoherent]="notebooks/trait_dict_incoherent.json"
)

# ── Result directory ─────────────────────────────────────────────────────
RESULT_DIR="results/fc_${DOMAIN}_${TRAIT}_8b"

echo "============================================"
echo "τ-trait Experiment (Qwen3-8B)"
echo "============================================"
echo "Domain:       ${DOMAIN}"
echo "Trait:        ${TRAIT}"
echo "Trials:       ${NUM_TRIALS}"
echo "Agent:        Qwen3-8B @ 127.0.0.1:${PORT_AGENT}"
if [ "${USE_STEER}" = "true" ]; then
    echo "User:         gpt-4o via Steer API"
else
    echo "User:         Qwen3-32B @ 127.0.0.1:${PORT_USER}"
fi
echo "Concurrency:  ${MAX_CONCURRENCY}"
echo "Results:      ${RESULT_DIR}"
echo "============================================"
echo ""

# ── Validate inputs ──────────────────────────────────────────────────────
valid_domains="airline retail telecom telehealth"
if ! echo "${valid_domains}" | grep -qw "${DOMAIN}"; then
    echo "ERROR: Invalid domain '${DOMAIN}'. Must be one of: ${valid_domains}"
    exit 1
fi

valid_traits="baseline skeptical confused impatient incoherent"
if ! echo "${valid_traits}" | grep -qw "${TRAIT}"; then
    echo "ERROR: Invalid trait '${TRAIT}'. Must be one of: ${valid_traits}"
    exit 1
fi

# ── Health check: agent server ───────────────────────────────────────────
echo "Checking vLLM agent server..."
if ! curl -sf "http://127.0.0.1:${PORT_AGENT}/health" >/dev/null 2>&1; then
    echo "ERROR: Agent server not responding at http://127.0.0.1:${PORT_AGENT}/health"
    echo "Start it first: bash scripts/start_vllm_tau_trait.sh"
    exit 1
fi
echo "  Agent server: OK"

# ── Health check: user server (if local) ─────────────────────────────────
if [ "${USE_STEER}" != "true" ]; then
    echo "Checking vLLM user server..."
    if ! curl -sf "http://127.0.0.1:${PORT_USER}/health" >/dev/null 2>&1; then
        echo "ERROR: User server not responding at http://127.0.0.1:${PORT_USER}/health"
        exit 1
    fi
    echo "  User server: OK"
fi
echo ""

# ── Activate environment ─────────────────────────────────────────────────
echo "Activating conda environment: ${CONDA_ENV}"
# On Sol, conda requires module load first. Try that before checking PATH.
if ! command -v conda >/dev/null 2>&1; then
    module load anaconda3 2>/dev/null || module load mamba/latest 2>/dev/null || true
fi
if command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook)"
    conda activate "${CONDA_ENV}"
else
    echo "ERROR: conda not found. Load anaconda3 module or install conda."
    exit 1
fi

# ── Source API keys ──────────────────────────────────────────────────────
if [ -f ~/.tau_trait_env ]; then
    source ~/.tau_trait_env
    echo "Sourced ~/.tau_trait_env"
else
    echo "WARNING: ~/.tau_trait_env not found. API keys may not be set."
fi

# Override OPENAI_API_BASE to point to our vLLM server
export OPENAI_API_BASE="http://127.0.0.1:${PORT_AGENT}/v1"
export OPENAI_API_KEY="EMPTY"

# ── Build command ────────────────────────────────────────────────────────
cd "${TAU_TRAIT_DIR}"

CMD=(
    python run.py
    --agent-strategy tool-calling
    --env "${DOMAIN}"
    --model Qwen3-8B
    --model-provider openai
    --user-strategy llm
    --num-trials "${NUM_TRIALS}"
    --max-concurrency "${MAX_CONCURRENCY}"
    --log-dir "${RESULT_DIR}"
)

# Add user model flags based on Steer vs local
if [ "${USE_STEER}" = "true" ]; then
    CMD+=(--user-model gpt-4o)
    CMD+=(--user-model-provider steer)
else
    CMD+=(--user-model Qwen3-32B)
    CMD+=(--user-model-provider openai)
fi

# Add trait dict (skip for baseline)
if [ "${TRAIT}" != "baseline" ]; then
    TRAIT_DICT="${TRAIT_DICT_MAP[${TRAIT}]:-}"
    if [ -z "${TRAIT_DICT}" ]; then
        echo "ERROR: No trait dict mapping for '${TRAIT}'"
        exit 1
    fi
    TRAIT_DICT_PATH="${TAU_TRAIT_DIR}/${TRAIT_DICT}"
    if [ ! -f "${TRAIT_DICT_PATH}" ]; then
        echo "ERROR: Trait dict not found at ${TRAIT_DICT_PATH}"
        echo "Available files:"
        ls "${TAU_TRAIT_DIR}/notebooks/trait_dict_"*.json 2>/dev/null || echo "  (none)"
        exit 1
    fi
    CMD+=(--trait-dict "${TRAIT_DICT_PATH}")
fi

# ── Run ──────────────────────────────────────────────────────────────────
echo ""
echo "Running command:"
printf "  %s" "${CMD[@]}"
echo ""
echo ""

START_TS="$(date +%s)"

"${CMD[@]}"

END_TS="$(date +%s)"
DURATION=$((END_TS - START_TS))
DURATION_MIN=$((DURATION / 60))

echo ""
echo "============================================"
echo "Experiment complete!"
echo "  Domain:   ${DOMAIN}"
echo "  Trait:    ${TRAIT}"
echo "  Trials:   ${NUM_TRIALS}"
echo "  Duration: ${DURATION_MIN} min (${DURATION}s)"
echo "  Results:  ${TAU_TRAIT_DIR}/${RESULT_DIR}/"
echo "============================================"
