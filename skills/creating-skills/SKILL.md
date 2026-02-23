---
name: creating-skills
description: Creates well-structured agent skills according to the specification. Use when creating a new skill.
---

# Creating Skills

Creates well-structured agent skills according to the specification.

## Skill Structure

Every skill needs a `SKILL.md` file with YAML frontmatter:

```md
---
name: my-skill-name
description: Does X when Y happens. Use for Z tasks.
---

# Skill Title

Instructions go here.
```

Keep the main SKILL.md under 500 lines. Move detailed reference material to separate files.

### Optional subdirectories
Additional files can be placed in three optional subdirectories. These files are loaded only when required.

- `scripts/`: Contains executable code that agents can run. Scripts should:
  - Be self-contained or clearly document dependencies
  - Include helpful error messages
  - Handle edge cases gracefully
- `references/`: Contains additional documentation that agents can read when needed, such as domain- or task-specific files (finance.md, legal.md, etc.). Keep individual reference files focused. Agents load these on demand, so smaller files mean less use of context.
- `assets/`: Contains static resources:
  - Templates (document templates, configuration templates)
  - Images (diagrams, examples)
  - Data files (lookup tables, schemas)

## Frontmatter Requirements

### name (required)
- Maximum 64 characters
- Lowercase letters (a-z), numbers (0-9), and hyphens only
- Must not start or end with a hyphen
- No consecutive hyphens (`my--skill` is invalid)
- Must match parent directory name exactly
- Use gerund form (verb + -ing): `processing-pdfs`, `analyzing-data`, `managing-deployments`
- Avoid vague names: `helper`, `utils`, `tools`

### description (required)
- Maximum 1024 characters (should be much shorter than 1024 characters)
- Write in third person ("Processes files" not "I process files")
- Include BOTH what the skill does AND when to use it
- Be specific with key terms for discovery

### Optional fields
- `license`: License identifier (e.g., "MIT", "Apache-2.0")
- `compatibility`: Max 500 characters describing compatibility requirements
- `metadata`: Arbitrary metadata object
- `allowed-tools`: List of tools the skill can use

## Directory Structure

### Simple skill (instructions only)
```
skills/my-skill/
└── SKILL.md
```

### Skill with additional files
```
.skills/my-skill/
├── SKILL.md
└── scripts/
    └── my-script.sh
└── resources/
    └── specific-task.md
└── assets/
    └── diagram.png
```

When referencing other files in your skill, use relative paths from the skill root:

```md
See [the reference guide](references/REFERENCE.md) for details.

Run the extraction script:
scripts/extract.py
```

## Writing Effective Instructions

### Do
- Start with a clear one-line summary
- List specific capabilities
- Provide step-by-step workflows
- Include concrete examples
- Reference scripts with execution intent

### Don't
- Explain concepts the model already knows
- Add lengthy introductions or summaries
- Include time-sensitive information in main sections
- Use abstract examples
