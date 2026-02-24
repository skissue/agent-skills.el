---
name: using-elfeed
description: "Interfaces with elfeed RSS/Atom feed reader in Emacs via elisp evaluation. Use when asked to read, search, tag, or manage RSS/Atom feed entries."
---

# Using elfeed Programmatically

elfeed is an Emacs-based RSS/Atom feed reader with a searchable database. All operations are performed via elisp evaluation in the active Emacs session.

## Critical Rules

- **Always load the database first.** Call `(elfeed-db-load)` before any query if the database may not be loaded yet.
- **Never call `elfeed-update` without the user asking.** Fetching feeds hits the network and can be slow.
- **Content is stored as refs.** Entry content is an `elfeed-ref` struct — you must call `(elfeed-deref (elfeed-entry-content entry))` to get the actual string.

## Data Model

### Entry struct (slots)

| Slot           | Accessor                        | Type                          |
|----------------|---------------------------------|-------------------------------|
| `id`           | `(elfeed-entry-id e)`           | `(url-string . id-string)`   |
| `title`        | `(elfeed-entry-title e)`        | string                        |
| `link`         | `(elfeed-entry-link e)`         | URL string                    |
| `date`         | `(elfeed-entry-date e)`         | float (epoch seconds)         |
| `content`      | `(elfeed-entry-content e)`      | `elfeed-ref` (use `elfeed-deref`) |
| `content-type` | `(elfeed-entry-content-type e)` | symbol (`html` or `nil` for text) |
| `enclosures`   | `(elfeed-entry-enclosures e)`   | list of `(url mime-type length)` |
| `tags`         | `(elfeed-entry-tags e)`         | list of symbols               |
| `feed-id`      | `(elfeed-entry-feed-id e)`      | URL string                    |
| `meta`         | `(elfeed-meta e KEY)`           | arbitrary plist               |

### Feed struct (slots)

| Slot     | Accessor                   | Type       |
|----------|----------------------------|------------|
| `id`     | `(elfeed-feed-id f)`       | URL string |
| `url`    | `(elfeed-feed-url f)`      | URL string |
| `title`  | `(elfeed-feed-title f)`    | string     |
| `author` | `(elfeed-feed-author f)`   | string     |
| `meta`   | `(elfeed-meta f KEY)`      | arbitrary  |

### Getting the feed for an entry

```elisp
(elfeed-entry-feed entry)  ;; => feed struct
(elfeed-feed-title (elfeed-entry-feed entry))  ;; => "Blog Name"
```

---

## 1. Querying Entries

### Iterate the full database (newest first)

`with-elfeed-db-visit` visits every entry from newest to oldest. Use `elfeed-db-return` to exit early.

```elisp
(let (results)
  (with-elfeed-db-visit (entry feed)
    (when (elfeed-tagged-p 'unread entry)
      (push (elfeed-entry-title entry) results))
    (when (>= (length results) 20)
      (elfeed-db-return)))
  (nreverse results))
```

### Get entries for a specific feed

```elisp
(elfeed-feed-entries "https://example.com/feed.xml")
```

### Get a single entry by ID

```elisp
(elfeed-db-get-entry '("https://example.com/feed.xml" . "entry-guid"))
```

### Compile and apply a search filter programmatically

```elisp
(let* ((filter (elfeed-search-parse-filter "@6-months-ago +unread"))
       (func (byte-compile (elfeed-search-compile-filter filter)))
       (results nil))
  (with-elfeed-db-visit (entry feed)
    (when (funcall func entry feed (current-time))
      (push entry results)))
  (nreverse results))
```

---

## 2. Reading Entry Content

Content is stored behind an `elfeed-ref`. Always deref it:

```elisp
(let ((content (elfeed-deref (elfeed-entry-content entry))))
  (if (eq (elfeed-entry-content-type entry) 'html)
      ;; content is an HTML string — you may want to strip tags
      (with-temp-buffer
        (insert content)
        (shr-render-region (point-min) (point-max))
        (buffer-string))
    ;; plain text
    content))
```

---

## 3. Tagging and Untagging

```elisp
;; Add tags (accepts a single entry or a list)
(elfeed-tag entry 'starred)
(elfeed-tag entry-list 'read-later 'important)

;; Remove tags
(elfeed-untag entry 'unread)

;; Check if tagged
(elfeed-tagged-p 'unread entry)  ;; => t or nil
```

### Get all tags in the database

```elisp
(elfeed-db-get-all-tags)  ;; => (unread starred blog emacs ...)
```

---

## 4. Managing Feeds

### List configured feeds

```elisp
(elfeed-feed-list)  ;; => ("https://..." "https://..." ...)
```

### Feed configuration format

`elfeed-feeds` is a list of URLs or `(url tag1 tag2 ...)` for auto-tagging:

```elisp
elfeed-feeds
;; => (("https://nullprogram.com/feed/" blog emacs)
;;     "https://example.com/atom.xml"
;;     ("https://youtube.com/feeds/videos.xml?channel_id=..." video youtube))
```

