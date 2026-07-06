# ARCHITECTURE — ClaudeCodeUsage (FR)

## Vue d'ensemble
Application macOS native SwiftUI qui scanne les transcripts JSONL locaux de Claude Code et
affiche un dashboard d'usage (sessions, tours, tokens, cache, coût estimé, graphique quotidien
en barres empilées), avec filtre par projet, répartition du coût par projet/agent/skill, et une
liste de sessions nommées avec détail.

## Source de données
Claude Code écrit un transcript JSONL append-only par session, dans :
```
~/.claude/projects/<chemin-projet-encodé>/<sessionId>.jsonl
~/.claude/projects/<chemin-projet-encodé>/<sessionId>/subagents/agent-*.jsonl   (sous-agents)
```
Les lignes avec `type == "assistant"` et un objet `message.usage` portent les compteurs de
tokens qui nous intéressent : `message.model`, `usage.input_tokens`, `usage.output_tokens`,
`usage.cache_creation_input_tokens`, `usage.cache_read_input_tokens`, plus `sessionId`,
`timestamp`, `cwd` (répertoire de travail réel), et — uniquement sur les tours de sous-agents —
`attributionAgent`/`attributionSkill`. Les lignes `type: "ai-title"` (`{aiTitle, sessionId}`) et
le champ `slug` (présent sur diverses lignes du fichier de session principal) donnent un nom
lisible à la session. L'app n'écrit jamais dans ces fichiers.

## Organisation des modules
```
ClaudeCodeUsage/
  App/ClaudeCodeUsageApp.swift      point d'entrée, fenêtre unique
  Models/
    UsageEvent                      un tour assistant avec son usage (+ cwd, attribution agent/skill)
    DailyUsage                      agrégat par jour (graphique)
    UsageSummary                    agrégat pour les cartes de stats
    DateRangeFilter                 Today/This Week/.../All
    ModelPricing                    table de tarifs par famille de modèle
    SessionInfo                     titre/slug/cwd d'une session (métadonnées hors UsageEvent)
    SessionSummary                  agrégat par session (pour la liste de sessions)
    BreakdownDimension / BreakdownRow  répartition par projet / agent / skill
  Services/
    TranscriptScanner               scan incrémental des fichiers *.jsonl (événements + SessionInfo)
    PricingCalculator                estimation du coût à partir des UsageEvent
  ViewModels/
    UsageViewModel                  filtres (modèle/projet/plage), auto-refresh 30s, agrégation,
                                     répartition par dimension, sessions
  Views/
    ContentView, HeaderView, FilterBarView, StatCardView, DailyUsageChartView,
    BreakdownView, SessionsListView, SessionDetailView
```

## Stratégie de scan
`~/.claude/projects` contient ~80 dossiers de projet, potentiellement des centaines de
transcripts. Pour que l'auto-refresh (30s) reste léger :
- Cache en mémoire par chemin de fichier : `(mtime, octetsDéjàLus, événementsParsés)`
- Chaque scan ne relit que les octets ajoutés depuis la dernière lecture (les transcripts sont
  append-only)
- Le bouton **Rescan** vide le cache et force une relecture complète
- Le scan tourne hors du thread principal (`Task` priorité `.utility`) ; les résultats sont
  republiés via `@MainActor`

## Stack technique
- SwiftUI + Swift Charts (aucune dépendance externe nécessaire pour le MVP)
- Cible de déploiement macOS 14+
- xcodegen : `project.yml` est la source de vérité, le `.xcodeproj` est régénéré et non committé
  (même convention que le projet voisin `RTKInfos`)
- Pas d'App Sandbox — l'app doit lire `~/.claude/projects/**` sans prompt de sélection

## Coût estimé — hypothèse
Il n'existe pas d'API de tarification locale : le coût est estimé via une table de tarifs par
famille de modèle (input / output / cache write / cache read par million de tokens), basée sur
les ratios de tarification connus d'Anthropic (output ≈ 5× input, cache write ≈ 1,25× input,
cache read ≈ 0,1× input). Voir la table exacte dans `PLAN.md`. Les modèles non reconnus héritent
du tarif Sonnet. La table vit dans `ModelPricing.swift` pour être corrigée sans toucher au reste
de l'app.

## Graphique — simplification assumée
La capture de référence affiche deux axes Y incohérents entre eux (Cache en millions,
Input/Output en centaines de milliers) appliqués à une *même* pile de barres — ce qui n'a pas de
sens mathématique cohérent. Le MVP utilise un axe Y unique (auto-formaté K/M) pour les 4 séries
empilées. Un vrai double axe pourra être ajouté plus tard sur demande.

## Pipeline de release (signature, notarisation, Sparkle)
`Scripts/release.sh` (adapté du template du projet voisin RTKInfos) fait, pour une version donnée :
1. Vérifie que `MARKETING_VERSION` dans `project.yml` correspond, régénère le projet Xcode.
2. Build Release avec `CODE_SIGNING_ALLOWED=NO` (contourne un xattr de macOS Sequoia+ qui casse
   `codesign --force` juste après un build Xcode), puis stage l'app via `ditto --noextattr` pour
   purger ces attributs.
3. Signe en profondeur avec Hardened Runtime : `Autoupdate`, `Downloader.xpc`, `Installer.xpc`,
   `Updater.app` imbriqués dans `Sparkle.framework`, puis le framework lui-même, puis l'app.
4. Packages un DMG avec mise en page Finder (app + alias `/Applications`).
5. Soumet à la notarisation Apple (`xcrun notarytool`, profil trousseau `AppliMacVincentGithub`,
   partagé entre les apps de Vincent) et staple le ticket.
6. Signe le DMG avec la clé Sparkle EdDSA (`sign_update --account MarkdownViewer` — cette app
   réutilise la clé partagée entre les apps macOS de Vincent plutôt que d'en générer une propre)
   et écrit `appcast.xml` à la racine du repo, servi via `raw.githubusercontent.com`.

`SUFeedURL`/`SUPublicEDKey` vivent dans `Info.plist` ; `AppDelegate` (via
`@NSApplicationDelegateAdaptor`) câble `SPUStandardUpdaterController` et un item de menu "Check
for Updates…". **Ne jamais régénérer la clé Sparkle** — cela casserait l'auto-update de toutes
les apps qui la partagent.

## Hors scope
- Persistance du cache de scan entre lancements
- Rendu exact du double axe
- Table de tarifs éditable depuis l'UI
- Une clé Sparkle EdDSA dédiée à cette app (elle partage actuellement celle de
  "MarkdownViewer", choix explicite — sacrifie l'isolation de confiance entre apps au profit
  d'une gestion de clé plus simple)
