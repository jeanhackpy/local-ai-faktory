# Real Estate AI — FAktory (Coolify deployment)

> Déploiement Coolify de la stack `jeanhackpy/local-ai-packaged` (12 services Supabase + 7 services IA), sans dépendance à `start_services.py` (script custom de l'ancien repo, maintenant archivé).

## Statut

| Phase | Contenu | Statut |
|---|---|---|
| **Phase 1** | Pilote qdrant (validation pipeline Coolify) | 🚧 en cours |
| Phase 2 | One-click services Coolify (PostgreSQL, Redis) | ⏳ |
| Phase 3 | Compose complet 18 services (Supabase + IA) | ⏳ |
| Phase 4 | Stratégie de backup DB (Coolify + MinIO) | ⏳ |
| Phase 5 | Switch définitif + durcissement OCI | ⏳ |

## Architecture cible

```
                ┌─────────────────────────────────────────┐
                │ VPS Oracle (138.2.105.66 / 100.68.166.111 Tailscale) │
                │ Ubuntu 22.04 ARM · 4 CPU · 23.4 GB RAM  │
                │                                                  │
                │  ┌────────────────────────────────────────┐      │
                │  │  Coolify v4.1.2 (Traefik edge :80/443) │      │
                │  │  One-click services:                    │      │
                │  │    • pg-n8n (PostgreSQL 16)             │      │
                │  │    • redis-shared (Valkey 8)            │      │
                │  │  docker-compose app:                    │      │
                │  │    • localai-stack (18 services)        │      │
                │  └────────────────────────────────────────┘      │
                │                                                  │
                │  Supabase-stack (12):                            │
                │    studio, kong, auth, rest, realtime,           │
                │    storage, imgproxy, meta, functions,           │
                │    db (postgres 15.8.1), supavisor               │
                │  IA & data (6):                                  │
                │    n8n, qdrant, neo4j, ollama-cpu, searxng, minio│
                └──────────────────────────────────────────────────┘
                          ▲                                ▲
                          │ Tailscale                      │ HTTPS public
                          │ (VPS ↔ Mac)                    │ (n8n.recall-agency.com)
                          │                                │
                       ┌──┴──┐                          ┌──┴──┐
                       │ Mac │                          │  ?  │
                       └─────┘                          └─────┘
```

## Repos liés

- **Source originale** (legacy) : `jeanhackpy/local-ai-packaged` — contient le `start_services.py` (archivé post-Phase 5)
- **Ce repo** (cible Coolify) : `jeanhackpy/local-ai-faktory`

## Services exposés publiquement

- **n8n** : `https://n8n.recall-agency.com` (Traefik + Let's Encrypt)

Tout le reste (Supabase, Qdrant, Neo4j, Ollama, SearXNG, MinIO) est **Tailscale-only** (`100.68.166.111:PORT`).

## Sécurité

- **Tailscale** : overlay réseau VPS↔Mac (Tailscale ACLs)
- **OCI Security List** : TCP 22/80/443 + UDP 443 + ICMP en ingress (audit 2026-06-12, déjà conforme)
- **Coolify 2FA** : à activer manuellement par l'admin (`recall`)
- **Secrets** : chiffrés côté Coolify (`is_shown_once: true`)

## Sauvegardes

- **PostgreSQL** (pg-n8n) : backup Coolify natif → MinIO
- **Supabase DB** : `pg_dump` quotidien via `backups/cron-pgdump.sh` → MinIO
- **n8n / Qdrant / Neo4j** : tarball quotidien → MinIO
- **Rétention** : 7j daily, 30j archivage

## Plan détaillé

Voir `/Users/phil/.claude_minimax/plans/ecoute-je-pense-que-composed-scroll.md` (plan complet validé 2026-06-12).
