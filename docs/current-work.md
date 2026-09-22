# Current work

## Sessione 2026-09-22

**Lavorando su**: fly-fight-sim (vedi docs/specs/fly-fight-sim.spec.md)

### Fatto
- Repo git inizializzato, Godot 4.7.2 installato (winget)
- venv Python 3.10 + stable-baselines3 2.4.0 + godot-rl 0.8.2
- Scaffold completo: arena 3D, due mosche, riflessi schivata, proiettili, bridge RL
- Modalita' demo alpha autonoma: senza flag --train, Sync resta in HUMAN
  (mai tentata connessione di rete -> niente hang), le mosche giocano da
  sole con euristica scriptata (fly.gd:_run_autonomous_heuristic)
- Training esplicito: passare --train a riga di comando Godot -> Sync passa
  a TRAINING e si connette al server Python (train.py)
- Bug trovato e fixato: connect_to_server() di sync.gd si blocca a tempo
  indeterminato (30s+ osservati, mai risolto) quando nessun server RL e' in
  ascolto su questa macchina (probabile WinSock/firewall) -> niente piu'
  tentativo automatico di connessione, opt-in esplicito via --train
- Verificato end-to-end 2 volte: (1) senza --train, fallback autonomo attivo
  istantaneamente, nessun blocco; (2) con --train, handshake ok, training
  PPO completa un rollout (4096 step), salva models/fly_ppo.zip, chiusura
  pulita via close message

### Prossimi step
1. Training vero e lungo (centinaia di migliaia di step) per vedere se
   emerge comportamento sensato di attacco/schivata
2. Eventualmente esportare modello in ONNX e testarlo in ONNX_INFERENCE mode
3. Bilanciamento valori (danno, velocita', HP) se il comportamento appreso
   e' degenere (es. spam lancio senza mai muoversi)

### Blocchi / questioni aperte
- Nessuno al momento
