---
name: using-mu4e
description: "Interfaces with mu4e email in Emacs via elisp evaluation and the mu CLI. Use when asked to read, search, compose, send, or manage email."
---

# Using mu4e Programmatically

mu4e is an Emacs-based email client backed by the `mu` indexer. You have two interfaces:

1. **`mu` CLI** — fast, non-interactive search and message viewing (always available)
2. **Emacs elisp evaluation** — full mu4e API for composing, sending, marking, and interactive operations (requires a running Emacs with mu4e loaded)

## Critical Rules

- **NEVER send an email unless the user EXPLICITLY instructs you to send it.** Composing a draft is not permission to send. Always leave the compose buffer open for user review unless they say "send it".
- **Never start interactive mu4e sessions.** All operations must be non-interactive or batch-compatible.

## Strategy

- **Prefer the `mu` CLI** for read-only operations (searching, reading messages, extracting data) and for moving/trashing messages. It is fast and produces structured output.
- **Use elisp evaluation** when you need to compose email, manage marks, update the index from within Emacs, or interact with mu4e buffers.
- **Maildir paths vary per system.** Do not assume `/INBOX`. Discover maildir structure with `mu find --fields=m '' | sort -u` if needed.
- **Re-index after CLI mutations.** After using `mu move` or modifying the Maildir on disk, run `mu index` to sync the database.

---

## 1. Searching with `mu find`

```bash
# Basic search
mu find 'from:alice AND subject:report'

# Structured output (s-expression plists — best for parsing)
mu find --format=sexp 'flag:unread' --maxnum 20

# JSON output
mu find --format=json 'date:1w.. AND flag:unread' --maxnum 10

# Custom display fields: d=date, f=from, s=subject, l=path
mu find --fields 'd f s' 'maildir:/INBOX' --maxnum 10

# Sort by date descending
mu find --sortfield=date --reverse 'to:me' --maxnum 5
```

### Query Language Reference

| Field       | Alias   | Short | Type    | Example                           |
|-------------|---------|-------|---------|-----------------------------------|
| `from`      |         | `f`   | phrase  | `from:alice@example.com`          |
| `to`        |         | `t`   | phrase  | `to:bob`                          |
| `cc`        |         | `c`   | phrase  | `cc:team@example.com`             |
| `bcc`       |         | `h`   | phrase  | `bcc:secret@example.com`          |
| `subject`   |         | `s`   | phrase  | `subject:quarterly report`        |
| `body`      |         | `b`   | phrase  | `body:capybara`                   |
| `date`      |         | `d`   | range   | `date:20240101..20240601`         |
| `changed`   |         | `k`   | range   | `changed:30M..`                   |
| `size`      |         | `z`   | range   | `size:1M..5M`                     |
| `flags`     | `flag`  | `g`   | boolean | `flag:unread AND flag:personal`   |
| `maildir`   |         | `m`   | boolean | `maildir:/INBOX`                  |
| `message-id`| `msgid` | `i`   | boolean | `msgid:abc@123`                   |
| `file`      |         | `j`   | boolean | `file:/\.pdf$/`                   |
| `mime`      |         | `y`   | boolean | `mime:image/jpeg`                 |
| `priority`  | `prio`  | `p`   | boolean | `prio:high`                       |
| `tags`      |         | `x`   | boolean | `tags:todo`                       |
| `list`      |         | `v`   | boolean | `list:mu-discuss.example.com`     |
| `language`  | `lang`  | `a`   | boolean | `lang:en`                         |
| `embed`     |         | `e`   | phrase  | `embed:important`                 |

**Logical operators:** `AND`, `OR`, `NOT` (case-sensitive)

**Date ranges:** `date:2024..2025`, `date:1w..` (last week), `date:3d..` (last 3 days), `date:..2024`

**Size ranges:** `size:..1M` (under 1MB), `size:1M..5M`

**Flag values:** `new`, `passed`, `replied`, `seen`, `trashed`, `draft`, `flagged`, `signed`, `encrypted`, `attach`, `unread`, `list`, `personal`, `calendar`

**Combined field shortcuts:** `recip:` (to+cc+bcc), `contact:` (from+recip)

### Regex in queries

Use `/regex/` syntax in boolean fields: `file:/\.docx$/`, `subject:/^\[URGENT\]/`

---

## 2. Viewing Messages with `mu view`

```bash
# Plain text (default)
mu view /path/to/message

# As s-expression (for programmatic parsing)
mu view --format=sexp /path/to/message

# HTML body
mu view --format=html /path/to/message

# With summary
mu view --summary-len=5 /path/to/message

# From stdin
cat message.eml | mu view

# Decrypt
mu view --decrypt /path/to/encrypted-message
```

