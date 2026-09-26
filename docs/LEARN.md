# Writing Learn notes

Learn is built from plain Markdown files bundled with the app. Writing a
note is writing a text file; nothing else needs to change.

## Adding a note

Put a `.md` file in the folder of its topic under `assets/learn/`, for
example `assets/learn/decoupling/02-choosing-values.md`.

- The note's **title** is its first `# heading`.
- Notes are listed in **file-name order**, so start names with `01-`, `02-`
  and so on to choose the order.
- Rebuild the app to see it.

Each topic starts with `01-your-first-note.md`, a template showing
everything a note can use. Replace it with your own.

## What a note can use

```markdown
# Title of the note

A paragraph. A blank line starts the next one.

## A heading inside the note

- A bullet point
- Another one

1. A numbered step
2. The next step

> A tip or a warning, drawn in its own box.

**Bold**, *italics*, and `code` for part numbers and values like `100 nF`.
```

## Adding a topic

1. Add it to `assets/learn/categories.json`: an `id` (the folder's name),
   a `title`, a one-line `blurb`, a `short` name for the home page's chips,
   and an `icon`: one of `chip`, `capacitor`, `wave`, `ground`, `speed` or
   `factory`.
2. Make the folder `assets/learn/<id>/` and put its notes in it.
3. List the folder in `pubspec.yaml` under `assets:`. Flutter does not look
   inside folders by itself.

## What's new

The home page's "What's new" strip and page read `assets/changelog.md`. Add
each release at the top:

```markdown
## 1.1.0 — A short title

- What changed
- What else changed
```

The first section is always shown as the version the phone has, so keep it
in step with the `version:` in `pubspec.yaml`.
