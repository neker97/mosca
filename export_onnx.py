"""Esporta un modello PPO addestrato in ONNX per godot-rl ONNX_INFERENCE mode.

Uso: venv/Scripts/python.exe export_onnx.py [--model models/fly_ppo.zip] [--out models/fly_ppo.onnx]
"""
import argparse
import os

import onnx
from stable_baselines3 import PPO

from godot_rl.wrappers.onnx.stable_baselines_export import export_model_as_onnx

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=str, default="models/fly_ppo.zip")
    parser.add_argument("--out", type=str, default="models/fly_ppo.onnx")
    args = parser.parse_args()

    model = PPO.load(args.model)
    export_model_as_onnx(model, args.out)

    # torch (>=2.5, dynamo exporter) scrive i pesi in un file .onnx.data
    # separato anche per modelli minuscoli come questo. Il wrapper C# di
    # godot_rl carica il modello da un array di byte (non dal path), quindi
    # onnxruntime non riesce a risolvere il riferimento relativo al file
    # esterno ed esplode a runtime. Reincorporiamo i pesi nel .onnx per
    # ottenere un file singolo autosufficiente.
    data_file = args.out + ".data"
    if os.path.exists(data_file):
        onnx_model = onnx.load(args.out, load_external_data=True)
        onnx.save(onnx_model, args.out, save_as_external_data=False)
        os.remove(data_file)

    print(f"Esportato: {args.out}")
