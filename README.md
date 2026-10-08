# AgroAssist — test app for filtering recommendations 🌾

A simple one-page web app that tests the recommendation schema: the employee
picks **crop → disease → growth phase** and gets a structured recommendation
(product + dosage) from the database.

## What's in this folder

| File | Description |
|---|---|
| `agroassist.db` | SQLite database (created by `seed.py`) |
| `seed.py` | Creates/resets `agroassist.db` with sample data |
| `app.py` | Web server (Python standard library only — no installation needed) |
| `index.html` | The UI (3 dropdowns + results table) |
| `migration_v2.sql` | The approved PostgreSQL migration (for later use) |

## Prerequisites

- Python 3 (3.8+). Check: `python3 --version`
- Nothing else — no `pip install`, no node, no database server.

## How to run it

Open a terminal in this folder:

```bash
cd "/Users/viktor/Documents/AgroAssist LongCat 2.5 "
```

**1. Create the database** (first time only, or whenever you want to reset the
sample data):

```bash
python3 seed.py
```

This deletes and recreates all tables and inserts 48 products, 6 crops,
15 diseases, 4 phases, and 90 recommendations.

**2. Start the server:**

```bash
python3 app.py
```

You'll see: `AgroAssist работи на http://localhost:8000`

**3. Open in the browser:**

```
http://localhost:8000
```

## How to use it

1. Pick a **Crop** (e.g. лозје / vine)
2. Pick a **Disease / problem** (e.g. пламеница / downy mildew)
3. Pick a **Growth phase** (e.g. Фаза 1 – растење)

The app filters the recommendations automatically and shows a table with:
product, category, active substance, **dosage**, notes, price, and stock.

If there's no exact recommendation for the chosen phase, it shows the
products that work for the same crop + disease in *other* phases (with the
phase labelled). If there's nothing at all — it shows a message that this
combination has no recommendation.

## Test examples

- `лозје` + `пламеница` + `Фаза 1` → 2 recommendations with dosages (Арметил комби, Манамид)
- `лозје` + `молец` + `Фаза 1` → no exact match, shows other phases instead
- `праски` + `кадравост на праска` + `Фаза 1 / Фаза 4` → different product per phase
- `домат` + `молец` + `Фаза 3` → 3 alternative products

## Important notes

- **The data is sample data.** The names of the 48 products, the crops, and
  the diseases are real (yours), but categories, active substances, prices,
  stock, expiry dates, and all dosages are made up — for testing only.
- The dosage lives exclusively in the `recommendation` table (not on the
  product), which is what allows 1 product to be recommended for multiple
  diseases with different dosages and in different phases.
- The database is SQLite only for this test. For production there's
  `migration_v2.sql` for PostgreSQL (same structure).