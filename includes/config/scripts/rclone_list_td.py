#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script permettant de choisir un teamdrive
dans le rclone.conf
"""
import ssd_rclone

# Choix du team drive
td = ssd_rclone.detect_td()

print("   Shared drives disponibles : ")
ssd_rclone.affiche_drive(td)
