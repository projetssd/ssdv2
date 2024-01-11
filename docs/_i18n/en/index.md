# What is Kubeseed ? 

Kubeseed is a seedbox (and other tools) project, running on a Kubernetes engine. To do so, we use  [k3s](https://k3s.io/)

# Can I use it ?

This projet aims to simplify the installation and usage of tools for a seebdox. Although, using Kubernetes is not necessarily simple.
It's better to have basis on Linux system administration, and not to be afraid of command line.

This project is in active development, and there should be major modifications to come.

If you're looking for seomthing simplier, I recommand [ssdv2](https://github.com/projetssd/ssdv2) (french only for now) fro the same crew, using docker.

# Installation 

You'll need :
- a fresh isntalled server on Debian 11 or 12 (Ubuntu 22.04 should be ok but not tested)
- a domain name

Not mandatory, but recommended : using cloudflare, it allows to automatically manage subdomains.

It you're using a remote storage with [rclone](https://rclone.org/), you'll need a already configures rclone.conf

At least, ports 80 and 443 should be opened. Other ports should be opened for other applications :

- 32400 for plex
- 30000 for rutorrent
- etc...

Connect on your machine using a user (not root), with sudo rights, and

```
git clone https://github.com/projetssd/kubeseed.git
cd kubeseed
./seedbox.sh
```

And follow the questions

## Install with kickstart and environment variables.

### Environment variables

Several environment variables can be declared before installations, to avoid manual inputs. Variable list is in **kickstart.sample** file.

### Kickstart file

Tou can also copy **kickstart.sample** to **kickstart**, edit its content, and it will be used during installation.

