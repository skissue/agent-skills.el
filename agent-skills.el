;;; agent-skills.el --- Agent skills implementation -*- lexical-binding: t -*-

;; Author: Ad <me@skissue.xyz>
;; Maintainer: Ad <me@skissue.xyz>
;; Version: 0.0.1
;; Package-Requires: ((emacs "29.1") (yaml "1.0"))
;; Homepage: https://github.com/skissue/agent-skills.el
;; Keywords: files, tools


;; This file is not part of GNU Emacs

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;;; Commentary:

;; Implementation of the agent skills specification[1] for use
;; with Emacs-native agents and LLM clients.
;;
;; [1] <https://agentskills.io>

;;; Code:

(require 'yaml)

(defun agent-skills--read-file (path)
  "Read the contents of file at PATH as a string."
  (with-temp-buffer
    (insert-file-contents path)
    (buffer-string)))

(defun agent-skills--extract-frontmatter (text)
  "Extract YAML frontmatter string from TEXT.
TEXT should be the contents of a SKILL.md file.  Returns the YAML
string between the opening and closing `---' delimiters, or nil
if no valid frontmatter is found."
  (when (string-match "\\`---\n\\(\\(?:.*\n\\)*?\\)---\n" text)
    (match-string 1 text)))

(defun agent-skills--parse-frontmatter (yaml-string)
  "Parse YAML-STRING into an alist of frontmatter fields.
Returns an alist with string keys.  The following fields are
defined by the specification:
  - \"name\" (required): skill name, max 64 chars
  - \"description\" (required): what the skill does, max 1024 chars
  - \"license\" (optional): license name or reference
  - \"compatibility\" (optional): environment requirements, max 500 chars
  - \"metadata\" (optional): arbitrary key-value mapping
  - \"allowed-tools\" (optional): space-delimited list of pre-approved tools"
  (yaml-parse-string yaml-string :object-type 'alist))

(defun agent-skills--parse-skill-folder (dir)
  "Parse the SKILL.md frontmatter in skill folder DIR.
DIR should be a path to a directory containing a SKILL.md file.
Returns an alist of frontmatter fields, or signals an error if
the SKILL.md file is missing or has no valid frontmatter."
  (let ((skill-file (expand-file-name "SKILL.md" dir)))
    (unless (file-exists-p skill-file)
      (error "No SKILL.md found in %s" dir))
    (let* ((contents (agent-skills--read-file skill-file))
           (fm-string (agent-skills--extract-frontmatter contents)))
      (unless fm-string
        (error "No valid YAML frontmatter found in %s" skill-file))
      (agent-skills--parse-frontmatter fm-string))))

(defun agent-skills--skill-dirs (dir)
  "Return a list of subdirectories in DIR that contain a SKILL.md file."
  (let (result)
    (dolist (entry (directory-files dir t "\\`[^.]"))
      (when (and (file-directory-p entry)
                 (file-exists-p (expand-file-name "SKILL.md" entry)))
        (push entry result)))
    (nreverse result)))

(defun agent-skills--parse-skills (dir)
  "Parse all skills found in DIR.
DIR should be a directory containing skill subdirectories, each
with a SKILL.md file.  Returns a list of alists, one per skill."
  (mapcar #'agent-skills--parse-skill-folder (agent-skills--skill-dirs dir)))

(defun agent-skills-create (&rest dirs)
  "Scan DIRS for agent skills and return a list of parsed skill entries.
Each directory in DIRS should contain skill subdirectories, each
with a SKILL.md file.  Each returned entry is an alist of parsed
frontmatter fields with an additional `path' key holding the
skill subdirectory path."
  (mapcan
   (lambda (dir)
     (let ((expanded (expand-file-name dir)))
       (mapcar
        (lambda (skill-dir)
          (cons (cons 'path skill-dir)
                (agent-skills--parse-skill-folder skill-dir)))
        (agent-skills--skill-dirs expanded))))
   dirs))

(defun agent-skills--load-skill (skills name)
  "Load the SKILL.md contents for skill NAME from SKILLS.
SKILLS is the object returned by `agent-skills-create'.
Returns the full file contents as a string."
  (let ((entry (seq-find (lambda (s) (equal (alist-get 'name s) name)) skills)))
    (unless entry
      (error "No skill named %s" name))
    (agent-skills--read-file (expand-file-name "SKILL.md" (alist-get 'path entry)))))

(defun agent-skills--format-description (skills)
  "Format the tool description string for SKILLS.
SKILLS is the object returned by `agent-skills-create'. Returns a
description matching the skill tool format used by OpenCode."
  (concat
   "Load a specialized skill that provides domain-specific instructions and workflows.\n"
   "\n"
   "When you recognize that a task matches one of the available skills listed below, "
   "use this tool to load the full skill instructions.\n"
   "\n"
   "The skill will inject detailed instructions, workflows, and access to bundled "
   "resources (scripts, references, templates) into the conversation context.\n"
   "\n"
   "<available_skills>\n"
   (mapconcat
    (lambda (s)
      (let-alist s
        (format "  <skill>\n    <name>%s</name>\n    <description>%s</description>\n    <location>%s</location>\n  </skill>"
                .name .description (expand-file-name "SKILL.md" .path))))
    skills
    "\n")
   "\n</available_skills>"))

(defun agent-skills-tool-specs (skills)
  "Return a tool spec plist for SKILLS.
SKILLS is the object returned by `agent-skills-create'.
The returned plist can be passed to a tool constructor via apply,
e.g. (apply #\\='gptel-make-tool (agent-skills-tool-specs skills))."
  (list :name "skill"
        :description (agent-skills--format-description skills)
        :function (lambda (name) (agent-skills--load-skill skills name))
        :args '((:name "name" :type string :description "The name of the skill to load"))
        :category "skills"
        :include t))

(provide 'agent-skills)

;;; agent-skills.el ends here
