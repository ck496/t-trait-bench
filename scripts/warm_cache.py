import os
from transformers import AutoModelForCausalLM, AutoTokenizer

# 1. Configuration - Use your scratch paths
token = os.getenv("HUGGING_FACE_HUB_TOKEN")
# Should be /scratch/ckurian/.cache/huggingface/hub
cache_path = os.getenv("HF_HOME")

# 2. Exact Model IDs for Qwen3 (2026 stable release)
# Use "Instruct" versions for the Agent and User Simulator
models = [
    "Qwen/Qwen3-8B-Instruct",
    "Qwen/Qwen3-32B-Instruct"
]

for model_id in models:
    print(f"--- Starting Download for {model_id} ---")
    try:
        # Download Tokenizer
        tokenizer = AutoTokenizer.from_pretrained(
            model_id,
            cache_dir=cache_path,
            token=token
        )

        # Download Model (Only the weights, don't load into RAM yet)
        # We use 'local_files_only=False' to force the download if missing
        model = AutoModelForCausalLM.from_pretrained(
            model_id,
            cache_dir=cache_path,
            token=token,
            device_map="cpu",     # Keep it on CPU to avoid OOM during download
            low_cpu_mem_usage=True
        )
        print(f"Successfully cached {model_id}\n")
    except Exception as e:
        print(f"Failed to download {model_id}. Error: {e}")
