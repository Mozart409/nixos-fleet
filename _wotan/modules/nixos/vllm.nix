{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.vllm;
in {
  options.services.vllm = {
    enable = lib.mkEnableOption "vLLM OpenAI-compatible inference server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.vllm;
      defaultText = lib.literalExpression "pkgs.vllm";
    };

    model = lib.mkOption {
      type = lib.types.str;
      example = "Qwen/Qwen2.5-7B-Instruct";
      description = "HuggingFace model id or local path. vLLM expects HF-format weights, not GGUF.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 10808;
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
        Path to a systemd EnvironmentFile containing the HuggingFace token
        (for gated models). The file must contain a line of the form:
          HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # NOTE: vllm 0.16.0 is flagged for 3 CVEs in nixpkgs. The insecure-package
    # exception lives in `lib/mkConfigs.nix` (sharedNixpkgsConfig) so it applies
    # to both nixos and home-manager evals. See that file for the full list,
    # and below for per-CVE details:
    #   CVE-2026-27893 (RCE, fixed in 0.18.0): hardcoded `trust_remote_code=True`
    #     in two model files bypasses the user's `--trust-remote-code=False`.
    #     Mitigation: only load models from trusted HF repos (Qwen/, RedHatAI/,
    #     official orgs). Do NOT load arbitrary community models.
    #   CVE-2026-44222 (DoS, fixed in 0.20.0): multimodal token-injection crashes
    #     a worker. Mitigation: loopback-only binding (host = 127.0.0.1).
    #   CVE-2026-44223 (DoS, fixed in 0.20.0): repetition/frequency/presence
    #     penalties crash the EngineCore. Mitigation: clients should avoid these
    #     params; systemd Restart=on-failure auto-recovers.
    # TODO: drop the exception in mkConfigs.nix once nixpkgs ships vllm >= 0.20.0.

    systemd.services.vllm = {
      description = "vLLM OpenAI-compatible inference server";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];

      environment = {
        HOME = "/var/lib/vllm";
        HF_HOME = "/var/lib/vllm/huggingface";
        TRITON_CACHE_DIR = "/var/lib/vllm/triton-cache";
      };

      preStart = ''
        # Stale half-written .so files from a previous crash can fail to mmap
        # on restart ("failed to map segment from shared object"). Wipe the
        # Triton compile cache so the next start always starts clean.
        rm -rf /var/lib/vllm/triton-cache
      '';

      serviceConfig = {
        DynamicUser = true;
        StateDirectory = "vllm";
        StateDirectoryMode = "0750";
        ExecStart = lib.concatStringsSep " " ([
            "${cfg.package}/bin/vllm"
            "serve"
            (lib.escapeShellArg cfg.model)
            "--host"
            cfg.host
            "--port"
            (toString cfg.port)
            "--gpu-memory-utilization"
            (toString cfg.gpuMemoryUtilization)
          ]
          ++ lib.optionals (cfg.maxModelLen != null) [
            "--max-model-len"
            (toString cfg.maxModelLen)
          ]
          ++ cfg.extraArgs);
        Restart = "on-failure";
        RestartSec = 10;
        EnvironmentFile = lib.optional (cfg.huggingfaceTokenFile != null) cfg.huggingfaceTokenFile;
      };
    };

    environment.systemPackages = [cfg.package];
  };
}
