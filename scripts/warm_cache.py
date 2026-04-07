import os
import sys
from transformers import AutoModelForCausalLM, AutoTokenizer
from huggingface_hub.utils import (
    RepositoryNotFoundError,
    GatedRepoError,
    HfHubHTTPError
)

# 1. Configuration
token = os.getenv("HUGGING_FACE_HUB_TOKEN")
cache_path = os.getenv("HF_HOME")

# The specific versions for your Stage 5 Smoke Test
models = [
    "Qwen/Qwen3-8B-Instruct",
    "Qwen/Qwen3-32B-Instruct"
]

if not token:
    print("❌ ERROR: HUGGING_FACE_HUB_TOKEN is not set. Run 'source ~/.tau_trait_env' first.")
    sys.exit(1)

for model_id in models:
    print(f"\n🚀 Checking cache for: {model_id}")
    try:
        # Download Tokenizer first (it's small and a good "gatekeeper" test)
        tokenizer = AutoTokenizer.from_pretrained(
            model_id,
            cache_dir=cache_path,
            token=token,
            local_files_only=False  # Allow it to check online
        )

        # Download Model Weights
        print(f"📥 Downloading weights for {model_id}...")
        model = AutoModelForCausalLM.from_pretrained(
            model_id,
            cache_dir=cache_path,
            token=token,
            device_map="cpu",
            low_cpu_mem_usage=True,
            torch_dtype="auto"
        )
        print(f"✅ Success: {model_id} is fully cached.")

    except GatedRepoError:
        print(
            f"❌ LOCKED: {model_id} is a gated model. You must accept the terms at https://huggingface.co/{model_id}")
    except RepositoryNotFoundError:
        print(
            f"❌ NOT FOUND: The ID '{model_id}' is incorrect or the repo was moved.")
    except HfHubHTTPError as e:
        print(
            f"⚠️ NETWORK ERROR: Could not connect to Hugging Face. Check Sol's internet access. Details: {e}")
    except Exception as e:
        print(f"❓ UNEXPECTED ERROR: {type(e).__name__}: {e}")

print("\n--- Cache Warmup Complete ---")
