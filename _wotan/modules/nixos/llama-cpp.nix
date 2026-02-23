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
  #   services.llama-cpp.modelsDir = "/home/amadeus/models";
  #
  # With modelsDir, access models via:
  #   http://127.0.0.1:10808/v1/models (list available models)
  #   Specify model in API calls with "model": "modelname.gguf"

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
}
