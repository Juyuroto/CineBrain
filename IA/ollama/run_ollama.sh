#!/bin/bash

MODEL="${OLLAMA_MODEL:-llama3.1}"

echo "Démarrage du serveur Ollama en arrière-plan..."
ollama serve &

echo "Attente du démarrage complet d'Ollama..."
until ollama list > /dev/null 2>&1; do
  sleep 2
done

if [ -f /model_files/Modelfile ]; then
  echo "Ollama est prêt ! Création du modèle personnalisé '$MODEL'..."
  ollama create "$MODEL" -f /model_files/Modelfile
elif ! ollama show "$MODEL" > /dev/null 2>&1; then
  # Premier démarrage : le modèle utilisé par le backend n'est pas encore téléchargé
  echo "Ollama est prêt ! Téléchargement du modèle '$MODEL'..."
  ollama pull "$MODEL"
fi

echo "Modèle '$MODEL' disponible. Maintien du conteneur actif..."
wait
