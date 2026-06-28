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
3. Active l'auth par email magic link.
4. Dans l'app, ouvre les réglages et colle l'URL Supabase + la clé anon.

Tu peux aussi copier `config.example.js` vers `config.js` et remplir les valeurs.

## TheTVDB

La clé TheTVDB ne doit pas être dans le navigateur. Déploie l'Edge Function:

```bash
supabase functions deploy tvdb-search
supabase secrets set TVDB_API_KEY=your_key TVDB_PIN=your_pin
```

`TVDB_PIN` est optionnel selon ton compte TheTVDB.
