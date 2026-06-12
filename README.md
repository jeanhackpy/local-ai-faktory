# Real Estate AI — FAktory (Coolify deployment)

> Déploiement Coolify de la stack `jeanhackpy/local-ai-packaged` (12 services Supabase + 7 services IA), sans dépendance à `start_services.py` (script custom de l'ancien repo, maintenant archivé).

## Statut

| Phase | Contenu | Statut |
|---|---|---|
| **Phase 1** | Pilote qdrant (validation pipeline Coolify + Tailscale) | ✅ Validé 2026-06-12 |
| **Phase 2** | Services one-click PG + Redis | 🚫 **BLOQUÉ** — `coolify-db` et `coolify-redis` sont INTERNE à Coolify, pas pour les ressources projet (per doc `/docs/get-started/internal-postgresql-upgrade`). Le compose Phase 3 est self-contained (n8n → supabase-db, redis in-compose). |
| **Phase 3** | Compose complet 18 services (Supabase + IA) | 🚧 Stage local, push en attente OK |
| **Phase 4** | Stratégie de backup DB (Coolify + MinIO) | ⏳ |
| **Phase 5** | Switch définitif + durcissement OCI | ⏳ |

## Architecture cible

```
                ┌─────────────────────────────────────────┐
                │ VPS Oracle (138.2.105.66 / 100.68.166.111 Tailscale) │
                │ Ubuntu 24.04 ARM · 4 CPU · 23.4 GB RAM  │
                │                                                  │
                │  ┌────────────────────────────────────────┐      │
                │  │  Coolify v4.1.2 (Traefik edge :80/443) │      │
                │  │  docker-compose app:                    │      │
                │  │    • pilot-qdrant (Phase 1)             │      │
                │  │    • localai-stack (Phase 3 — 18 svc)   │      │
                │  └────────────────────────────────────────┘      │
                │                                                  │
                │  Self-contained (Phase 3 compose):               │
                │    supabase-db (Postgres 15.8.1 spécialisé)      │
                │    └─ sert aussi de DB à n8n                    │
                │    redis (Valkey 8) ←─ cache n8n + SearXNG      │
                │  Supabase-stack (11 services sur supabase-db):  │
                │    studio, kong, auth, rest, realtime,           │
                │    storage, imgproxy, meta, functions, supavisor │
                │  IA & data (6):                                  │
                │    n8n (Tailscale Mac + public via Traefik)       │
                │    qdrant (Tailscale :6333-6334)                 │
                │    neo4j (Tailscale :7474, :7687)                │
                │    ollama-cpu (internal :11434)                  │
                │    searxng (internal :8080)                      │
                │    minio (internal :9000, :9001)                 │
                │                                                  │
                │  Internes Coolify (NE PAS UTILISER pour apps):   │
                │    coolify-db, coolify-redis, coolify-proxy,     │
                │    coolify-sentinel, coolify-realtime            │
                └──────────────────────────────────────────────────┘
                          ▲                                ▲
                          │ Tailscale                      │ HTTPS public
                          │ (VPS ↔ Mac)                    │ (n8n.recall-agency.com)
                          │                                │
                       ┌──┴──┐                          ┌──┴──┐
                       │ Mac │                          │  ?  │
                       └─────┘                          └─────┘
```

## Mapping Tailscale (ports host → container)

| Service | Host port | Container | Pourquoi |
|---|---|---|---|
| qdrant | 6333, 6334 | qdrant | API REST + gRPC depuis Mac |
| neo4j | 7474, 7687 | neo4j | Browser + Bolt driver |
| supabase-kong | 8000, 8443 | kong | API Supabase (REST, auth, storage) |
| supavisor | 5432, 6543 | pooler | Connexions Postgres directes (session + transaction) |
| ollama-cpu | — | 11434 | Internal — n8n workflows only |
| searxng | — | 8080 | Internal — n8n HTTP Request node only |
| minio | — | 9000, 9001 | Internal — backups scripts only |
| n8n | — | 5678 | Public via Traefik (n8n.recall-agency.com) |

## Repos liés

- **Source originale** (legacy) : `jeanhackpy/local-ai-packaged` — contient le `start_services.py` (archivé post-Phase 5)
- **Ce repo** (cible Coolify) : `jeanhackpy/local-ai-faktory`

## Services exposés publiquement

- **n8n** : `https://n8n.recall-agency.com` (Traefik + Let's Encrypt)

Tout le reste est **Tailscale-only** (`100.68.166.111:PORT`) sauf ollama/searxng/minio (internal-only, accessed via n8n).

## Sécurité

- **Tailscale** : overlay réseau VPS↔Mac (Tailscale ACLs)
- **OCI Security List** : TCP 22/80/443 + UDP 443 + ICMP en ingress (audit 2026-06-12, déjà conforme, NO-OP)
- **Coolify 2FA** : à activer manuellement par l'admin (`recall`)
- **Secrets** : chiffrés côté Coolify (`is_shown_once: true`)
- **coolify-db / coolify-redis** : INTERNES Coolify, JAMAIS pour les ressources projet (per doc)

## Sauvegardes (Phase 4)

- **PostgreSQL** (compose 18, `supabase-db`) : `pg_dump` quotidien via `backups/cron-pgdump.sh` → MinIO
- **n8n** : tarball quotidien → MinIO
- **qdrant** : snapshot quotidien → MinIO
- **neo4j** : `neo4j-admin dump` → MinIO
- **Rétention** : 7j daily, 30j archivage

## Fichiers du repo

| Fichier | Rôle |
|---|---|
| `docker-compose.coolify.yml` | Compose 18 services (Phase 3) |
| `supabase/docker/volumes/db/*.sql` | 7 fichiers init PostgreSQL (cherry-pick `supabase/supabase@main`) |
| `supabase/docker/volumes/api/kong.yml` | Config Kong (cherry-pick) |
| `searxng/settings.yml` | `secret_key` pré-généré, prêt pour Coolify |
| `backups/cron-pgdump.sh` | Backup quotidien Supabase DB → MinIO |
| `.env.coolify.example` | Template des secrets requis (sans valeurs) |
| `.gitignore` | Exclut `.secrets.local` et autres secrets |

## Plan détaillé

Voir `/Users/phil/.claude_minimax/plans/ecoute-je-pense-que-composed-scroll.md` (plan complet validé 2026-06-12, **à corriger** : la section Phase 2 contient une erreur — supabase-db n'est PAS utilisé par n8n).
