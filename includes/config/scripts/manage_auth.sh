#!/bin/bash

# Fonction pour gérer l'authentification des applications (Décembre 2025)
# Interface ergonomique avec checkbox pour 24+ apps
# Récupère les apps installées (Docker)
# Modifie leur authentification via manage_account_yml
# Utilise launch_service pour relancer les apps

function manage_apps_auth() {
    local ANSIBLEVARS="/home/${USER}/.ansible/inventories/group_vars/all.yml"
    
    if [ ! -f "$ANSIBLEVARS" ]; then
        echo -e "${CRED}❌ Fichier non trouvé: $ANSIBLEVARS${CEND}"
        return 1
    fi

    # Récupérer les apps Docker avec traefik
    declare -a apps_list=($(docker ps --format "{{.Names}}" --filter "network=traefik_proxy" 2>/dev/null | sort))

    if [ ${#apps_list[@]} -eq 0 ]; then
        clear
        echo -e "${CRED}❌ Aucune application Docker trouvée${CEND}"
        echo -e "${BWHITE}Appuyer sur ENTER pour continuer${CEND}"
        read -r
        return 1
    fi

    # Initialiser les tableaux
    declare -A app_auth
    declare -A app_selected
    declare -A app_new_auth
    
    for app in "${apps_list[@]}"; do
        local current_auth=$(get_from_account_yml "sub.${app}.auth")
        [ "$current_auth" == "notfound" ] && current_auth="---"
        app_auth["$app"]="$current_auth"
        app_selected["$app"]=0
    done

    # Boucle du menu
    local menu_active=1
    
    while [ $menu_active -eq 1 ]; do
        clear
        echo -e "${BLUE}#################################${NC}"
        echo -e "${BLUE}GESTION DE L'AUTHENTIFICATION DES APPS${NC}"
        echo -e "${BLUE}#################################${NC}"
        echo ""
        echo -e "${BWHITE}Applications (${#apps_list[@]}):${CEND}"
        echo ""
        
        # Afficher apps avec checkbox
        local i=1
        for app in "${apps_list[@]}"; do
            local box="[ ]"
            [ "${app_selected[$app]}" -eq 1 ] && box="[✓]"
            
            local auth_show="${app_auth[$app]}"
            [ -n "${app_new_auth[$app]}" ] && auth_show="${app_new_auth[$app]} (modifié)"
            
            printf "%s %2d) %-20s %s\n" "$box" "$i" "$app" "$auth_show"
            ((i++))
        done
        
        echo ""
        echo -e "${YELLOW}Auth types: 1=basique  2=oauth  3=authelia  4=aucune  5=oauth2-proxy${CEND}"
        echo ""
        echo -e "${BWHITE}Commandes:${CEND}"
        echo "  3       = sélectionner app 3"
        echo "  5:2     = app 5 → oauth"
        echo "  a       = sélectionner TOUT"
        echo "  c       = désélectionner tout"
        echo "  s       = APPLIQUER"
        echo "  q       = quitter"
        echo ""
        
        local cnt=0
        for app in "${apps_list[@]}"; do
            [ "${app_selected[$app]}" -eq 1 ] && ((cnt++))
        done
        [ $cnt -gt 0 ] && echo -e "${CGREEN}$cnt sélectionnée(s)${CEND}" || echo ""
        
        read -p "Commande: " cmd

        if [[ "$cmd" == "q" || "$cmd" == "Q" ]]; then
            menu_active=0
            break
        fi

        if [[ "$cmd" == "a" || "$cmd" == "A" ]]; then
            for app in "${apps_list[@]}"; do app_selected["$app"]=1; done
            continue
        fi

        if [[ "$cmd" == "c" || "$cmd" == "C" ]]; then
            for app in "${apps_list[@]}"; do app_selected["$app"]=0; done
            continue
        fi

        if [[ "$cmd" == "s" || "$cmd" == "S" ]]; then
            menu_active=0
            break
        fi

        # Parse n:type
        if [[ "$cmd" =~ ^([0-9]+):([1-5])$ ]]; then
            local num="${BASH_REMATCH[1]}"
            local type="${BASH_REMATCH[2]}"
            
            if [ $num -ge 1 ] && [ $num -le ${#apps_list[@]} ]; then
                local app="${apps_list[$((num-1))]}"
                
                case $type in
                    1) app_new_auth["$app"]="basique" ;;
                    2) app_new_auth["$app"]="oauth" ;;
                    3) app_new_auth["$app"]="authelia" ;;
                    4) app_new_auth["$app"]="aucune" ;;
                    5) app_new_auth["$app"]="oauth2-proxy" ;;
                esac
                
                app_selected["$app"]=1
                echo -e "${CGREEN}✓ $app → ${app_new_auth[$app]}${CEND}"
                sleep 1
            fi
        elif [[ "$cmd" =~ ^[0-9]+$ ]]; then
            if [ $cmd -ge 1 ] && [ $cmd -le ${#apps_list[@]} ]; then
                local app="${apps_list[$((cmd-1))]}"
                [ "${app_selected[$app]}" -eq 0 ] && app_selected["$app"]=1 || app_selected["$app"]=0
            fi
        fi
    done

    # Appliquer
    if [ $menu_active -eq 0 ] && [[ "$cmd" == "s" || "$cmd" == "S" ]]; then
        clear
        echo -e "${BLUE}APPLIQUER LES MODIFICATIONS${NC}"
        echo ""
        
        local has_changes=0
        local apps_to_modify=()
        
        for app in "${apps_list[@]}"; do
            if [ -n "${app_new_auth[$app]}" ]; then
                has_changes=1
                apps_to_modify+=("$app")
                echo -e "${BWHITE}$app${CEND}: ${app_auth[$app]} → ${CCYAN}${app_new_auth[$app]}${CEND}"
            fi
        done
        
        if [ $has_changes -eq 0 ]; then
            echo -e "${CYELLOW}Aucune modification${CEND}"
            echo -e "${BWHITE}ENTER pour continuer${CEND}"
            read -r
            return 0
        fi
        
        echo ""
        read -p "Confirmer? (y/n): " confirm
        
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            echo ""
            echo -e "${BLUE}Enregistrement...${CEND}"
            
            for app in "${apps_to_modify[@]}"; do
                manage_account_yml "sub.${app}.auth" "${app_new_auth[$app]}"
                [ $? -eq 0 ] && echo -e "${CGREEN}✓ $app${CEND}" || echo -e "${CRED}❌ $app${CEND}"
            done
            
            echo ""
            read -p "Relancer les apps? (y/n): " restart
            
            if [[ "$restart" == "y" || "$restart" == "Y" ]]; then
                echo ""
                for app in "${apps_to_modify[@]}"; do
                    read -p "Recréer $app? (y/n): " choice
                    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
                        echo -e "${BWHITE}Recréation $app${CEND}"
                        launch_service "$app"
                        [ $? -eq 0 ] && echo -e "${CGREEN}✓${CEND}" || echo -e "${CRED}❌${CEND}"
                    fi
                done
                echo -e "${CGREEN}✓ Terminé${CEND}"
            fi
        fi
    fi

    echo ""
    echo -e "${BWHITE}ENTER pour continuer${CEND}"
    read -r
}

function edit_apps_auth() {
    manage_apps_auth "$@"
}
