# PLAN — ClaudeCodeUsage

## Objectif
Application macOS native (SwiftUI) reproduisant le dashboard "Claude Code Usage" fourni en capture :
header avec statut de rafraîchissement, filtres (modèle + plage de dates), cartes de stats
(Sessions, Turns, Input/Output Tokens, Cache Read/Creation, Est. Cost) et un graphique en barres
empilées de l'usage quotidien sur 30 jours.

## Source de données
Claude Code écrit un historique de transcript JSONL par session, dans :
`~/.claude/projects/<projet-encodé>/<sessionId>.jsonl`

Chaque ligne est un objet JSON. Les lignes qui nous intéressent ont `type == "assistant"` et
contiennent `message.usage` :
```
message.model                          -> ex: "claude-opus-4-8"
message.usage.input_tokens
message.usage.output_tokens
message.usage.cache_creation_input_tokens
message.usage.cache_read_input_tokens
sessionId (top-level ou message.sessionId)
timestamp (ISO8601, UTC)
```
Une même requête peut apparaître plusieurs fois avec des `usage.iterations` (retries) — on ne
prend que le total `usage.*_tokens` de la ligne (déjà agrégé par le SDK), pas la somme des
itérations, pour éviter le double comptage.

## Stack technique (aligné sur RTKInfos, projet voisin de `~/DevApps/ClaudeTools`)
- SwiftUI, Swift Charts (natif, pas de dépendance externe)
- macOS 14+ (Sonoma), xcodegen + `project.yml` comme source de vérité pour le projet Xcode
  (`.xcodeproj` non committé, régénéré via `xcodegen generate`)
- Pas d'App Sandbox (comme RTKInfos) : l'app doit lire `~/.claude/projects/**` librement sans
  prompt de sélection de fichier
- Aucune dépendance SPM externe nécessaire pour le MVP (JSON parsing via `Foundation`)

## Architecture
```
ClaudeCodeUsage/
  ClaudeCodeUsage/
    App/ClaudeCodeUsageApp.swift        // entry point, fenêtre unique
    Models/
      UsageEvent.swift                  // 1 tour assistant avec usage
      DailyUsage.swift                  // agrégat par jour (pour le chart)
      UsageSummary.swift                // agrégat pour les stat cards
      DateRangeFilter.swift             // Today/This Week/.../All
      ModelPricing.swift                // table de tarifs par famille de modèle
    Services/
      TranscriptScanner.swift           // scan incrémental des .jsonl
      PricingCalculator.swift           // coût estimé à partir des UsageEvent
    ViewModels/
      UsageViewModel.swift              // filtres, auto-refresh 30s, agrégation
    Views/
      ContentView.swift
      HeaderView.swift                  // titre, updated at, countdown, rescan
      FilterBarView.swift               // dropdown modèles + segmented range
      StatCardView.swift
      DailyUsageChartView.swift         // Swift Charts BarMark empilé
  project.yml
  Info.plist
  ClaudeCodeUsage.entitlements
```

## Scan incrémental (perf)
`~/.claude/projects` contient ~80 dossiers projet, potentiellement des centaines de fichiers
`.jsonl` de quelques centaines à milliers de lignes chacun. Pour que l'auto-refresh (30s) reste
léger :
- Cache en mémoire par fichier : `(mtime, tailleOctetsDéjàLue, eventsExtraits)`
- À chaque scan, on ne relit que les octets ajoutés depuis la dernière lecture (les transcripts
  sont append-only)
- Le bouton **Rescan** vide le cache et force un scan complet
- Le scan tourne hors du main thread (Task priority `.utility`), publication des résultats via
  `@MainActor`

## Filtres
- **Modèle** : "All models" + liste des modèles distincts rencontrés dans les données
- **Plage** : Today, This Week, This Month, Prev Month, 7d, 30d (sélection par défaut), 90d, All
  — calculée avec `Calendar.current` (fuseau local)

## Stat cards
Sessions (nb sessionId distincts dans la plage), Turns (nb de tours assistant), Input Tokens,
Output Tokens, Cache Read, Cache Creation, Est. Cost. Formatage compact K/M (ex: `452.9K`,
`3.19M`) via un formatter dédié.

## Coût estimé — hypothèse de tarification
Pas d'API publique locale pour le prix exact : on applique une table par famille de modèle basée
sur les ratios de tarification connus d'Anthropic (input / output ×5 / cache write ×1.25 input /
cache read ×0.1 input), par million de tokens :

