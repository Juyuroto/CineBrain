# Jarvis-Tor

**Jarvis-Tor** est un système d'automatisation en arrière-plan basé sur **Python**, **Docker** et un **LLM local (Ollama)**. 

Le projet surveille une **Wishlist multi-utilisateurs** de médias (Films, Séries, Documents), utilise un LLM local pour analyser les demandes et valider la pertinence des fichiers, puis orchestre leur téléchargement anonyme en P2P via un tunnel VPN. Une fois le téléchargement terminé, le système transfère et organise automatiquement les fichiers dans le dossier personnel de l'utilisateur sur le serveur **Jellyfin**, puis déclenche un rafraîchissement de la médiathèque.

---

## Fonctions & Flux de Travail

1. **Wishlist Multi-Utilisateurs :** Les utilisateurs (Alain, Louane, Papa, etc.) ajoutent leurs demandes. Chaque requête est attribuée à son demandeur.
2. **Python Orchestrator :** Script Python sous Docker qui scrute en continu la file d'attente de la wishlist.
3. **Analyse LLM (Ollama) :** Le LLM qualifie la demande, génère la recherche torrent, valide les fichiers et détermine le dossier cible selon l'utilisateur (`/mnt/films/<utilisateur>/`).
4. **Téléchargement Sécurisé :** Envoi automatique vers qBittorrent routé de manière étanche dans le tunnel VPN Mullvad (Gluetun) avec Kill-Switch.
5. **Transfert & Rangement Jellyfin :** Copie automatique via SFTP/Rsync depuis le stockage temporaire du Serveur 1 vers le dossier dédié sur le Serveur 2 (`/mnt/films/<utilisateur>/`).
6. **Notification & Scan :** Déclenchement automatique d'un scan via l'API Jellyfin pour rendre le média immédiatement disponible sur le profil de l'utilisateur.

---

## Architecture du Système

