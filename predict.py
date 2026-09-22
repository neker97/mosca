"""Fa girare il modello addestrato in modalita' inferenza pura (no training),
riusando la connessione TCP del training invece di ONNX_INFERENCE (che
richiederebbe il build Mono/.NET di Godot, non installato).

Uso:
  1. venv/Scripts/python.exe predict.py
  2. In un altro terminale, Godot CON finestra (no --headless) e --train:
       godot --path godot_project --port=11008 --train
"""
import argparse

from stable_baselines3 import PPO

from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=str, default="models/fly_ppo.zip")
    parser.add_argument("--steps", type=int, default=100_000)
    args = parser.parse_args()

    env = StableBaselinesGodotEnv(env_path=None, n_parallel=1)
    model = PPO.load(args.model)

    obs = env.reset()
    for _ in range(args.steps):
        action, _ = model.predict(obs, deterministic=True)
        obs, reward, done, info = env.step(action)
    env.close()
