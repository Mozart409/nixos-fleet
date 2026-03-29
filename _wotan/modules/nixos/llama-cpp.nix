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
  # Optimized for Qwen3-8B as primary model
  # Model ~5.5GB at Q5_K_M on RTX 3060 12GB
  # 96K context (scaled from 40K training ctx) with Q4_0 KV cache
  environment.etc."llama-cpp-presets.ini".text = lib.mkDefault ''
    [Qwen3-8B-Q5_K_M]
    ctx-size = 98304
    rope-scale = 2.5
    n-gpu-layers = 99
    parallel = 1
    cache-type-k = q4_0
    cache-type-v = q4_0
  '';
}
