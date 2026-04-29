# Context-Based Slide Image Analysis for PowerPoint

A Ruby on Rails app that lets you upload a `.pptx` deck, extracts slide images, and generates **context-aware slide titles and short analyses** using Google’s Generative Language API. Results are shown in the UI and exported as a downloadable **DOCX report**.

- Demo-first workflow: upload → analyze → download report
- Authenticated: Google SSO (OAuth)
- Designed to stay within strict API rate limits

## Motivation

When you’re working with large slide decks, it’s easy to lose consistent narrative and meaningful descriptions of visuals (charts, photos, screenshots). This project helps:

- quickly summarize what each slide’s visuals communicate
- maintain context across slides (rolling context window)
- generate a shareable DOCX report for review/editing

## Demo

- [Demo video](https://drive.google.com/file/d/14lzmb8Q8ZiQhROS9ltQjyzh9bDkJmtJY/view?usp=sharing)

## Architecture

- System overview: [`ARCHITECTURE.md`](./ARCHITECTURE.md)

## Features

- Upload `.pptx` (<= 50 slides)
- Extract slide images from the deck
- Generate, per image:
  - a concise context-aware title
  - a 2–3 sentence contextual analysis
- Download a DOCX report
- Client-side enforcement of rate limits (per Rails process):
  - 30 RPM, 15K TPM, 14.4K RPD

## Tech Stack

- Ruby 3.3.4 / Rails 8.0.3
- SQLite (dev/test)
- OmniAuth Google OAuth2 (SSO)
- Faraday (HTTP)
- htmltoword (HTML → DOCX)

## Setup

### 1) Prerequisites

- Ruby **3.3.4**
- Bundler
- Node is *not* required for this project’s core flow (Rails importmap)

### 2) Install dependencies

```bash
bundle install
```

### 3) Rails credentials / `master.key`

This app uses Rails encrypted credentials (`config/credentials.yml.enc`).

- **Do not commit** `config/master.key` to source control.
- Some configuration (optionally including Google OAuth credentials) can live in encrypted credentials.
- **If you choose to store Google OAuth credentials in Rails credentials, you MUST provide the master key** (either via `config/master.key` locally or `RAILS_MASTER_KEY`).

In development you can provide the key via either:
- a local `config/master.key` file (kept private), or
- an environment variable:

```bash
export RAILS_MASTER_KEY="<your master key>"
```

If you don’t have the key (fresh clone), you can generate new credentials:

```bash
EDITOR="nano" bin/rails credentials:edit
```

That will create a new `config/master.key` locally and open the credentials file for editing.

### 4) Configure environment variables

Copy the example file:

```bash
cp .env.example .env
```

Then edit `.env` and set values.

#### Gemini / Generative Language API

Required:
- `GEMINI_API_KEY` (Get from https://ai.google.dev/)

Optional:
- `GEMINI_MODEL` (default: `gemma-3-27b-it`)
- `GEMINI_CONTEXT_WINDOW` (default: `4`)

Note: Not all model names are available via the same API version/method. If you see a 404 like “model not found for generateContent”, set a fallback model:

- `GEMINI_FALLBACK_MODEL` (example: `gemini-2.5-flash-lite`)

Rate limit tuning (defaults enforce the assignment limits):
- `GEMINI_MAX_RPM` (default 30)
- `GEMINI_MAX_TPM` (default 15000)
- `GEMINI_MAX_RPD` (default 14400)

#### Google SSO (OAuth)

You need a Google OAuth “Web application” client.

1. Go to Google Cloud Console → APIs & Services → Credentials
2. Create **OAuth client ID** → **Web application**
3. Add Authorized redirect URI:

```
http://127.0.0.1:3000/auth/google_oauth2/callback
```

4. Add Authorized JavaScript origin:

```
http://127.0.0.1:3000
```

##### Option A (recommended): configure via `.env` / ENV vars

Set these env vars in `.env`:

- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`

This is the simplest local setup and does **not** require `RAILS_MASTER_KEY`.

##### Option B: configure via Rails encrypted credentials (requires master key)

Instead of ENV vars, you can store these in Rails credentials. This requires the master key.

Edit credentials:

```bash
EDITOR="nano" bin/rails credentials:edit
```

Add:

```yaml
google:
  client_id: "<your client id>"
  client_secret: "<your client secret>"
```

Then provide the key at runtime via either:

- `config/master.key` (local file), or
- `RAILS_MASTER_KEY` environment variable


If neither ENV vars nor encrypted credentials are set, the app will raise on boot:

> "Google OAuth credentials missing. Set GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET or configure credentials.google."

This originates from `config/initializers/omniauth.rb`, which loads credentials from **ENV first**, then falls back to **Rails credentials**.

### 5) Database setup

```bash
bin/rails db:create
bin/rails db:migrate
```

### 6) Run the server

```bash
bin/rails server
```

Then open: http://127.0.0.1:3000

## Usage

1. Log in with Google SSO
2. Upload a `.pptx` and click **Launch analysis**
3. Review per-slide titles in the UI
4. Download the DOCX analysis report

## Security notes

- **Never commit** `config/master.key`.
- API keys should be in `.env` (local) or secret manager in production.
- Sensitive params are filtered in logs via `config/initializers/filter_parameter_logging.rb`.

## Author

**Shravan Bhat**  
Email: shrabhat@tamu.edu  
UIN: 735007755
