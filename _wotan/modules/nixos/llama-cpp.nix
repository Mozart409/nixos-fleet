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

  # Per-model configuration presets for llama-cpp
  # Optimized for Qwen3-8B as primary model with full VRAM utilization
  environment.etc."llama-cpp-presets.ini".text = lib.mkDefault ''
    # Qwen3-8B: Primary model - dense with native tool calling
    # Model ~5.5GB at Q5_K_M, leaves ~5.5GB for KV cache (after ~1GB desktop)
    # 96K context uses ~6GB KV cache - pushes VRAM limits but should fit
    # Expected speed: ~50-70 tok/s on RTX 3060
    [Qwen3-8B-Q5_K_M]
    model = /var/lib/llama-cpp/models/Qwen3-8B-Q5_K_M.gguf
    ctx-size = 98304
    n-gpu-layers = 99
    parallel = 1
  '';
}
