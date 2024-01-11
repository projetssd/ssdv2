---
layout: default
title: ssdv2
---
Prérecquis, avoir intégré le 2e teamdrive dans rclone.conf (teamdrive_crypt et teamdrive_crypt2 par exemple)

# Créer un 2e sous-dossier rclone
```
sudo mkdir /mnt/rclone2
sudo chown -R $USER:$USER /mnt/rclone2
```


# Dans /etc/systemd/system
```
sudo systemctl stop mergerfs
sudo systemctl stop rclone
sudo nano mergerfs.service
```

Rajouter à coté de /mnt/rclone/monUser (modifier monUser)
```
:/mnt/rclone2/monUser
```

# Dans /etc/systemd/system
```
sudo cp rclone.service rclone2.service
```

Repérer le 2e rclone si besoin : 
```
rclone listremotes
```

```
sudo nano rclone2.service
```

modifier les /mnt/rclone par /mnt/rclone2 (3 fois) + modifier le teamdrive_crypt: par teamdrive_crypt2: (dans mon cas, à adapter)

Enregistrer évidemment

# Relancer
```
sudo systemctl start rclone
sudo systemctl status rclone
```
 
Vérifier si ok
```
sudo systemctl start rclone2
sudo systemctl status rclone2
```
 
Vérifier si ok
```
sudo systemctl start mergerfs
sudo systemctl status mergerfs
```
 
Vérifier si ok

Enfin, relancer Plex... (les applis qui utilisent mergerfs, sinon bug) 
