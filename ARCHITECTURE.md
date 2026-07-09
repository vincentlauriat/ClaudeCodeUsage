# ARCHITECTURE — ClaudeCodeUsage (FR)

## Vue d'ensemble
Application macOS native SwiftUI qui scanne les transcripts JSONL locaux de Claude Code et
affiche un dashboard d'usage (sessions, tours, tokens, cache, coût estimé éditable, graphique
quotidien à double axe Y), une grille de cartes de comparaison (tendances sessions/coût, alertes
automatiques, répartition du coût par famille de modèle), un filtre par projet, une répartition
du coût par projet/agent/skill, et une liste de sessions nommées avec détail. Le cache de scan
est persisté entre lancements.

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
    HourlyUsage                     agrégat par heure de la journée (carte "Cost per hour")
    YearlyUsage / MonthlyUsage       agrégat par année / par mois — calculé et publié, sans vue
                                     consommatrice pour l'instant (préparation d'une mise en page
                                     de dashboard plus dense, voir "Grille de cartes" ci-dessous)
    ModelFamily / ModelMixRow        les 4 familles tarifaires en enum à ordre fixe + couleur, et
                                     la part de coût d'une famille (carte "Model mix")
    Insight                         une ligne du panneau Insights & Alerts (niveau + texte)
  Services/
    TranscriptScanner               scan incrémental des fichiers *.jsonl (événements + SessionInfo),
                                     cache persisté sur disque entre lancements
    PricingCalculator                estimation du coût à partir des UsageEvent + PricingSettings
    InsightEngine                    dérive les Insight à partir des événements filtrés + du coût
                                     semaine sur semaine (tendance de coût, modèles sans tarif,
                                     taux de cache)
  ViewModels/
    UsageViewModel                  filtres (modèle/projet/plage), auto-refresh 30s, agrégation,
                                     répartition par dimension, sessions, tarifs éditables, les
                                     comparaisons fixes aujourd'hui/hier et cette semaine/semaine
                                     dernière, les insights
  Views/
    ContentView, HeaderView, FilterBarView, StatCardView, DailyUsageChartView,
    SessionsPerWeekChartView, CostPerHourChartView, InsightsPanelView, ModelMixView,
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

## Performance UI — agrégats mis en cache
`UsageViewModel` publie un compte à rebours d'une seconde (`secondsUntilRefresh`, affiché dans le
header) sur le même `ObservableObject` que les données d'usage. Comme tout changement `@Published`
invalide toutes les vues SwiftUI qui observent cet objet, chaque tick recalculait auparavant
`filteredEvents`/`summary`/`dailyUsages`/`breakdown(for:)`/`sessions` depuis zéro — filtres,
regroupements et sommes de coût sur l'ensemble des événements (des dizaines de milliers de tours),
chaque seconde, indéfiniment. Corrigé en transformant ces propriétés en `@Published` *stockées*,
recalculées uniquement dans `recomputeFiltered()`/`recomputeAll()`, déclenchées par un `didSet` sur
`allEvents`/`sessionInfo`/les trois filtres/`pricingSettings` — donc seulement quand les données
dont elles dépendent changent réellement, pas à chaque rendu.
Deux blocages liés, trouvés après que ce premier correctif n'ait pas suffi :
- `DailyUsageChartView.ChartPoint.id` valait `UUID()` — régénéré aléatoirement à chaque accès à la
  propriété calculée `points`. Swift Charts se base sur ces id `Identifiable` pour savoir quoi
  redessiner ; un id aléatoire lui fait croire que tout le dataset a changé à chaque rendu, et il
  reconstruit tout le graphique au lieu d'ignorer les barres inchangées. Corrigé avec un id
  déterministe `"\(jour)-\(série)"`.
- `UsageViewModel.breakdown(for:)` regroupait les événements par clé dans un dictionnaire
  `[String: (turnCount: Int, tokens: Int, events: [UsageEvent])]`, en ajoutant à `bucket.events`
  via un pattern lecture-copie-mutation-écriture (`var bucket = byKey[key] ?? …;
  bucket.events.append(event); byKey[key] = bucket`). Comme `bucket` et la copie du dictionnaire
  restent toutes deux vivantes un instant, le copy-on-write ne peut pas réutiliser le buffer du
  tableau : chaque ajout recopie tout le bucket accumulé jusque-là — O(n²) pour toute clé qui
  absorbe la majorité des événements (ex. "Direct (main session)" pour les dimensions Agent/Skill,
  d'où un passage à Agent/Skill bien plus lent qu'à Project). Corrigé en accumulant le coût de
  façon incrémentale (`costUSD: Double` par clé) plutôt qu'en collectant un tableau d'événements à
  coûter après coup.

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

## Grille de cartes — évolution du dashboard (Proposition C)
Suite à une exploration graphique (3 maquettes HTML comparant des dispositions, inspirées d'une
référence de dashboard type retail), `ContentView` gagne une grille `LazyVGrid` à 2 colonnes entre
la rangée de stat-cards et le graphique quotidien existant : `SessionsPerWeekChartView` (line
chart cette-semaine-vs-semaine-dernière), `CostPerHourChartView` (bullet bar chart
aujourd'hui-vs-hier), `InsightsPanelView`, et `ModelMixView`. C'était la moins risquée des trois
maquettes (celle qui touche le moins la logique de données existante) — une disposition « grille
de cartes indépendantes » plus proche de la maquette de référence (bulle → équivalents
barre/chiffre héros, cartes hebdo/mensuelles) a été mise en réserve pour une itération suivante,
une fois qu'elle mérite ses propres cartes ; `YearlyUsage`/`MonthlyUsage` existent déjà pour cela
(voir Models ci-dessus), donc cette itération future ne touchera qu'aux vues, pas à la couche de
données.

Ces nouvelles comparaisons (aujourd'hui/hier, cette semaine/semaine dernière) sont calculées dans
`UsageViewModel.recomputeFixedWindows(events:)` à partir de `allEvents` filtré par MODELS/PROJECT
mais **pas** par le filtre RANGE — restreindre une comparaison jour/semaine sur jour/semaine fixe
à une plage arbitraire n'aurait pas de sens. La tendance de coût semaine sur semaine
d'`InsightEngine` utilise cette même fenêtre non filtrée par plage ; ses signaux "modèle sans
tarif" et "taux de cache" utilisent en revanche les événements filtrés par plage normaux, pour
refléter « ce qui est actuellement affiché » comme le reste du dashboard.

**Piège Swift Charts découvert en construisant `CostPerHourChartView`** : un `BarMark` dont le
`x` est un simple `Int` (24 cases horaires, sans unité type `.day` pour former des bandes) ne
dessine silencieusement rien avec une largeur `.ratio(_:)` — le mark exige une largeur absolue
`.fixed(_:)`. Ça a coûté une passe de debug (affichage temporaire des valeurs brutes de l'agrégat
en overlay texte) avant de découvrir que les données étaient correctes depuis le début et que
seul le paramètre de largeur du mark posait problème.

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
