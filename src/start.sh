#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# Ensure ComfyUI-Manager runs in offline network mode inside the container
comfy-manager-set-mode offline || echo "worker-comfyui - Could not set ComfyUI-Manager network_mode" >&2

# Download Style Pack IFL LoRA at runtime if CIVITAI_API_TOKEN secret is set and file doesn't exist
if [ -n "${CIVITAI_API_TOKEN}" ] && [ ! -f /comfyui/models/loras/style-pack-IFL.safetensors ]; then
    echo "worker-comfyui: Downloading Style Pack IFL LoRA..."
    mkdir -p /comfyui/models/loras
    wget -q -O /comfyui/models/loras/style-pack-IFL.safetensors \
        "https://civitai.com/api/download/models/2211883?token=${CIVITAI_API_TOKEN}" && \
        echo "worker-comfyui: Style Pack IFL LoRA downloaded" || \
        echo "worker-comfyui: WARNING - Failed to download Style Pack IFL LoRA"
fi

echo "worker-comfyui: Starting ComfyUI"

# Allow operators to tweak verbosity; default is DEBUG.
: "${COMFY_LOG_LEVEL:=DEBUG}"

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    python -u /comfyui/main.py --disable-auto-launch --disable-metadata --listen --verbose "${COMFY_LOG_LEVEL}" --log-stdout &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    python -u /comfyui/main.py --disable-auto-launch --disable-metadata --verbose "${COMFY_LOG_LEVEL}" --log-stdout &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py
fi