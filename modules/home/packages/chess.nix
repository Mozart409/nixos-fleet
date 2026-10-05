{
  config,
  pkgs,
  lib,
  ...
}: let
  cudnn = pkgs.cudaPackages.cudnn;
  cuda_cudart = pkgs.cudaPackages.cuda_cudart;
  libcublas = pkgs.cudaPackages.libcublas;

  cudaLibDirs = [
    "${cudnn.lib}/lib"
    "${cuda_cudart}/lib"
    "${libcublas.lib}/lib"
  ];
  cuda_nvcc = pkgs.cudaPackages.cuda_nvcc;
  cudaIncludeDirs = [
    "${cudnn.dev}/include"
    "${cuda_cudart}/include"
    "${libcublas.dev}/include"
    "${cuda_nvcc}/include"
  ];

  lc0-cuda = pkgs.stdenv.mkDerivation {
    pname = "lc0-cuda";
    version = "0.31.2";

    src = pkgs.fetchFromGitHub {
      owner = "LeelaChessZero";
      repo = "lc0";
      tag = "v0.31.2";
      hash = "sha256-8watDDxSyZ5khYqpXPyjQso2MkOzfI6o2nt0vkuiEUI=";
      fetchSubmodules = true;
    };

    patchPhase = ''
      runHook prePatch
      patchShebangs --build scripts/*
      runHook postPatch
    '';

    strictDeps = true;

    nativeBuildInputs = with pkgs; [
      # keep-sorted start
      cudaPackages.cuda_nvcc
      meson
      ninja
      pkg-config
      python3
      # keep-sorted end
    ];

    buildInputs = with pkgs; [
      # keep-sorted start
      cuda_cudart
      cudnn
      eigen
      gtest
      libcublas
      zlib
      # keep-sorted end
    ];

    mesonFlags = [
      "-Dplain_cuda=true"
      "-Dcudnn=true"
      "-Daccelerate=false"
      "-Dmetal=disabled"
      "-Dembed=false"
      "-Dcudnn_libdirs=${builtins.concatStringsSep "," cudaLibDirs}"
      "-Dcudnn_include=${builtins.concatStringsSep "," cudaIncludeDirs}"
    ];

    # Ensure g++ can find all CUDA headers (crt/host_defines.h etc.)
    NIX_CFLAGS_COMPILE = builtins.concatStringsSep " " (map (d: "-isystem ${d}") cudaIncludeDirs);

    enableParallelBuilding = true;

    meta = {
      homepage = "https://lczero.org/";
      description = "Open source neural network based chess engine (with CUDA/cuDNN)";
      license = lib.licenses.gpl3Plus;
    };
  };
in {
  home.packages = with pkgs; [
    # lc0 with CUDA/cuDNN support for GPU acceleration
    lc0-cuda
  ];
}