### Add a feed

```elisp
(elfeed-add-feed "https://example.com/feed.xml" :save t)
```

### Auto-tag rules via hooks

```elisp
;; Tag entries from youtube as 'video
(add-hook 'elfeed-new-entry-hook
          (elfeed-make-tagger :feed-url "youtube\\.com"
                              :add '(video youtube)))

;; Remove 'unread from entries older than 2 weeks
(add-hook 'elfeed-new-entry-hook
          (elfeed-make-tagger :before "2 weeks ago"
                              :remove 'unread))
```

---

## 5. Updating Feeds

Only do this when the user asks:

```elisp
;; Update all feeds
(elfeed-update)

;; Update a single feed
(elfeed-update-feed "https://example.com/feed.xml")
```

---

## 6. Search Filter Syntax

The filter string used by `elfeed-search-set-filter` and `elfeed-search-parse-filter`:

| Component     | Meaning                                   | Example                            |
|---------------|-------------------------------------------|------------------------------------|
| `+tag`        | Entry must have tag                       | `+unread`                          |
| `-tag`        | Entry must NOT have tag                   | `-junk`                            |
| `@date`       | Age limit (no older than)                 | `@6-months-ago`, `@3-days-ago`     |
| `@date--date` | Date range                                | `@2024-01-01--2024-06-01`          |
| `#N`          | Max number of entries                     | `#50`                              |
| `=regex`      | Match feed title or URL                   | `=emacs`, `=youtube\\.com`         |
| `!regex`      | Exclude feed title or URL                 | `!reddit`                          |
| other text    | Regex match against title, link, and feed | `rust programming`                 |

Components are space-separated and ANDed together. Example: `@1-year-ago +unread =emacs #100`

### Set the search filter in the search buffer

```elisp
(elfeed-search-set-filter "@1-week-ago +unread")
```

### Parse a filter into a structured plist

```elisp
(elfeed-search-parse-filter "@6-months-ago +unread =emacs")
```

---

## 7. Database Management

```elisp
;; Load database from disk
(elfeed-db-load)

;; Save database to disk
(elfeed-db-save)

;; Database size (number of entries)
(elfeed-db-size)

;; Compact/garbage-collect the database
(elfeed-db-compact)
```

---

## 8. Interacting with the Search Buffer

```elisp
;; Get selected entries in search buffer (respects region)
(elfeed-search-selected)

;; Get entry at point only (ignore region)
(elfeed-search-selected t)

;; Tag all selected entries
(elfeed-search-tag-all 'starred)

;; Untag all selected entries
(elfeed-search-untag-all 'unread)

;; Open entry in show buffer
(elfeed-show-entry entry)

;; Refresh the search buffer
(elfeed-search-update :force)
```

---

## 9. Metadata

Arbitrary per-entry or per-feed metadata:

```elisp
;; Read
(elfeed-meta entry :my-notes)

;; Write
(setf (elfeed-meta entry :my-notes) "interesting article")
```

---

## 10. OPML Import/Export

```elisp
;; Import feeds from OPML file
(elfeed-load-opml "/path/to/feeds.opml")

;; Export current feeds to OPML
(elfeed-export-opml "/path/to/export.opml")
```

---

## Common Workflows

### Summarize unread entries

```elisp
(progn
  (elfeed-db-load)
  (let (results)
    (with-elfeed-db-visit (entry feed)
      (when (elfeed-tagged-p 'unread entry)
        (push (list :title (elfeed-entry-title entry)
                    :feed (elfeed-feed-title feed)
                    :date (format-time-string "%Y-%m-%d" (elfeed-entry-date entry))
                    :link (elfeed-entry-link entry))
              results))
      (when (>= (length results) 50)
        (elfeed-db-return)))
    (nreverse results)))
```

### Read the content of a specific entry

```elisp
(let* ((entry (car (elfeed-feed-entries "https://example.com/feed.xml")))
       (raw (elfeed-deref (elfeed-entry-content entry))))
  (if (eq (elfeed-entry-content-type entry) 'html)
      (with-temp-buffer
        (insert raw)
        (shr-render-region (point-min) (point-max))
        (buffer-string))
    raw))
```

### Find entries matching a filter string

```elisp
(progn
  (elfeed-db-load)
  (let* ((filter (elfeed-search-parse-filter "@1-month-ago +unread =emacs"))
         (func (byte-compile (elfeed-search-compile-filter filter)))
         (results nil))
    (with-elfeed-db-visit (entry feed)
      (when (funcall func entry feed (current-time))
        (push (cons (elfeed-entry-title entry)
                    (elfeed-entry-link entry))
              results)))
    (nreverse results)))
```

### Mark entries as read

```elisp
(with-elfeed-db-visit (entry feed)
  (when (and (elfeed-tagged-p 'unread entry)
             (string-match-p "old-feed" (elfeed-feed-url feed)))
    (elfeed-untag entry 'unread)))
```
