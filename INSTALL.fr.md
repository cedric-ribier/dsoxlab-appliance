# Guide d'installation

*[English version](INSTALL.md)*

Ce document sert à **utiliser** l'appliance — la télécharger,
l'importer, et arriver à ton premier lab. Si tu cherches à la
**construire** toi-même depuis les sources, voir
[`RELEASE.md`](RELEASE.md) à la place.

> **Ceci est une release de preuve de concept (v0.1.x).** Testée par
> l'auteur et un petit nombre de testeurs externes sur des
> combinaisons matériel/hyperviseur précises — pas encore une matrice
> de compatibilité large. Voir [`PLAN.md`](PLAN.md) pour ce qui est
> validé et ce qui ne l'est pas.

## 1. Avant de télécharger quoi que ce soit — vérifie ta machine

| | Minimum | Confortable |
| --- | --- | --- |
| CPU | 4 vCPU | 8 vCPU |
| RAM | 8 Go | 16 Go |
| Disque | 20 Go libres | 40 Go libres |

Ce sont des minimums pour les labs `shell`. Si tu veux aussi les labs
`vm` (KVM/Incus, installés automatiquement — voir étape 4), ton CPU
hôte a besoin de la **virtualisation imbriquée** (Intel VT-x ou
AMD-V), et elle doit être activée — pas juste physiquement présente.

**Vérifie et active la virtualisation imbriquée maintenant, avant
d'importer quoi que ce soit** — ça ne peut pas se corriger une fois
l'appliance déjà démarrée, seulement avant son tout premier
démarrage :

- **VirtualBox** : dans les réglages de la VM (VM éteinte) →
  *Système → Processeur* → cocher *Activer VT-x/AMD-V imbriqué*.
- **VMware Fusion / Workstation** : dans les réglages de la VM (VM
  éteinte) → *Processeurs* → cocher *Activer les applications
  d'hyperviseur dans cette machine virtuelle*. **Pas activé par
  défaut** — importer et démarrer la VM sans cocher ça d'abord veut
  dire que les labs `vm` ne fonctionneront tout simplement pas, sans
  message d'erreur (l'appliance le détecte proprement et ne fait rien
  de nuisible, mais il te manquera une fonctionnalité sans savoir
  pourquoi).

Si ton CPU ou ton hyperviseur ne supporte pas du tout la
virtualisation imbriquée (fréquent sur d'anciens CPU, certains
environnements de dev hébergés dans le cloud, ou Apple Silicon), pas
de souci — les labs `shell` fonctionnent quand même. Les labs `vm`
non.

## 2. Téléchargement

Récupère le fichier `.ova` et `SHA256SUMS` depuis la
[page Releases](https://github.com/stephrobert/dsoxlab/releases) (ou
la page Releases de ce dépôt, tant que cette proposition n'est pas
fusionnée).

Vérifie le téléchargement avant d'importer quoi que ce soit :
```bash
sha256sum -c SHA256SUMS
```
(macOS : `shasum -a 256 -c SHA256SUMS` si `sha256sum` n'est pas
installé.)

## 3. Import

### VirtualBox
Double-clique sur le `.ova`, ou *Fichier → Importer une application
virtuelle*.

**Avant de la démarrer**, vérifie le réglage de la carte réseau —
VirtualBox pré-sélectionne *une* interface réseau hôte par défaut à
l'import (souvent le Wi-Fi, pas forcément ce que tu veux), sans te
demander confirmation. Dans les réglages de la VM → *Réseau* →
*Adaptateur 1*, confirme qu'il est bien attaché en *Accès par pont* et
pointe vers l'interface réseau sur laquelle tu veux réellement que
l'appliance soit joignable.

### VMware Fusion / Workstation
Double-clique sur le `.ova`, ou *Fichier → Importer*. Avant le premier
démarrage, règle aussi l'option de virtualisation imbriquée de
l'étape 1 si tu veux les labs `vm`.

## 4. Premier démarrage

Le premier démarrage prend plus de temps que les suivants — il fait un
vrai travail de configuration :
- Crée ton compte de connexion.
- Adapte la configuration réseau à ton hyperviseur précis.
- Si la virtualisation imbriquée est disponible et activée : installe
  et configure KVM/libvirt et Incus (nécessite un accès internet).

Connecte-toi avec :
```
login: user
password: MotDePasse
```
Un changement de mot de passe te sera demandé immédiatement — c'est
normal, pas une erreur.

> **Remarque sur le clavier** : cette appliance utilise actuellement
> par défaut une disposition console française/AZERTY. Si ton clavier
> physique utilise une disposition différente, taper `MotDePasse` à
> l'invite de connexion peut produire des caractères inattendus
> (certaines lettres changent de position entre AZERTY et QWERTY, par
> exemple). Si tu es bloqué, depuis n'importe quelle session terminal
> fonctionnelle, essaie `sudo loadkeys us` (ou le code de ta propre
> disposition) pour basculer temporairement, ou observe les caractères
> réels que produit ton clavier en suivant l'invite à l'écran. C'est
> une limitation connue — voir `PLAN.md`.

## 5. Configurer ton catalogue de labs

```bash
dsoxlab catalog list
dsoxlab catalog add <id>
```

Puis vérifie que tout est en ordre :
```bash
dsoxlab doctor
```

## 6. Étapes pas encore automatiques

Ce qui suit est documenté et affiché directement à l'écran par
`dsoxlab` lui-même quand tu en as besoin — ça n'apparaît qu'à partir du
lab `L2` du parcours Linux, moment où tu es censé être à l'aise pour
taper des commandes et suivre des instructions à l'écran (plus
vraiment un débutant, par définition d'avoir terminé le `L1`) :

- **Pool de stockage libvirt/KVM** — doit être créé avant que les labs
  `vm` utilisant ce provider puissent tourner.
- **Réseau et pool de stockage Incus** — même idée, pour le provider
  Incus.
- **Clé SSH** — pas générée par défaut ; lancer
  `dsoxlab instructor bootstrap`.

Cette liste n'est pas exhaustive et grandira au fur et à mesure que ça
sera mieux documenté — si tu tombes sur une étape non listée ici mais
qui devrait l'être, c'est un retour utile pour cette proposition.

## Dépannage

- **Pas de réseau / DHCP ne démarre pas** : vérifie le réglage de la
  carte réseau de l'étape 3 (VirtualBox) — c'est la cause la plus
  fréquente.
- **Les labs `vm` ne fonctionnent pas, aucune erreur affichée** : la
  virtualisation imbriquée n'a pas été activée avant le premier
  démarrage (étape 1). Active-la maintenant, puis redémarre la VM —
  l'appliance retente automatiquement à chaque démarrage jusqu'à
  réussir une fois.
- **Impossible de taper correctement le mot de passe de connexion** :
  voir la remarque clavier de l'étape 4.
- **Autre chose** : vérifie `PLAN.md` pour ce qui est déjà connu comme
  ne fonctionnant pas encore, puis ouvre une issue.
