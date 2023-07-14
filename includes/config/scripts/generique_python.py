import sys
import ssdv2

"""
CE script sert à lancer une fonction pyehon depuis bash
il faut que la fonction se trouve dans kubeseed.py
"""

eval('kubeseed.' + sys.argv[1] + '()')