Get a message path from `mu find`:

```bash
mu find --fields=l 'msgid:abc@123' --maxnum 1
```

---

## 3. Moving and Managing Messages with `mu move`

`mu move` moves messages between maildirs or changes their flags, updating both the filesystem and the mu database.

**Flag letters:** `D` (draft), `F` (flagged), `N` (new), `P` (passed/forwarded), `R` (replied), `S` (seen), `T` (trashed)

```bash
# Move a message to a different maildir
mu move /path/to/message /Archive

# Change flags (set absolute flags)
mu move /path/to/message --flags=SF

# Add a flag (prefix with +)
mu move /path/to/message --flags=+F

# Remove a flag (prefix with -)
mu move /path/to/message --flags=-F

# Trash a message (add Seen + Trashed flags)
mu move /path/to/message --flags=+ST

# Move to maildir AND change flags
mu move /path/to/message /Trash --flags=ST
```

The command prints the new path of the message on success. **Always run `mu index` after using `mu move`.**

---

## 4. Extracting Attachments with `mu extract`

`mu extract` extracts MIME parts (attachments) from message files. Does not require the message to be indexed.

```bash
# List all MIME parts in a message
mu extract /path/to/message

# Save all attachments to the current directory
mu extract --save-attachments /path/to/message

# Save to a specific directory
mu extract --save-attachments --target-dir=/tmp/attachments /path/to/message

# Extract specific parts by number (numbers shown by listing)
mu extract --parts=3,4 /path/to/message

# Overwrite existing files
mu extract --parts=2 --overwrite /path/to/message

# Extract parts matching a filename pattern
mu extract /path/to/message '\.pdf$'

# From stdin
cat message.eml | mu extract --save-attachments
```

---

## 5. Message Plist Structure (sexp format)

When using `--format=sexp` or elisp, messages are plists:

```elisp
(:docid 32461
 :from ((:name "Nikola Tesla" :email "niko@example.com"))
 :to ((:name "Thomas Edison" :email "tom@example.com"))
 :cc ((:name "Rupert The Monkey" :email "rupert@example.com"))
 :subject "RE: what about the 50K?"
 :date (20369 17624 0)
 :size 4337
 :message-id "238C8233AB82D81EE81AF0114E4E74@123.mail.example.com"
 :path "/home/tom/Maildir/INBOX/cur/133443243973_1.10027.atlas:2,S"
 :maildir "/INBOX"
 :priority normal
 :flags (seen))
```

**Address fields** are lists of `(:name NAME :email EMAIL)`. Access with:
- `(mu4e-contact-name contact)` → name or nil
- `(mu4e-contact-email contact)` → email

**Date** is in Emacs `current-time` format.

**Attachments** (only in view, not headers): `(:index 2 :name "photo.jpg" :mime-type "image/jpeg" :size 147331)`

**Note:** Messages from headers search do NOT have `:attachments` or `:body` fields. Only messages opened in the view buffer include these.

---

## 6. Elisp: Reading Message Data

```elisp
;; Get message plist at point (in headers or view buffer)
(mu4e-message-at-point)

;; Extract a field
(mu4e-message-field msg :subject)   ;; => "RE: what about the 50K?"
(mu4e-message-field msg :from)      ;; => ((:name "Nikola Tesla" :email "niko@example.com"))
(mu4e-message-field msg :date)      ;; => (20369 17624 0)
(mu4e-message-field msg :flags)     ;; => (seen)
(mu4e-message-field msg :path)      ;; => "/home/tom/Maildir/..."
(mu4e-message-field msg :maildir)   ;; => "/INBOX"

;; Shorthand for message at point
(mu4e-message-field-at-point :subject)

;; Get rendered message body as string
(mu4e-view-message-text msg)

;; Fetch arbitrary RFC header from message file (slower — reads file)
(mu4e-fetch-field msg "X-Mailer")
(mu4e-fetch-field msg "List-Unsubscribe" t)  ;; t = first value only
```

---

## 7. Elisp: Searching

```elisp
;; Run a search (opens headers buffer with results)
(mu4e-search "from:boss AND flag:unread")

;; Search a specific maildir
(mu4e-search "maildir:/INBOX AND flag:unread")

;; Use bookmarked searches
(mu4e-search-bookmark)

;; Search by maildir
(mu4e-search-maildir)
```

`mu4e-search` is primarily interactive — it populates the headers buffer. For non-interactive data extraction, prefer `mu find --format=sexp` or `mu find --format=json` via the CLI.

---

## 8. Elisp: Composing and Sending Email

**⚠ NEVER call `message-send-and-exit` unless the user has EXPLICITLY asked you to send the email. Default to composing only (leave the buffer open for review).**

