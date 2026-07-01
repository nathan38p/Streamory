# Streamory

Web app iPhone pour suivre les films et séries vus, en cours ou à voir.

## Lancer en local

```bash
python3 -m http.server 5173
```

Ouvre ensuite `http://localhost:5173`.

## Configuration Supabase

1. Crée un projet Supabase.
2. Exécute `supabase/schema.sql` dans le SQL editor.
3. Active l'auth par email et mot de passe.
4. Copie `config.example.js` vers `config.js` et remplis l'URL Supabase + la clé publishable.

Les réglages dans l'app servent au compte utilisateur, pas à la configuration Supabase.

## TheTVDB

La clé TheTVDB ne doit pas être dans le navigateur ni dans le repo. Ajoute-la comme secret Supabase, puis déploie l'Edge Function:

```bash
supabase functions deploy tvdb-search
supabase secrets set TVDB_API_KEY=your_key
```

`TVDB_PIN` est optionnel selon ton compte TheTVDB. Si TheTVDB t'en fournit un, ajoute-le aussi avec `supabase secrets set TVDB_PIN=your_pin`.

TheTVDB indique que le palier gratuit est disponible pour les projets sous 50k de revenus annuels, avec attribution obligatoire.