```text
┌─────────────────────────────────────────────────────────┐
│              SERVEUR 1 : IA & Orchestration             │
│                     (Docker Host)                       │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │ Wishlist Service (Multi-User UI / Database)       │  │
│  │ - Stores target requests tagged by User           │  │
│  │ - Triggers fetch requests                         │  │
│  └─────────────────────────┬─────────────────────────┘  │
│                            │                            │
│                            ▼                            │
│  ┌───────────────────────────────────────────────────┐  │
│  │ Python Orchestrator (Backend)                     │  │
│  │ - Polls wishlist queue                            │  │
│  │ - Parses targets & queries local LLM              │  │
│  │ - Controls qBittorrent API & triggers SFTP/API    │  │
│  └──────────────┬──────────────────────┬─────────────┘  │
│                 │                      │                │
│                 ▼                      ▼                │
│  ┌──────────────────────────┐ ┌──────────────────────┐  │
│  │ Ollama Service (GPU)     │ │ Gluetun VPN (Mullvad)│  │
│  │ - Engine: Llama 3.2 /    │ │ - Wireguard Tunnel   │  │
│  │   Qwen 2.5               │ │ - Kill-Switch Active │  │
│  │ - VRAM Acceleration      │ │                      │  │
│  │ - Port: 11434            │ │  ┌─────────────────┐ │  │
│  │                          │ │  │ qBittorrent     │ │  │
│  │                          │ │  │ - Port: 8080    │ │  │
│  │                          │ │  │ - Download Agent│ │  │
│  │                          │ │  └────────┬────────┘ │  │
│  └──────────────────────────┘ └───────────┼──────────┘  │
│                                           │             │
│                               Local Temp  │ Downloads   │
│                                           ▼             │
│                              ┌────────────────────────┐ │
│                              │ Temp Storage Volume    │ │
│                              │ - Path: /tmp/downloads │ │
│                              └────────────┬───────────┘ │
└───────────────────────────────────────────┼─────────────┘
                                            │
                     Network Transfer       │ (SFTP / Rsync)
                                            ▼
┌─────────────────────────────────────────────────────────┐
│               SERVEUR 2 : Serveur Média                 │
│                   (Jellyfin Server)                     │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │ Jellyfin Media Server                             │  │
│  │ - Location: /opt/jellyfin                         │  │
│  │ - Auto-Refresh via Webhook/API                    │  │
│  └─────────────────────────┬─────────────────────────┘  │
│                            │                            │
│                            ▼                            │
│  ┌───────────────────────────────────────────────────┐  │
│  │ Targeted User Storage Volume                      │  │
│  │ - Path: /mnt/films/                               │  │
│  │ - User Folders: /User1, /User2, /User3, /communs  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Stack Technique

* **Langage & Orchestration :** Python 3.11 (Scripts de traitement)
* **Moteur IA :** Ollama (LLM local exécuté sur GPU NVIDIA)
* **Réseau & Sécurité :** Gluetun (Mullvad Wireguard + Kill-Switch)
* **Client P2P :** qBittorrent
* **Serveur Média** : Jellyfin
* **Transfert Réseau** : OpenSSH / SFTP / Rsync
* **Environnement :** Docker & Docker Compose

---

## Organisation de l'Arborescence

### SERVEUR 1 : IA & Orchestration *(/opt/jarvis-tor/)*

```text
/opt/jarvis-tor/
├── docker-compose.yml          # Déploiement unique de toute la stack (Ollama, Gluetun, qBit, App)
├── .env                        # Clés VPN, identifiants Jellyfin et configurations SSH
├── app/                        # Code source de l'Orchestrateur Python
│   ├── main.py                 # Boucle principale de surveillance de la Wishlist
│   ├── ollama_client.py        # Communication avec l'API Ollama (Analyse LLM)
│   ├── qbit_client.py          # Gestionnaire de téléchargements qBittorrent
│   ├── transfer.py             # Transfert SFTP/Rsync vers les dossiers utilisateurs du Serveur 2
│   └── requirements.txt        # Dépendances Python (requests, paramiko, etc.)
└── config/                     # Volumes persistants des conteneurs
    ├── wishlist.json           # Whislist que l'IA va lire
    ├── ollama/                 # Stockage des modèles LLM (Llama, Qwen, etc.)
    ├── qbittorrent/            # Configuration et état du client P2P
    └── temp_downloads/         # Zone de téléchargement temporaire local
```

Format JSON (wishlist.json):

```json
[
  {"title": "Interstellar", "year": "2014", "user": "Alain"},
  {"user": "User1", "title": "Inception", "year": 2010},
  {"user": "User2", "title": "Le Voyage de Chihiro", "year": 2001},
  {"user": "User3", "title": "Interstellar", "year": 2014}
  {"user": "Serie", "title": "Yellowstone", "type": "serie", "season": 2, }
]
```

### SERVEUR 2 : Stockage Distant *(/media/storage/)*

```text
/
├── opt/jellyfin/               # Configuration & Docker-Compose de Jellyfin
│   ├── docker-compose.yml
│   ├── config/
│   └── cache/
│
└── mnt/films/                  # Point de montage des bibliothèques Jellyfin
    ├── communs/                # Médias partagés (Films/Séries généraux)
    ├── User1/                  # Profil 1 / Dossier spécifique User1
    ├── User2/                  # Profil 2 / Dossier spécifique User2
    └── User3/                  # Profil 3 / Dossier spécifique User3
```

## Installation & Lancement

### 1. Préparer le Serveur 1

```bash
# Récupérer le dépôt
git clone [https://github.com/juyuroto/jarvis-tor.git](https://github.com/juyuroto/jarvis-tor.git)
cd jarvis-tor

# Configurer les variables d'environnement
cp .env.example .env
nano .env

# Lancer l'ensemble des services sous Docker
docker compose up -d
```

### 2. Configurer le transfert vers le Serveur 2

Générer une clé SSH sur le Serveur 1 et copier la clé publique sur le Serveur 2 pour autoriser le transfert automatique sans mot de passe :

```bash
# Sur le Serveur 1
ssh-keygen -t ed25519 -C "jarvis-tor"
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@IP_SERVEUR_2
```