---
spec: fly-fight-sim
version: 0.1.0
status: approved
---

# Fly Fight Sim

## Obiettivo

Simulazione 3D: due agenti "mosca" combattono con proiettili ("palla di fuoco").
Movimento/schivata ispirati a circuiti riflessi reali della mosca (loom-detection).
Attacco (lancio proiettile) appreso via reinforcement learning (self-play PPO).

## Stack

- Godot 4.7.2 (engine + rendering + fisica)
- godot-rl-agents (bridge RL <-> Godot)
- Python 3.10 venv (stable-baselines3, PPO)
- GDScript per logica scena/riflessi

## Architettura

```
mosca/
  venv/                  # Python 3.10, non versionato
  godot_project/         # progetto Godot
    project.godot
    scenes/
      arena.tscn          # scena principale
      fly.tscn            # personaggio mosca (CharacterBody3D)
      fireball.tscn        # proiettile (RigidBody3D)
    scripts/
      fly_reflex.gd        # riflessi: loom-detection -> schiva/insegui
      fly_ai_controller.gd # bridge godot-rl: observation/action/reward
      fireball.gd           # collisione, danno
  train.py                 # loop training PPO (self-play)
  requirements.txt
  docs/
```

## API contract

**Observation space** (per agente):
- distanza dall'avversario (float)
- direzione relativa avversario (vec3 normalizzato)
- cooldown lancio residuo (float, 0-1)
- HP proprio e avversario (float, 0-1 ciascuno)

**Action space**:
- movimento (vec2: avanti/indietro, strafe)
- lancia (bool/discrete)

**Reward**:
- +danno colpo a segno / -danno colpito (0.2 di default)
- shaping denso: +0.05 * (distanza_precedente - distanza_attuale) ogni step
  (avvicinarsi al nemico premia un po', da' segnale continuo alla value
  function — introdotto dopo osservazione: senza shaping la policy
  collassava su "non fare nulla", explained_variance restava ~0)
- -2 malus se non si colpisce entro 15s, poi sconfitta immediata ("cade
  dalla mappa") — v. `no_hit_timeout`/`no_hit_malus` in fly.gd
- +10 / -10 fine round (vittoria/sconfitta)

**Riflessi (non-RL, scriptati)**:
- raycast rilevamento oggetto in avvicinamento rapido (proiettile nemico) → trigger schivata laterale automatica, priorità su azione RL quando entro soglia critica

## Decisioni architetturali

- Riflessi scriptati (GDScript, non appresi) per movimento base di schivata: comportamento noto, deterministico, veloce da implementare, coerente con circuito reale mosca.
- Attacco via RL: comportamento non ovvio, timing/strategia emergono da training, non scriptabile a mano in modo sensato.
- Python 3.10 per venv: 3.14 di sistema troppo recente, incompatibilità note con stable-baselines3/godot-rl-agents.
- Self-play: due istanze stesso agente si allenano una contro l'altra, no dataset esterno necessario.

## Test plan

- Self-check `demo()` in `train.py`: istanzia env, esegue N step random, assert reward in range atteso, no crash.
- Verifica manuale in-editor: avvio scena, controllo riflesso schivata su proiettile lanciato manualmente.
- Training smoke test: 1000 step PPO, verifica reward medio non-NaN e in salita nel tempo (log).

## Fuori scope

- Grafica/animazioni rifinite (placeholder mesh capsule/sfera).
- Multiplayer di rete.
- Bilanciamento gioco avanzato (danno, HP, velocità) — valori iniziali arbitrari, tunabili dopo.
