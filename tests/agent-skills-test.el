;;; agent-skills-test.el --- Tests for agent-skills.el -*- lexical-binding: t -*-

;;; Commentary:

;; ERT test suite for agent-skills.el.

;;; Code:

(require 'ert)
(require 'agent-skills)

(defvar agent-skills-test--dir
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing this test file.")

(defvar agent-skills-test--skills-dir
  (expand-file-name "skills/" agent-skills-test--dir)
  "Directory containing test skill fixtures.")

;;; Helper to build a temp skill tree

(defun agent-skills-test--make-skill-dir (parent name frontmatter body &optional extra-files)
  "Create a skill directory NAME under PARENT with FRONTMATTER and BODY.
EXTRA-FILES is an alist of (RELATIVE-PATH . CONTENTS) for bundled files.
Returns the skill directory path."
  (let ((dir (expand-file-name name parent)))
    (make-directory dir t)
    (with-temp-file (expand-file-name "SKILL.md" dir)
      (when frontmatter
        (insert "---\n" frontmatter "---\n"))
      (insert body))
    (dolist (f extra-files)
      (let ((fpath (expand-file-name (car f) dir)))
        (make-directory (file-name-directory fpath) t)
        (with-temp-file fpath
          (insert (cdr f)))))
    dir))

;; -------------------------------------------------------------------
;;; 1. agent-skills--extract-frontmatter
;; -------------------------------------------------------------------

(ert-deftest agent-skills-test-extract-frontmatter/valid ()
  "Extracts YAML between --- delimiters."
  (should (equal "name: foo\n"
                 (agent-skills--extract-frontmatter "---\nname: foo\n---\nbody"))))

(ert-deftest agent-skills-test-extract-frontmatter/no-frontmatter ()
  "Returns nil when no frontmatter delimiters exist."
  (should-not (agent-skills--extract-frontmatter "just body text")))

(ert-deftest agent-skills-test-extract-frontmatter/empty-frontmatter ()
  "Returns empty string when frontmatter block is empty."
  (should (equal "" (agent-skills--extract-frontmatter "---\n---\nbody"))))

(ert-deftest agent-skills-test-extract-frontmatter/not-at-start ()
  "Returns nil when --- doesn't start at beginning of text."
  (should-not (agent-skills--extract-frontmatter "text\n---\nname: foo\n---\n")))

(ert-deftest agent-skills-test-extract-frontmatter/multiline ()
  "Extracts multi-line frontmatter."
  (let ((text "---\nname: foo\ndescription: bar\nlicense: MIT\n---\nbody"))
    (should (equal "name: foo\ndescription: bar\nlicense: MIT\n"
                   (agent-skills--extract-frontmatter text)))))

(ert-deftest agent-skills-test-extract-frontmatter/triple-dash-in-body ()
  "Only matches the first --- pair; ignores --- in body."
  (let ((text "---\na: 1\n---\nbody\n---\nmore"))
    (should (equal "a: 1\n"
                   (agent-skills--extract-frontmatter text)))))

;; -------------------------------------------------------------------
;;; 2. agent-skills--parse-frontmatter
;; -------------------------------------------------------------------

(ert-deftest agent-skills-test-parse-frontmatter/simple ()
  "Parses a simple key-value YAML string."
  (let ((result (agent-skills--parse-frontmatter "name: test-skill\n")))
    (should (equal "test-skill" (alist-get 'name result)))))

(ert-deftest agent-skills-test-parse-frontmatter/multiple-fields ()
  "Parses multiple frontmatter fields."
  (let ((result (agent-skills--parse-frontmatter
                 "name: my-skill\ndescription: Does things\nlicense: GPL-3.0\n")))
    (should (equal "my-skill" (alist-get 'name result)))
    (should (equal "Does things" (alist-get 'description result)))
    (should (equal "GPL-3.0" (alist-get 'license result)))))

(ert-deftest agent-skills-test-parse-frontmatter/quoted-strings ()
  "Parses quoted YAML values."
  (let ((result (agent-skills--parse-frontmatter
                 "name: \"quoted-skill\"\ndescription: \"A \\\"quoted\\\" desc\"\n")))
    (should (equal "quoted-skill" (alist-get 'name result)))))

;; -------------------------------------------------------------------
;;; 3. agent-skills--strip-frontmatter
;; -------------------------------------------------------------------

(ert-deftest agent-skills-test-strip-frontmatter/has-frontmatter ()
  "Strips frontmatter and returns body."
  (should (equal "body content"
                 (agent-skills--strip-frontmatter "---\nk: v\n---\nbody content"))))

(ert-deftest agent-skills-test-strip-frontmatter/no-frontmatter ()
  "Returns text unchanged when no frontmatter present."
  (should (equal "plain body"
                 (agent-skills--strip-frontmatter "plain body"))))

(ert-deftest agent-skills-test-strip-frontmatter/empty-body ()
  "Returns empty string when body is empty after frontmatter."
  (should (equal ""
                 (agent-skills--strip-frontmatter "---\nk: v\n---\n"))))

(ert-deftest agent-skills-test-strip-frontmatter/trims-leading-whitespace ()
  "Trims leading whitespace from body after frontmatter."
  (should (equal "body"
                 (agent-skills--strip-frontmatter "---\nk: v\n---\n\n\n  body"))))

;; -------------------------------------------------------------------
;;; 4. agent-skills--read-file (filesystem)
;; -------------------------------------------------------------------

(ert-deftest agent-skills-test-read-file/reads-contents ()
  "Reads file contents correctly."
  (let ((tmpfile (make-temp-file "as-test-")))
    (unwind-protect
        (progn
          (with-temp-file tmpfile (insert "hello world"))
          (should (equal "hello world" (agent-skills--read-file tmpfile))))
      (delete-file tmpfile))))

(ert-deftest agent-skills-test-read-file/nonexistent ()
  "Signals error for nonexistent file."
  (should-error (agent-skills--read-file "/tmp/agent-skills-nonexistent-file-xyz")))

;; -------------------------------------------------------------------
;;; 5. agent-skills--skill-dirs (filesystem)
;; -------------------------------------------------------------------

(ert-deftest agent-skills-test-skill-dirs/finds-valid-dirs ()
  "Finds subdirectories that contain a SKILL.md."
  (let ((dirs (agent-skills--skill-dirs agent-skills-test--skills-dir)))
    ;; skill-alpha and skill-beta and no-frontmatter all have SKILL.md
    (should (>= (length dirs) 2))
    (should (cl-some (lambda (d) (string-match-p "skill-alpha\\'" d)) dirs))
    (should (cl-some (lambda (d) (string-match-p "skill-beta\\'" d)) dirs))))

(ert-deftest agent-skills-test-skill-dirs/skips-dir-without-skill-md ()
  "Skips subdirectories that lack SKILL.md."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (let ((subdir (expand-file-name "no-skill" tmpdir)))
          (make-directory subdir t)
          (should (null (agent-skills--skill-dirs tmpdir))))
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-skill-dirs/empty-dir ()
  "Returns nil for an empty directory."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (should (null (agent-skills--skill-dirs tmpdir)))
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-skill-dirs/ignores-hidden-dirs ()
  "Ignores dotfiles/hidden directories."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (let ((hidden (expand-file-name ".hidden" tmpdir)))
          (make-directory hidden t)
          (with-temp-file (expand-file-name "SKILL.md" hidden)
            (insert "---\nname: hidden\n---\n"))
          (should (null (agent-skills--skill-dirs tmpdir))))
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-skill-dirs/ignores-regular-files ()
  "Ignores regular files (non-directories)."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "not-a-dir" tmpdir)
            (insert "data"))
          (should (null (agent-skills--skill-dirs tmpdir))))
      (delete-directory tmpdir t))))

;; -------------------------------------------------------------------
;;; 6. agent-skills--parse-skill-folder (filesystem fixtures)
;; -------------------------------------------------------------------

(ert-deftest agent-skills-test-parse-skill-folder/valid ()
  "Parses a valid skill directory."
  (let* ((dir (expand-file-name "skill-alpha" agent-skills-test--skills-dir))
         (result (agent-skills--parse-skill-folder dir)))
    (should (equal "skill-alpha" (alist-get 'name result)))
    (should (equal "A simple test skill for unit testing." (alist-get 'description result)))))

(ert-deftest agent-skills-test-parse-skill-folder/optional-fields ()
  "Parses optional fields from a skill directory."
  (let* ((dir (expand-file-name "skill-beta" agent-skills-test--skills-dir))
         (result (agent-skills--parse-skill-folder dir)))
    (should (equal "skill-beta" (alist-get 'name result)))
    (should (equal "MIT" (alist-get 'license result)))
    (should (equal "Emacs 29.1+" (alist-get 'compatibility result)))))

(ert-deftest agent-skills-test-parse-skill-folder/missing-skill-md ()
  "Signals error when SKILL.md is missing."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (should-error (agent-skills--parse-skill-folder tmpdir)
                      :type 'error)
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-parse-skill-folder/no-frontmatter ()
  "Signals error when SKILL.md has no frontmatter."
  (let ((dir (expand-file-name "no-frontmatter" agent-skills-test--skills-dir)))
    (should-error (agent-skills--parse-skill-folder dir)
                  :type 'error)))

;; -------------------------------------------------------------------
;;; 7. agent-skills--parse-skills
;; -------------------------------------------------------------------

(ert-deftest agent-skills-test-parse-skills/multiple ()
  "Parses multiple skill directories."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (agent-skills-test--make-skill-dir tmpdir "s1" "name: s1\ndescription: d1\n" "body1")
          (agent-skills-test--make-skill-dir tmpdir "s2" "name: s2\ndescription: d2\n" "body2")
          (let ((results (agent-skills--parse-skills tmpdir)))
            (should (= 2 (length results)))
            (should (cl-some (lambda (r) (equal "s1" (alist-get 'name r))) results))
            (should (cl-some (lambda (r) (equal "s2" (alist-get 'name r))) results))))
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-parse-skills/empty ()
  "Returns nil for a directory with no skills."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (should (null (agent-skills--parse-skills tmpdir)))
      (delete-directory tmpdir t))))

;; -------------------------------------------------------------------
;;; 8. agent-skills-create
;; -------------------------------------------------------------------

(ert-deftest agent-skills-test-create/single-dir ()
  "Creates skill entries from a single directory."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (agent-skills-test--make-skill-dir tmpdir "s1" "name: s1\ndescription: d1\n" "body")
          (agent-skills-test--make-skill-dir tmpdir "s2" "name: s2\ndescription: d2\n" "body")
          (let ((results (agent-skills-create tmpdir)))
            (should (= 2 (length results)))
            ;; Each entry should have a path key
            (dolist (entry results)
              (should (alist-get 'path entry))
              (should (file-name-absolute-p (alist-get 'path entry))))))
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-create/multiple-dirs ()
  "Creates skill entries from multiple directories."
  (let ((dir1 (make-temp-file "as-test-" t))
        (dir2 (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (agent-skills-test--make-skill-dir dir1 "s1" "name: s1\ndescription: d1\n" "body")
          (agent-skills-test--make-skill-dir dir2 "s2" "name: s2\ndescription: d2\n" "body")
          (let ((results (agent-skills-create dir1 dir2)))
            (should (= 2 (length results)))
            (should (cl-some (lambda (r) (equal "s1" (alist-get 'name r))) results))
            (should (cl-some (lambda (r) (equal "s2" (alist-get 'name r))) results))))
      (delete-directory dir1 t)
      (delete-directory dir2 t))))

(ert-deftest agent-skills-test-create/path-is-absolute ()
  "The path key in entries is an absolute expanded path."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (agent-skills-test--make-skill-dir tmpdir "s1" "name: s1\ndescription: d1\n" "body")
          (let* ((results (agent-skills-create tmpdir))
                 (path (alist-get 'path (car results))))
            (should (file-name-absolute-p path))
            (should (string-match-p "s1\\'" path))))
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-create/empty-dir ()
  "Returns nil for a directory with no skills."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (should (null (agent-skills-create tmpdir)))
      (delete-directory tmpdir t))))

;; -------------------------------------------------------------------
;;; 9. agent-skills--list-skill-files
;; -------------------------------------------------------------------

(ert-deftest agent-skills-test-list-skill-files/excludes-skill-md ()
  "Excludes SKILL.md from the listing."
  (let ((dir (expand-file-name "skill-alpha" agent-skills-test--skills-dir)))
    (should-not (member "SKILL.md" (agent-skills--list-skill-files dir)))))

(ert-deftest agent-skills-test-list-skill-files/includes-bundled-files ()
  "Includes other files in the listing."
  (let* ((dir (expand-file-name "skill-beta" agent-skills-test--skills-dir))
         (files (agent-skills--list-skill-files dir)))
    (should (member "scripts/helper.sh" files))
    (should (member "reference/notes.txt" files))))

(ert-deftest agent-skills-test-list-skill-files/only-skill-md ()
  "Returns nil when only SKILL.md exists."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "SKILL.md" tmpdir)
            (insert "---\nname: x\n---\n"))
          (should (null (agent-skills--list-skill-files tmpdir))))
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-list-skill-files/nested-subdirs ()
  "Returns relative paths for nested files."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "SKILL.md" tmpdir)
            (insert "---\nname: x\n---\n"))
          (make-directory (expand-file-name "a/b" tmpdir) t)
          (with-temp-file (expand-file-name "a/b/deep.txt" tmpdir)
            (insert "deep"))
          (let ((files (agent-skills--list-skill-files tmpdir)))
            (should (member "a/b/deep.txt" files))))
      (delete-directory tmpdir t))))

;; -------------------------------------------------------------------
;;; 10. agent-skills--load-skill
;; -------------------------------------------------------------------

(ert-deftest agent-skills-test-load-skill/valid ()
  "Loads a skill by name and returns formatted content."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (agent-skills-test--make-skill-dir
           tmpdir "my-skill" "name: my-skill\ndescription: test\n"
           "# My Skill\n\nBody text here.\n")
          (let* ((skills (agent-skills-create tmpdir))
                 (output (agent-skills--load-skill skills "my-skill")))
            (should (string-match-p "<skill_content name=\"my-skill\">" output))
            (should (string-match-p "# Skill: my-skill" output))
            (should (string-match-p "Body text here\\." output))
            (should (string-match-p "<skill_files>" output))
            (should (string-match-p "</skill_content>" output))))
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-load-skill/nonexistent-name ()
  "Signals error when skill name doesn't exist."
  (should-error (agent-skills--load-skill nil "nonexistent")
                :type 'error))

(ert-deftest agent-skills-test-load-skill/includes-bundled-files ()
  "Includes bundled file entries in the output."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (agent-skills-test--make-skill-dir
           tmpdir "with-files" "name: with-files\ndescription: test\n"
           "body\n"
           '(("scripts/run.sh" . "#!/bin/sh\n")
             ("data/ref.txt" . "reference\n")))
          (let* ((skills (agent-skills-create tmpdir))
                 (output (agent-skills--load-skill skills "with-files")))
            (should (string-match-p "<file>scripts/run\\.sh</file>" output))
            (should (string-match-p "<file>data/ref\\.txt</file>" output))))
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-load-skill/no-bundled-files ()
  "Works when skill has no bundled files."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (agent-skills-test--make-skill-dir
           tmpdir "bare" "name: bare\ndescription: test\n" "body\n")
          (let* ((skills (agent-skills-create tmpdir))
                 (output (agent-skills--load-skill skills "bare")))
            (should (string-match-p "<skill_files>" output))
            (should-not (string-match-p "<file>" output))))
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-load-skill/strips-frontmatter-from-body ()
  "The loaded content does not contain the YAML frontmatter."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (agent-skills-test--make-skill-dir
           tmpdir "fm-strip" "name: fm-strip\ndescription: test\n"
           "# Heading\n\nBody.\n")
          (let* ((skills (agent-skills-create tmpdir))
                 (output (agent-skills--load-skill skills "fm-strip")))
            (should-not (string-match-p "^---$" output))
            (should (string-match-p "# Heading" output))))
      (delete-directory tmpdir t))))

;; -------------------------------------------------------------------
;;; 11. agent-skills--format-description
;; -------------------------------------------------------------------

(ert-deftest agent-skills-test-format-description/structure ()
  "Produces expected XML-like structure."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (agent-skills-test--make-skill-dir
           tmpdir "desc-skill" "name: desc-skill\ndescription: Does things.\n" "body\n")
          (let* ((skills (agent-skills-create tmpdir))
                 (desc (agent-skills--format-description skills)))
            (should (string-match-p "<available_skills>" desc))
            (should (string-match-p "</available_skills>" desc))
            (should (string-match-p "<name>desc-skill</name>" desc))
            (should (string-match-p "<description>Does things\\.</description>" desc))
            (should (string-match-p "<location>.*SKILL\\.md</location>" desc))))
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-format-description/multiple-skills ()
  "Lists multiple skills."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (agent-skills-test--make-skill-dir tmpdir "a" "name: a\ndescription: da\n" "body")
          (agent-skills-test--make-skill-dir tmpdir "b" "name: b\ndescription: db\n" "body")
          (let* ((skills (agent-skills-create tmpdir))
                 (desc (agent-skills--format-description skills)))
            (should (string-match-p "<name>a</name>" desc))
            (should (string-match-p "<name>b</name>" desc))))
      (delete-directory tmpdir t))))

;; -------------------------------------------------------------------
;;; 12. agent-skills-tool-specs
;; -------------------------------------------------------------------

(ert-deftest agent-skills-test-tool-specs/plist-keys ()
  "Returns a plist with the expected keys."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (agent-skills-test--make-skill-dir
           tmpdir "ts" "name: ts\ndescription: test\n" "body\n")
          (let* ((skills (agent-skills-create tmpdir))
                 (spec (agent-skills-tool-specs skills)))
            (should (equal "skill" (plist-get spec :name)))
            (should (stringp (plist-get spec :description)))
            (should (functionp (plist-get spec :function)))
            (should (plist-get spec :args))
            (should (equal "skills" (plist-get spec :category)))
            (should (eq t (plist-get spec :include)))))
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-tool-specs/function-loads-skill ()
  "The :function in tool specs loads a skill by name."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (agent-skills-test--make-skill-dir
           tmpdir "loadable" "name: loadable\ndescription: test\n" "# Content\n")
          (let* ((skills (agent-skills-create tmpdir))
                 (spec (agent-skills-tool-specs skills))
                 (fn (plist-get spec :function))
                 (output (funcall fn "loadable")))
            (should (string-match-p "<skill_content name=\"loadable\">" output))
            (should (string-match-p "# Content" output))))
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-tool-specs/function-errors-on-unknown ()
  "The :function errors on unknown skill name."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (agent-skills-test--make-skill-dir
           tmpdir "only" "name: only\ndescription: test\n" "body\n")
          (let* ((skills (agent-skills-create tmpdir))
                 (spec (agent-skills-tool-specs skills))
                 (fn (plist-get spec :function)))
            (should-error (funcall fn "nonexistent") :type 'error)))
      (delete-directory tmpdir t))))

;; -------------------------------------------------------------------
;;; 13. Integration / end-to-end
;; -------------------------------------------------------------------

(ert-deftest agent-skills-test-integration/full-round-trip ()
  "Full round-trip: create skills, get tool specs, load each skill."
  (let ((tmpdir (make-temp-file "as-test-" t)))
    (unwind-protect
        (progn
          (agent-skills-test--make-skill-dir
           tmpdir "skill-one" "name: skill-one\ndescription: First skill.\n"
           "# Skill One\n\nDoes the first thing.\n"
           '(("data/info.txt" . "info")))
          (agent-skills-test--make-skill-dir
           tmpdir "skill-two" "name: skill-two\ndescription: Second skill.\n"
           "# Skill Two\n\nDoes the second thing.\n")
          (let* ((skills (agent-skills-create tmpdir))
                 (spec (agent-skills-tool-specs skills))
                 (fn (plist-get spec :function)))
            ;; Correct count
            (should (= 2 (length skills)))
            ;; Tool spec is well-formed
            (should (equal "skill" (plist-get spec :name)))
            ;; Load each skill
            (let ((out1 (funcall fn "skill-one"))
                  (out2 (funcall fn "skill-two")))
              ;; skill-one
              (should (string-match-p "<skill_content name=\"skill-one\">" out1))
              (should (string-match-p "Does the first thing\\." out1))
              (should (string-match-p "<file>data/info\\.txt</file>" out1))
              ;; skill-two
              (should (string-match-p "<skill_content name=\"skill-two\">" out2))
              (should (string-match-p "Does the second thing\\." out2))
              (should-not (string-match-p "<file>" out2)))))
      (delete-directory tmpdir t))))

(ert-deftest agent-skills-test-integration/fixture-skills ()
  "Loads the test fixture skills under tests/skills/."
  (let* ((tmpdir (make-temp-file "as-test-" t)))
    ;; Copy only valid skills to a clean dir so parse-skills won't hit
    ;; the no-frontmatter fixture.
    (unwind-protect
        (progn
          (copy-directory (expand-file-name "skill-alpha" agent-skills-test--skills-dir)
                          (expand-file-name "skill-alpha" tmpdir))
          (copy-directory (expand-file-name "skill-beta" agent-skills-test--skills-dir)
                          (expand-file-name "skill-beta" tmpdir))
          (let* ((skills (agent-skills-create tmpdir))
                 (spec (agent-skills-tool-specs skills))
                 (fn (plist-get spec :function)))
            (should (= 2 (length skills)))
            ;; Load skill-alpha
            (let ((out (funcall fn "skill-alpha")))
              (should (string-match-p "Skill Alpha" out)))
            ;; Load skill-beta (has bundled files)
            (let ((out (funcall fn "skill-beta")))
              (should (string-match-p "Skill Beta" out))
              (should (string-match-p "<file>scripts/helper\\.sh</file>" out))
              (should (string-match-p "<file>reference/notes\\.txt</file>" out)))))
      (delete-directory tmpdir t))))

(provide 'agent-skills-test)

;;; agent-skills-test.el ends here
