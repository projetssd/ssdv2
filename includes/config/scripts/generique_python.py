import sys
import seedbox

"""
CE script sert à lancer une fonction pyehon depuis bash
il faut que la fonction se trouve dans seedbox.py
"""

eval('seedbox.' + sys.argv[1] + '()')
