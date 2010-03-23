#!/usr/bin/env python2.4

# Stack analyzer, copyright (c) 2007 Jacob Potter.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2, as published by the Free Software Foundation.

import sys
import stacklib86

MAX_TREES = 3

if len(sys.argv) < 2:
	print "usage: %s [object]" % sys.argv[0]
	sys.exit(1)

known_funcs = stacklib86.parse_file(sys.argv[1])

for f in known_funcs.itervalues():
	print str(f)

functree = stacklib86.grind_tree(known_funcs, lambda name: name.endswith("_wrapper"))

sequences = {}

def format(terminals):

	strs = "\n".join((
		"\tTotal %d: %s" % (
			sum(f.stacklen for f in funclist),
			" -> ".join(str(f) for f in funclist)
		)
		for funclist
		in terminals[-MAX_TREES:]
	))

	if len(terminals) > MAX_TREES:
		strs = ("\t(%d call paths omitted)\n" % (len(terminals) - MAX_TREES)) + strs

	return strs

sequences = sorted(
	(
		(
			startfunc,
			"Stack used from %s:\n%s" % (startfunc, format(terminals)),
			sum(( f.stacklen for f in terminals[-1] ))
		)
		for startfunc, terminals
		in functree
	),
	key = lambda i: i[2]
)

for startfunc, info, len in sequences:
	print info
	print

#max_syscall = (0, "")
#for func, len in sequences.iteritems():
#	if (func.startswith("syscall_") or func.startswith("fault_")) and len > max_syscall[0]:
#		max_syscall = (len, func)

#print "Longest system call: %d (%s)" % max_syscall
print "Timer: %d" % (sequences["timer_handler_wrapper"][1])
print "Keyboard: %d" % (sequences["keyboard_handler_wrapper"][1])