| Famille  | Input | Output | Cache Write | Cache Read |
|----------|-------|--------|--------------|------------|
| Opus     | $15   | $75    | $18.75       | $1.50      |
| Sonnet   | $3    | $15    | $3.75        | $0.30      |
| Haiku    | $1    | $5     | $1.25        | $0.10      |
| Fable    | $3    | $15    | $3.75        | $0.30      | (hypothèse, alignée Sonnet)

Modèle non reconnu → tarif Sonnet par défaut. Cette table est isolée dans `ModelPricing.swift`
pour être ajustable facilement si Anthropic publie des tarifs différents.

## Graphique quotidien — simplification assumée
La capture d'origine affiche un axe Y gauche ("Cache", en millions) et un axe Y droit
("Input/Output", en centaines de milliers) sur le **même** empilement de barres — ce qui est
visuellement trompeur (deux échelles différentes sur une même pile n'ont pas de sens
mathématique). Le MVP utilise un **axe unique cohérent** (tokens, auto-formaté K/M), avec les 4
séries empilées (Input, Output, Cache Read, Cache Creation) et une légende colorée identique à
la capture. Si Vincent veut absolument le double-axe visuel de l'original, on l'ajoutera dans une
itération suivante (overlay de deux charts).

## Étapes
1. Docs projet (ce fichier + COMMANDS/TODOS/MEMORY/CHANGES/ARCHITECTURE/README)
2. git init, scaffold xcodegen (project.yml, Info.plist, entitlements, .gitignore)
3. Modèles + TranscriptScanner
4. PricingCalculator
5. UsageViewModel (filtres, auto-refresh)
6. Vues SwiftUI (fidèles à la capture, thème sombre)
7. `xcodegen generate` + `xcodebuild build`, itérer jusqu'à build propre, lancer l'app pour
   vérification visuelle

## Hors scope (MVP)
- Persistance du cache de scan entre lancements de l'app
- Double axe Y visuel exact de la capture

## Suite — Enrichissement des données JSONL (2026-07-06)
Exploration d'un échantillon de transcripts réels a révélé de nombreux champs non exploités par
le MVP (voir `TODOS.md` → Backlog pour la liste complète). Trois sont retenus pour cette
itération :

### 1. Usage par projet (`cwd`)
Chaque ligne JSONL porte `cwd` (répertoire de travail réel, ex.
`/Users/vincent/DevApps/ClaudeTools/ClaudeCodeUsage`), y compris sur les lignes de sous-agents
(qui héritent du `cwd` du projet parent). On l'ajoute à `UsageEvent` et on l'utilise à la fois
comme filtre (picker "PROJECT" à côté de "MODELS") et comme dimension du nouveau panneau de
répartition (voir point 3).

### 2. Coût par agent / skill (`attributionAgent`, `attributionSkill`)
Ces champs n'apparaissent que sur les tours d'assistant exécutés par un sous-agent (lignes
`isSidechain: true` dans `<sessionId>/subagents/agent-*.jsonl`) — les tours de la conversation
principale ne les ont pas. On les ajoute à `UsageEvent` en `String?`, avec fallback d'affichage
`"Direct (main session)"` quand absents.

### 3. Répartition par dimension — panneau unique
Plutôt que 3 panneaux dupliqués (projet / agent / skill), un seul panneau `BreakdownView` avec un
sélecteur segmenté (Project / Agent / Skill) et une table triée par coût décroissant
(label, tours, tokens, coût). Réutilise `panelStyle()`.

### 4. Sessions nommées (`ai-title`, `slug`)
Les lignes `type: "ai-title"` (`{aiTitle, sessionId}`) et le champ `slug` (présent sur les lignes
user/assistant/system du fichier de session principal) donnent un nom lisible à chaque session, à
la place de l'UUID brut. Ces champs n'étant pas présents sur *chaque* ligne, le scanner maintient
un dictionnaire séparé `sessionId -> SessionInfo` (titre/slug/cwd), peuplé en observant *toutes*
les lignes (pas seulement les tours assistant), construit incrémentalement comme le cache
d'événements et vidé par `reset()`.

`UsageViewModel.sessions` agrège les `UsageEvent` filtrés par `sessionId` (titre depuis
`SessionInfo`, fallback `slug`, fallback UUID tronqué), trié par activité la plus récente. Clic
sur une ligne → `.sheet` `SessionDetailView` (stats de la session + répartition par modèle).

### Modifications d'architecture
- `TranscriptScanner.scan()` retourne désormais `ScanResult { events, sessionInfo }` au lieu de
  `[UsageEvent]` seul — un seul point d'entrée, pas de duplication de la logique de scan
  incrémental.
