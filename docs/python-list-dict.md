## Listes

Une liste est une structure de données qui contient une série de valeurs. Python autorise la construction de liste contenant des valeurs de types différents (par exemple entier et chaîne de caractères), ce qui leur confère une grande flexibilité. Une liste est déclarée par une série de valeurs (n'oubliez pas les guillemets, simples ou doubles, s'il s'agit de chaînes de caractères) séparées par des virgules, et le tout encadré par des crochets.
#### Notation python
```
maliste = ["element1", "element2", "element3"]
```
#### Notation yaml : chaque élément d'une liste est précédé d'un tiret
```
maliste:
- element1
- element2
- element3
```

Les elements d'une liste sont appelés par leur index
```
>>> print(maliste[0])
element1
>>> print(maliste[2])
element3
```

## Dictionnaires
Les dictionnaires sont des collections non ordonnées d'objets, c'est-à-dire qu'il n'y a pas de notion d'ordre (i.e. pas d'indice). On accède aux valeurs d'un dictionnaire par des clés
##### Notation python1
```
mondictionnaire = {}
mondictionnaire['macle1'] = 'mavaleur1'
mondictionnaire['macle2'] = 'mavaleur2'
```
#### Notation python 2
```
mondictionnaire = {"macle1": "mavaleur1", "macle2": "mavaleur2"}
```
On remarque qu'un json est en fait un dictionnaire
#### Notation yaml
```
"mondictionnaire":
   "macle1": "mavaleur1"
   "macle2": "mavaleur2"
 ```
Les éléments d'un dictionnaire sont appelés par leur clé
```
>>> print(mondictionnaire["macle1"])
mavaleur1
```
Attention, avec ansible, on peut accéder à une valeur d'un dictionnaire en utilisant le "dot notation" (par exemple mavaleur = mondictionnaire.macle). Cette notation proche du javascript n'est pas autorisée en python, ou il faut utiliser la "bracket notation" : mavaleur = mondocitionnaire["macle"], notation qui est aussi reconnue par ansible
## Utilisation avancée des dictionnaires / listes
### Dictionnaires
Un dictionnaire est toujours un ensemble de clés/valeurs. Les clés sont toujours des chaines de caractères. Toutefois, les valeurs peuvent être n'importe quel objet, une chaine de caractère, un numérique, mais aussi une liste, ou un autre dictionnaire
Exemple d'enregistrement uCmdb : la valeur de la clé "properties" est un dictionnaire
#### Notation json
```
{
 "id" : "492ca83d34c1b45c8faac4e6bff06f14",
 "globalId" : null,
 "type" : "serveur_ns",
 "properties" : {
  "name" : "myname",
  "environnement_ns" : "TEST ET RECETTE",
  "host_server_type_ns" : "test1",
  "appartenance_ns" : "MUTUALISE"
  },
 "attributesQualifiers" : null,
 "displayLabel" : null,
 "label" : "Serveur"
}
```
#### Notation yml
```
id: 492ca83d34c1b45c8faac4e6bff06f14
globalId: null
type: serveur_ns
properties:
  name: myname
  environnement_ns: TEST ET RECETTE
  host_server_type_ns: test1
  appartenance_ns: MUTUALISE
attributesQualifiers: null
displayLabel: null
label: Serveur
```
Autre exemple :
environnements est un dictionnaire

La valeur environnements['DEVELOPPEMENT'] est un dictionnaire comprenant deux clés (reseau1 et reseau2)

La valeur environnements['DEVELOPPEMENT']['reseau1'] est un dictionnaire comprenant une seule clé (company)
etc...

environnements['DEVELOPPEMENT']['LBP'']['VM VMWARE'] est une liste
#### Notation json (dans cette notation, une liste est encadrée par des crochets, comme une déclaration python classique)
```
{
  "environnements": {
    "DEVELOPPEMENT": {
      "reseau1": {
        "company": {
          "VM VMWARE": [
            "machine1",
            "machine2",
            "machine3",
            "machine4",
            "machine5",
            "machine6",
            "machine7",
            "machine8"
          ]
        }
      },
      "reseau2": {
        "company": {
          "SERVEUR DISCRET": [
            "machine9",
            "machine10",
            "machine11",
            "machine12",
            "machine13"
          ],
          "VM MICROSOFT": [
            "machine14"
          ],
          "VM VMWARE": [
            "machine15",
            "machine16",
            "machine17"
          ]
        }
      }
    }
  }
}
```
#### Notation yml
```
environnements:
 DEVELOPPEMENT:
  reseau1 :
   company:
    VM VMWARE:
     - machine1
     - machine2
     - machine3
     - machine4
     - machine5
     - machine6
     - machine7
     - machine8
  reseau2:
   company:
    SERVEUR DISCRET:
     - machine9
     - machine10
     - machine11
     - machine12
     - machine13
    VM MICROSOFT:
     - machine14
    VM VMWARE:
     - machine15
     - machine16
     - machine17
 ```

### Listes
De même que pour les dictionnaires, chaque élément de liste peut être une autre liste ou un dictionnaire.
#### Notation python
```
[
 "ucmdbId",
 "globalId",
 {
  "name" : "montest",
  "environnement_ns" : "TEST ET RECETTE",
  "host_server_type_ns" : "desc",
  "appartenance_ns" : "MUTUALISE"
  },
 "attributesQualifiers",
  [
    "liste2_elt1",
    "liste2_slt2"
  ]
]
```
#### Notation yml
```
- ucmdbId
- globalId
- name: montest
  environnement_ns: TEST ET RECETTE
  host_server_type_ns: desc
  appartenance_ns: MUTUALISE
- attributesQualifiers
- - liste2_elt1
    - liste2_slt2
```
