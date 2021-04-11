EMACS ?= emacs

all: compile


compile:
	${CASK} exec ${EMACS} -Q -batch -f batch-byte-compile double-keystroke.el

clean-elc:
	rm -f run-every-day.elc

.PHONY:	all compile clean-elc
