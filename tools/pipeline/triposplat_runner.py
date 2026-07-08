from __future__ import annotations

import argparse
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Run TripoSplat from the OMNI pipeline adapter.")
    parser.add_argument("--triposplat-root", required=True)
    parser.add_argument("--image", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--num-gaussians", type=int, default=262144)
    parser.add_argument("--device", default="cuda")
    args = parser.parse_args()

    triposplat_root = Path(args.triposplat_root).resolve()
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(triposplat_root))

    from triposplat import TripoSplatPipeline

    pipe = TripoSplatPipeline(
        ckpt_path=str(triposplat_root / "ckpts" / "diffusion_models" / "triposplat_fp16.safetensors"),
        decoder_path=str(triposplat_root / "ckpts" / "vae" / "triposplat_vae_decoder_fp16.safetensors"),
        dinov3_path=str(triposplat_root / "ckpts" / "clip_vision" / "dino_v3_vit_h.safetensors"),
        flux2_vae_encoder_path=str(triposplat_root / "ckpts" / "vae" / "flux2-vae.safetensors"),
        rmbg_path=str(triposplat_root / "ckpts" / "background_removal" / "birefnet.safetensors"),
        device=args.device,
    )
    gaussian, prepared = pipe.run(args.image, num_gaussians=args.num_gaussians, show_progress=True)
    prepared.save(output_dir / "preprocessed_image.webp")
    gaussian.save_ply(output_dir / f"output_{args.num_gaussians}.ply")
    gaussian.save_splat(output_dir / f"output_{args.num_gaussians}.splat")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

