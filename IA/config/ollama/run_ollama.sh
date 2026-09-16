#!/bin/bash

echo "Démarrage du serveur Ollama en arrière-plan..."
ollama serve &

echo "Attente du démarrage complet d'Ollama..."
until ollama list > /dev/null 2>&1; do
  sleep 2
done

echo "Ollama est prêt ! Création du modèle personnalisé..."
ollama create llama3.1 -f /model_files/Modelfile

echo "Modèle créé avec succès ! Maintien du conteneur actif..."

wait -n