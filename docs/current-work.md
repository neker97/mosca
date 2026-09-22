# Current work

## Sessione 2026-09-22

**Lavorando su**: fly-fight-sim (vedi docs/specs/fly-fight-sim.spec.md)

### Fatto
- Repo git inizializzato
- Godot 4.7.2 installato via winget
- venv Python 3.10 creato (venv/) — 3.14 di sistema incompatibile con stable-baselines3
- Spec approvata: docs/specs/fly-fight-sim.spec.md

### In corso
- Setup progetto Godot (scaffold scene/script)
- requirements.txt + install godot-rl-agents/stable-baselines3 in venv

### Prossimi step
1. Creare godot_project/ con scena arena + fly placeholder
2. Script riflessi fly_reflex.gd (loom-detection -> schiva)
3. Bridge godot-rl (fly_ai_controller.gd) + observation/action/reward
4. Scena fireball + collisione
5. train.py con self-play PPO
6. Self-check demo() in train.py

### Blocchi / questioni aperte
- Nessuno al momento
