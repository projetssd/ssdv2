#!/bin/bash
export SCRIPTPATH=/opt/seedbox-compose
export PATH="$HOME/.local/bin:$PATH"

if [ -f "${SCRIPTPATH}/ssddb" ]; then
    export BASEDIR="/opt/seedbox-compose"
    export CONFDIR="/opt/seedbox"

    source ${SCRIPTPATH}/includes/variables.sh
    source ${SCRIPTPATH}/includes/functions.sh
    source ${SCRIPTPATH}/includes/menus.sh
    source ${SCRIPTPATH}/venv/bin/activate

    PYTHONPATH=/opt/seedbox-compose/venv/lib/$(ls /opt/seedbox-compose/venv/lib)/site-packages
    export PYTHONPATH
fi
