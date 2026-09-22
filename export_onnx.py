"""Esporta un modello PPO addestrato in ONNX per godot-rl ONNX_INFERENCE mode.

Uso: venv/Scripts/python.exe export_onnx.py [--model models/fly_ppo.zip] [--out models/fly_ppo.onnx]
"""
import argparse

from stable_baselines3 import PPO

from godot_rl.wrappers.onnx.stable_baselines_export import export_model_as_onnx

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=str, default="models/fly_ppo.zip")
    parser.add_argument("--out", type=str, default="models/fly_ppo.onnx")
    args = parser.parse_args()

    model = PPO.load(args.model)
    export_model_as_onnx(model, args.out)
    print(f"Esportato: {args.out}")