- `parseLine` est scindé en `parseJSON` (une seule désérialisation par ligne) + `parseEvent(from:)`
  pour éviter de reparser deux fois la même ligne (une fois pour l'événement, une fois pour les
  métadonnées de session).
- Nouveaux modèles : `SessionInfo`, `SessionSummary`, `BreakdownRow`, `BreakdownDimension`.
- Nouvelles vues : `BreakdownView`, `SessionsListView`, `SessionDetailView`. `FilterBarView` gagne
  un picker "PROJECT".

### Hors scope de cette itération (→ `TODOS.md` backlog)
`gitBranch`, `version`, `service_tier`/`inference_geo`, `stop_reason` (troncature `max_tokens`),
répartition par nom d'outil (`tool_use.name`) et taux d'erreur (`tool_result.is_error`), durée des
hooks, erreurs/retries API, temps passé par `mode`/`permissionMode`.

## Suite — Publication (2026-07-05, même jour)
Sur demande explicite de Vincent, le scope a été étendu au-delà du MVP local : repo GitHub
public, signature Developer ID + notarisation + DMG, auto-update Sparkle, release v1.0.0,
landing page GitHub Pages, et mise à jour du portfolio + de lauriat.fr. Tout est fait et vérifié
— détail dans `CHANGES.md` et `ARCHITECTURE_EN.md` (section "Release pipeline"). Ce qui restait
« hors scope MVP » ci-dessus (signature/notarisation/DMG/Sparkle) est donc désormais fait ; seuls
la persistance du cache et le double axe restent en dehors du périmètre livré.

## Suite — Persistance, tarifs éditables, double axe Y (2026-07-06)
Trois derniers items du backlog MVP, implémentés sur demande explicite de Vincent.

### 1. Persistance du cache de scan entre lancements
`TranscriptScanner` gardait son cache `[String: FileState]` (offset/mtime/events) et
`[String: SessionInfo]` uniquement en mémoire — un redémarrage de l'app relisait tous les
transcripts depuis zéro. `UsageEvent`, `SessionInfo` et `FileState` deviennent `Codable` ; un
`PersistedCache` (les deux dictionnaires) est chargé paresseusement au premier `scan()` depuis
`~/Library/Application Support/ClaudeCodeUsage/scan-cache.json`, et réécrit après `scan()`
uniquement si au moins un fichier a effectivement eu de nouveaux octets lus (`scanFile` retourne
désormais un `Bool`) — un auto-refresh de 30s sans nouvelle activité n'écrit rien sur disque.
`reset()` (bouton Rescan) supprime aussi le fichier de cache, pour repartir sur une base saine.

### 2. Tarifs de coût configurables depuis l'UI
`ModelPricing` devient `Codable`. Nouveau `PricingSettings` (Codable) qui regroupe les 4 tarifs
(Opus/Sonnet/Haiku/Fable) avec `.default` reprenant exactement les valeurs actuellement en dur, et
un lookup `pricing(forModel:)` identique à l'ancien `ModelPricing.forModel`. Persisté en
`UserDefaults` (JSON encodé sous une clé dédiée) — pas besoin d'un fichier séparé, c'est un simple
réglage utilisateur. `UsageViewModel` porte `@Published var pricingSettings`, sauvegardé à chaque
changement. `PricingCalculator.estimatedCostUSD` et `SessionSummary.init` prennent désormais un
`PricingSettings` en paramètre au lieu d'utiliser la table figée. Nouvelle vue
`PricingSettingsView` (Form avec les 16 champs éditables + bouton "Reset to Defaults"), ouverte via
un bouton engrenage dans `HeaderView`.

### 3. Double axe Y visuel exact de la capture
Annule la décision précédente ("axe Y unique, simplification assumée") sur demande explicite de
Vincent : la capture d'origine a deux axes Y avec des échelles différentes (Cache en millions à
gauche, Input/Output en centaines de milliers à droite) appliquées à la même pile de barres.
Reproduit en normalisant chaque série par le maximum de son propre groupe d'axe (`cacheMax` pour
Cache Read/Creation, `ioMax` pour Input/Output) vers une échelle commune 0...1, puis en dessinant
deux jeux d'`AxisMarks` (`.leading` formaté via `cacheMax`, `.trailing` formaté via `ioMax`) aux
mêmes fractions `[0, 0.25, 0.5, 0.75, 1.0]`. `UsageSeries` gagne `isCacheAxis` pour savoir quel
groupe utiliser. Le résultat est fidèle à la capture mais garde la même incohérence
mathématique assumée qu'à l'origine (deux échelles sur une même pile) — documenté explicitement
dans `ARCHITECTURE.md`/`ARCHITECTURE_EN.md`.
