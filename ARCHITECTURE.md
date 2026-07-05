# ARCHITECTURE — ClaudeCodeUsage (FR)

## Vue d'ensemble
Application macOS native SwiftUI qui scanne les transcripts JSONL locaux de Claude Code et
affiche un dashboard d'usage (sessions, tours, tokens, cache, coût estimé, graphique quotidien
en barres empilées).

## Source de données
Claude Code écrit un transcript JSONL append-only par session, dans :
```
~/.claude/projects/<chemin-projet-encodé>/<sessionId>.jsonl
```
Les lignes avec `type == "assistant"` et un objet `message.usage` portent les compteurs de
tokens qui nous intéressent : `message.model`, `usage.input_tokens`, `usage.output_tokens`,
`usage.cache_creation_input_tokens`, `usage.cache_read_input_tokens`, plus `sessionId` et
`timestamp`. L'app n'écrit jamais dans ces fichiers.

## Organisation des modules
```
ClaudeCodeUsage/
  App/ClaudeCodeUsageApp.swift      point d'entrée, fenêtre unique
  Models/
    UsageEvent                      un tour assistant avec son usage
    DailyUsage                      agrégat par jour (graphique)
    UsageSummary                    agrégat pour les cartes de stats
    DateRangeFilter                 Today/This Week/.../All
    ModelPricing                    table de tarifs par famille de modèle
  Services/
    TranscriptScanner               scan incrémental des fichiers *.jsonl
    PricingCalculator                estimation du coût à partir des UsageEvent
  ViewModels/
    UsageViewModel                  filtres, auto-refresh 30s, agrégation
  Views/
    ContentView, HeaderView, FilterBarView, StatCardView, DailyUsageChartView
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

## Hors scope (MVP)
- Signature / notarisation / packaging DMG (pipeline standard du repo, sur demande explicite)
- Auto-update Sparkle
- Persistance du cache de scan entre lancements
- Rendu exact du double axe
- Table de tarifs éditable depuis l'UI
