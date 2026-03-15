{
  config,
  pkgs,
  lib,
  ...
}: {
  # llama.cpp configuration with NVIDIA CUDA support
  # The service is disabled by default - enable in host config with:
  #
  # Option 1: Single model
  #   services.llama-cpp.enable = true;
  #   services.llama-cpp.model = "/path/to/model.gguf";
  #
  # Option 2: Models directory (recommended - serves multiple models)
  #   services.llama-cpp.enable = true;
  #   services.llama-cpp.modelsDir = "/var/lib/llama-cpp/models";
  #
  # With modelsDir, access models via:
  #   http://127.0.0.1:10808/v1/models (list available models)
  #   Specify model in API calls with "model": "modelname.gguf"
  #
  # Models location: /var/lib/llama-cpp/models/ (systemd state directory)
  # Add models with: sudo mv model.gguf /var/lib/llama-cpp/models/

  # Use CUDA-enabled llama-cpp for NVIDIA GPUs
  services.llama-cpp = {
    package = lib.mkDefault (pkgs.llama-cpp.override {cudaSupport = true;});
    port = lib.mkDefault 10808; # Less common port to avoid conflicts
    host = lib.mkDefault "127.0.0.1"; # Only local access by default
  };

  # Install llama-cpp CLI tools system-wide for manual usage
  environment.systemPackages = with pkgs; [
    (llama-cpp.override {cudaSupport = true;})
  ];

  # Per-model configuration presets for llama-cpp multi-model server
  # Large MoE models need smaller context to fit KV cache in VRAM
  # Dense models can use larger context since they're more VRAM-efficient
  #
  # Note: Models not listed here will use global defaults from extraFlags
  environment.etc."llama-cpp-presets.ini".text = lib.mkDefault ''
    # LFM2: Fast dense model, can use large context (128K supported, 64K practical)
    [LFM2-8B-A1B-Q6_K]
    model = /var/lib/llama-cpp/models/LFM2-8B-A1B-Q6_K.gguf
    ctx-size = 65536
    n-gpu-layers = 99
    parallel = 2

    # Qwen3-30B MoE: With --cpu-moe, model uses only ~800MB VRAM
    # KV cache scales with context but we have ~11GB available
    # 80K context should use ~5-6GB VRAM total (model + KV cache)
    [Qwen3-30B-A3B-Instruct-2507-Q4_K_M]
    model = /var/lib/llama-cpp/models/Qwen3-30B-A3B-Instruct-2507-Q4_K_M.gguf
    ctx-size = 81920
    n-gpu-layers = 99
    parallel = 1

    # Qwen3-8B: Dense model, moderate context
    [Qwen3-8B-Q5_K_M]
    model = /var/lib/llama-cpp/models/Qwen3-8B-Q5_K_M.gguf
    ctx-size = 32768
    n-gpu-layers = 99
    parallel = 2

    # Qwen3.5-27B Claude Opus distilled: Dense 27B at Q2_K (~9.2GB)
    # Model needs 9.2GB, leaving ~2GB for KV cache after desktop overhead
    # Offload some layers to CPU to free VRAM for larger context
    [Qwen3.5-27B-Claude-Opus-Q2_K]
    model = /var/lib/llama-cpp/models/Qwen3.5-27B-Claude-Opus-Q2_K.gguf
    ctx-size = 16384
    n-gpu-layers = 55
    parallel = 1
  '';
}
