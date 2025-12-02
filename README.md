# Prérequis : 
 - avoir wsl
 - avoir ubuntu server 24.0.4 (dans le wsl)

## Connexion en tant que root
```bash 
sudo su - root
```

## Création du dossier de travail (ex: simon)
```bash
mkdir simon
cd simon
```

## Récupération du script d'installation de la stack
```bash
git config --global credential.helper "cache --timeout=3600"
git clone https://iut-git.unice.fr/simon/infra
```

## Lancement du script
```bash
chmod +x ./infra/script-init-dev-env.sh
./infra/script-init-dev-env.sh
```




