test:
    emacs --batch -L . -L tests/ -l agent-skills-test.el -f ert-run-tests-batch-and-exit
