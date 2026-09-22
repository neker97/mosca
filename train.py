"""Training self-play PPO per fly-fight-sim (vedi docs/specs/fly-fight-sim.spec.md).

Uso:
  1. Avvia questo script per primo: venv/Scripts/python.exe train.py
  2. In un altro terminale, avvia Godot con il flag --train (altrimenti Sync
     resta in modalita' HUMAN e le mosche giocano in autonomia, demo alpha):
       godot --path godot_project --headless --port=11008 --train
     (oppure apri l'editor e passa --train tra gli argomenti di esecuzione)
  3. Al termine, modello salvato in models/fly_ppo.zip

Self-check (no Godot richiesto): venv/Scripts/python.exe train.py --check

Checkpoint periodici in models/checkpoints/ (ogni --checkpoint_freq step,
default 5000): se il processo viene interrotto (es. spegnimento macchina),
si riprende dall'ultimo con --resume_from models/checkpoints/<file>.zip
"""
import argparse
from pathlib import Path

from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import CheckpointCallback
from stable_baselines3.common.vec_env.vec_monitor import VecMonitor

from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv

EXPECTED_OBS_SIZE = 6  # dist, rel.x, rel.z, cooldown, hp, opp_hp (vedi fly_ai_controller.gd)
EXPECTED_ACTIONS = {"move", "throw"}


def check() -> None:
    """Sanity check statico: verifica coerenza spec <-> codice senza avviare Godot."""
    import re
    from pathlib import Path

    controller_src = Path("godot_project/scripts/fly_ai_controller.gd").read_text()

    obs_list = re.search(r'"obs":\s*\[(.*?)\]', controller_src, re.S)
    assert obs_list is not None, "get_obs non trovato in fly_ai_controller.gd"
    n_fields = len([f for f in obs_list.group(1).split(",") if f.strip()])
    assert n_fields == EXPECTED_OBS_SIZE, f"observation space cambiata: {n_fields} campi, attesi {EXPECTED_OBS_SIZE}"

    for action_name in EXPECTED_ACTIONS:
        assert f'"{action_name}"' in controller_src, f"action '{action_name}' mancante in get_action_space"

    print(f"OK: observation space={n_fields} campi, action space={EXPECTED_ACTIONS}")


def train(timesteps: int, env_path: str | None, checkpoint_freq: int, resume_from: str | None) -> None:
    env = StableBaselinesGodotEnv(env_path=env_path, n_parallel=1)
    env = VecMonitor(env)

    if resume_from:
        model = PPO.load(resume_from, env=env)
        print(f"Ripreso da checkpoint: {resume_from}")
    else:
        model = PPO("MultiInputPolicy", env, verbose=1)

    Path("models/checkpoints").mkdir(parents=True, exist_ok=True)
    checkpoint_cb = CheckpointCallback(
        save_freq=checkpoint_freq, save_path="models/checkpoints", name_prefix="fly_ppo"
    )

    model.learn(total_timesteps=timesteps, callback=checkpoint_cb, reset_num_timesteps=resume_from is None)

    model.save("models/fly_ppo")
    env.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="sanity check statico, no Godot richiesto")
    parser.add_argument("--timesteps", type=int, default=200_000)
    parser.add_argument("--env_path", type=str, default=None, help="eseguibile esportato; None = editor interattivo")
    parser.add_argument("--checkpoint_freq", type=int, default=5000, help="step tra un checkpoint e l'altro")
    parser.add_argument("--resume_from", type=str, default=None, help="path a un checkpoint .zip da cui riprendere")
    args = parser.parse_args()

    if args.check:
        check()
    else:
        train(args.timesteps, args.env_path, args.checkpoint_freq, args.resume_from)
