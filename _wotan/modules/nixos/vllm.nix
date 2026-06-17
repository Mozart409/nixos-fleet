{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.vllm;

  # Build the argument list passed to the container image.
  # The vllm-openai image entrypoint already invokes the server,
  # so we only pass flags.
  containerArgs =
    [
      "--model"
      cfg.model
      "--gpu-memory-utilization"
      (toString cfg.gpuMemoryUtilization)
    ]
    ++ lib.optionals (cfg.maxModelLen != null) [
      "--max-model-len"
      (toString cfg.maxModelLen)
    ]
    ++ cfg.extraArgs;
in {
  options.services.vllm = {
    enable = lib.mkEnableOption "vLLM OpenAI-compatible inference server";

    image = lib.mkOption {
      type = lib.types.str;
      default = "vllm/vllm-openai:v0.22.1";
      description = "OCI image for vLLM.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      example = "Qwen/Qwen2.5-7B-Instruct";
      description = "HuggingFace model id. vLLM expects HF-format weights, not GGUF.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host interface to bind the API server to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 10808;
      description = "Port on the host to expose the API server.";
    };

    maxModelLen = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 98304;
      description = "Max sequence length. null = use model default.";
    };

    gpuMemoryUtilization = lib.mkOption {
      type = lib.types.float;
      default = 0.9;
      description = "Fraction of GPU memory vLLM may allocate (0.0–1.0).";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["--enforce-eager" "--kv-cache-dtype" "fp8"];
    };

    huggingfaceTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing the HuggingFace token
        (for gated models). The file must contain a line of the form:
          HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.vllm = {
      image = cfg.image;
      # Don't start at boot — launch manually with `systemctl start podman-vllm`.
      autoStart = false;
      ports = ["${cfg.host}:${toString cfg.port}:8000"];
      volumes = [
        "/var/lib/vllm/huggingface:/root/.cache/huggingface"
      ];
      environmentFiles = lib.optional (cfg.huggingfaceTokenFile != null) cfg.huggingfaceTokenFile;
      extraOptions = [
        "--device"
        "nvidia.com/gpu=all"
        "--ipc=host"
      ];
      cmd = containerArgs;
    };
  };
}
