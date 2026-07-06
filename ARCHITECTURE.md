# ARCHITECTURE — ClaudeCodeUsage (FR)

## Vue d'ensemble
Application macOS native SwiftUI qui scanne les transcripts JSONL locaux de Claude Code et
affiche un dashboard d'usage (sessions, tours, tokens, cache, coût estimé éditable, graphique
quotidien à double axe Y), avec filtre par projet, répartition du coût par projet/agent/skill, et
une liste de sessions nommées avec détail. Le cache de scan est persisté entre lancements.

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
    ModelPricing                    les 4 tarifs (input/output/cache write/cache read) + formule de coût
    PricingSettings                 les 4 familles de tarifs, éditables, persistées en UserDefaults
    SessionInfo                     titre/slug/cwd d'une session (métadonnées hors UsageEvent)
    SessionSummary                  agrégat par session (pour la liste de sessions)
    BreakdownDimension / BreakdownRow  répartition par projet / agent / skill
  Services/
    TranscriptScanner               scan incrémental des fichiers *.jsonl (événements + SessionInfo),
                                     cache persisté sur disque entre lancements
    PricingCalculator                estimation du coût à partir des UsageEvent + PricingSettings
  ViewModels/
    UsageViewModel                  filtres (modèle/projet/plage), auto-refresh 30s, agrégation,
                                     répartition par dimension, sessions, tarifs éditables
  Views/
    ContentView, HeaderView, FilterBarView, StatCardView, DailyUsageChartView,
    BreakdownView, SessionsListView, SessionDetailView, PricingSettingsView
```

## Stratégie de scan
`~/.claude/projects` contient ~80 dossiers de projet, potentiellement des centaines de
transcripts. Pour que l'auto-refresh (30s) reste léger :
- Cache en mémoire par chemin de fichier : `(mtime, octetsDéjàLus, événementsParsés)`
- Chaque scan ne relit que les octets ajoutés depuis la dernière lecture (les transcripts sont
  append-only)
- Le bouton **Rescan** vide le cache (mémoire + disque) et force une relecture complète
- Le scan tourne hors du thread principal (`Task` priorité `.utility`) ; les résultats sont
  republiés via `@MainActor`
- **Persisté entre lancements** : le cache (`[String: FileState]` + `[String: SessionInfo]`) est
  sérialisé en JSON dans `~/Library/Application Support/ClaudeCodeUsage/scan-cache.json`, chargé
  paresseusement au premier scan du process et réécrit uniquement quand au moins un fichier a
  effectivement eu de nouveaux octets lus — un auto-refresh sans nouvelle activité n'écrit rien.
  Ce cache évite de reparser du JSON déjà vu, mais n'élimine pas le coût de l'énumération du
  répertoire (un `stat()` par fichier reste nécessaire à chaque scan pour détecter les
  changements).

## Stack technique
- SwiftUI + Swift Charts (aucune dépendance externe nécessaire pour le MVP)
- Cible de déploiement macOS 14+
- xcodegen : `project.yml` est la source de vérité, le `.xcodeproj` est régénéré et non committé
  (même convention que le projet voisin `RTKInfos`)
- Pas d'App Sandbox — l'app doit lire `~/.claude/projects/**` sans prompt de sélection

## Coût estimé — tarifs éditables
Il n'existe pas d'API de tarification locale : le coût est estimé via une table de tarifs par
famille de modèle (input / output / cache write / cache read par million de tokens), basée à
l'origine sur les ratios de tarification connus d'Anthropic (output ≈ 5× input, cache write ≈
1,25× input, cache read ≈ 0,1× input) — voir `PricingSettings.default` pour les valeurs. Les
modèles non reconnus héritent du tarif Sonnet. Ces tarifs sont **éditables depuis l'UI**
(`PricingSettingsView`, ouverte via le bouton engrenage du header) et persistés en `UserDefaults` :
Vincent peut les corriger lui-même si Anthropic publie des tarifs différents, sans mise à jour de
l'app.

## Graphique — double axe Y (réplique fidèle de la capture d'origine)
La capture de référence affiche deux axes Y incohérents entre eux (Cache en millions,
Input/Output en centaines de milliers) appliqués à une *même* pile de barres — ce qui n'a pas de
sens mathématique cohérent (le MVP avait initialement simplifié à un axe unique pour cette
raison). Sur demande explicite de Vincent, `DailyUsageChartView` reproduit fidèlement ce double
axe : les 4 séries sont normalisées sur une échelle 0...1 partagée, chacune divisée par le maximum
de *son propre* groupe d'axe (`cacheMax` pour Cache Read/Creation, `ioMax` pour Input/Output —
`UsageSeries.isCacheAxis`), puis deux jeux d'`AxisMarks` (`.leading` formaté via `cacheMax`,
`.trailing` formaté via `ioMax`) sont dessinés aux mêmes fractions `[0, .25, .5, .75, 1]`. Le
résultat est visuellement fidèle à la capture mais garde la même incohérence mathématique
assumée à l'origine.

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
- Une clé Sparkle EdDSA dédiée à cette app (elle partage actuellement celle de
  "MarkdownViewer", choix explicite — sacrifie l'isolation de confiance entre apps au profit
  d'une gestion de clé plus simple)
- Faire tourner la cible `ClaudeCodeUsageTests` (crash pré-existant du test runner, `More than one
  NSApplication instance was created` — voir `TODOS.md`)
