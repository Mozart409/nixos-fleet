{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  llamaCppCuda = inputs.llama-cpp.packages.${pkgs.stdenv.hostPlatform.system}.cuda;
in {
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

  # Use CUDA-enabled llama-cpp from the upstream flake.
  # The upstream CI publishes these exact builds to llama-cpp.cachix.org,
  # so this should hit the binary cache instead of recompiling.
  services.llama-cpp = {
    package = lib.mkDefault llamaCppCuda;
    port = lib.mkDefault 10808; # Less common port to avoid conflicts
    host = lib.mkDefault "127.0.0.1"; # Only local access by default
  };

  # Install llama-cpp CLI tools system-wide for manual usage
  environment.systemPackages = [
    llamaCppCuda
  ];

  # Per-model configuration presets for llama-cpp
  # Optimized for different models
  environment.etc."llama-cpp-presets.ini".text = lib.mkDefault ''
    # Qwen3-8B: Dense model with tool calling, 40K training context
    # Needs RoPE scaling for 96K+ requests
    [Qwen3-8B-Q5_K_M]
    ctx-size = 98304
    rope-scale = 2.5
    n-gpu-layers = 99
    parallel = 1
    cache-type-k = q4_0
    cache-type-v = q4_0

    # NVIDIA Nemotron 3 Nano 4B: 262K native context (no scaling needed!)
    # Mamba2-Transformer hybrid, ~2.5GB at Q4_K_M
    # Perfect for long-context tasks on 12GB VRAM
    [NVIDIA-Nemotron3-Nano-4B-Q4_K_M]
    ctx-size = 262144
    n-gpu-layers = 99
    parallel = 1
    cache-type-k = q4_0
    cache-type-v = q4_0
  '';
}