```elisp
;; Compose a new message (opens compose buffer)
(mu4e-compose-new "recipient@example.com" "Subject line")

;; With extra headers (CC, BCC, etc.)
(mu4e-compose-new "to@example.com" "Subject"
  '(("Cc" . "cc@example.com")
    ("Bcc" . "bcc@example.com")))

;; Reply to message at point
(mu4e-compose-reply)       ;; reply to sender
(mu4e-compose-reply t)     ;; reply-to-all (wide reply)

;; Forward message at point
(mu4e-compose-forward)

;; Resend as-is to a new address
(mu4e-compose-resend "newrecipient@example.com")
```

### Compose and leave for user review (DEFAULT)

```elisp
(progn
  (mu4e-compose-new "recipient@example.com" "Subject")
  (message-goto-body)
  (insert "Message body here.")
  ;; DO NOT send — leave buffer open for user review
  "draft composed")
```

### Sending programmatically (ONLY when user explicitly requests sending)

After `mu4e-compose-new` opens the compose buffer, to fill and send non-interactively:

```elisp
(mu4e-compose-new "recipient@example.com" "Subject")
;; Now in compose buffer:
(message-goto-body)
(insert "Hello,\n\nThis is the message body.\n\nBest regards")
;; Add attachment
(mml-attach-file "/path/to/file.pdf" "application/pdf" "Description" "attachment")
;; Send — ONLY if user explicitly asked to send
(message-send-and-exit)
```

**Important:** `message-send-and-exit` uses the configured `send-mail-function` (typically `smtpmail-send-it`). Ensure SMTP is configured.

---

## 9. Elisp: Marking and Managing Messages

```elisp
;; In headers buffer — mark message at point
(mu4e-headers-mark-and-next 'trash)    ;; mark for trash
(mu4e-headers-mark-and-next 'refile)   ;; mark for refile
(mu4e-headers-mark-and-next 'delete)   ;; mark for permanent deletion
(mu4e-headers-mark-and-next 'unmark)   ;; remove mark
(mu4e-headers-mark-and-next 'flag)     ;; toggle flagged
(mu4e-headers-mark-and-next 'read)     ;; mark as read
(mu4e-headers-mark-and-next 'unread)   ;; mark as unread

;; Execute all pending marks
(mu4e-mark-execute-all t)  ;; t = no confirmation prompt

;; In view buffer
(mu4e-view-mark-for-trash)
(mu4e-view-mark-for-refile)
(mu4e-view-mark-for-delete)
```

---

## 10. Elisp: Navigation

```elisp
;; Navigate in headers buffer
(mu4e-headers-next)
(mu4e-headers-prev)
(mu4e-headers-next-unread)

;; View message at point
(mu4e-headers-view-message)
```

---

## 11. Updating the Index

```bash
# CLI: index/update
mu index
```

```elisp
;; Elisp: fetch new mail and re-index (runs mu4e-get-mail-command)
(mu4e-update-mail-and-index t)  ;; t = run in background
```

---

## 12. Contexts

mu4e supports multiple email accounts via contexts:

```elisp
;; Switch context by name
(mu4e-context-switch nil "work")
(mu4e-context-switch nil "personal")

;; Current context
(mu4e-context-current)
```

---

## 13. Contacts

```elisp
;; Complete a contact (for use in completion-at-point-functions)
(mu4e-complete-contact)

;; Debug: show contacts cache info
(mu4e-contacts-info)
```

---

## Common Workflows

### Find and summarize unread emails

```bash
mu find --format=sexp 'flag:unread AND maildir:/INBOX' --maxnum 50 --sortfield=date --reverse
```

Parse the sexp output to extract sender, subject, date for each message.

### Read a specific message body

```bash
# 1. Find the message path
path=$(mu find --fields=l 'msgid:specific-id@example.com' --maxnum 1)
# 2. View it
mu view "$path"
```

### Compose a draft via elisp (do NOT send unless user says so)

```elisp
(progn
  (mu4e-compose-new "recipient@example.com" "Subject line")
  (message-goto-body)
  (insert "Message body here.")
  ;; Leave buffer open for user review
  "draft composed")
```

### Trash a message via CLI

```bash
# 1. Find the message path
path=$(mu find --fields=l 'msgid:specific-id@example.com' --maxnum 1)
# 2. Trash it
mu move "$path" --flags=+ST
# 3. Re-index
mu index
```

### Search with date range

```bash
mu find --format=json 'from:alice AND date:2w..' --maxnum 20
```

### Capture a message for later attachment

```elisp
;; While viewing a message
(mu4e-action-capture-message (mu4e-message-at-point))
;; Later, in a compose buffer
(mu4e-compose-attach-captured-message)
```
