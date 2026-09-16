import sys
import seedbox

"""
CE script sert à lancer une fonction python depuis bash
il faut que la fonction se trouve dans seedbox.py
"""

if len(sys.argv) < 2:
    print("Usage: generique_python.py <fonction>")
    sys.exit(1)

fonction = getattr(seedbox, sys.argv[1], None)
if not callable(fonction):
    print(f"Fonction inconnue : {sys.argv[1]}")
    sys.exit(1)

fonction()
