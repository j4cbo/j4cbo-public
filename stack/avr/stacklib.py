#!/usr/bin/python2.4

# AVR stack analyzer, copyright (c) 2007 Jacob Potter.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2, as published by the Free Software Foundation.

import os
import re

line_re = re.compile(" *[a-f0-9]+:\t[a-f0-9 ]+\t([a-z]+)(?:[^<]*<([^>]+)>)?")#(?:0x[a-f0-9]+ <(\w+)>)")
dataline_re = re.compile(" *[a-f0-9]+:\t([a-f0-9][a-f0-9] ){5,16}")
function_re = re.compile("^[a-f0-9]+ <([^>]+)>:$")
local_label_re = re.compile("^[a-f0-9]+ <(\\.\\w+)>:$")

class Func(object):
	def __init__(self, name, stacklen, children):
		self.name = name
		self.stacklen = stacklen
		self.children = children

	def __str__(self):
		return "%s (%d)" % (self.name, self.stacklen)

	def find_children_recursive(self, namehash, history = []):

		history.append(self)
		terminals = []

		# If this is a leaf function, record the path that got us here
		if len(self.children) == 0:
			terminals.append(history)

		# Otherwise, loop through each function this one calls
		for childname in self.children:
			if childname not in namehash:
				raise Exception("unknown function %s called from %s" % (childname, self.name))
			c = namehash[childname]

			# Detect recursion or loops
			if c in history:
				history.append(c)
				raise Exception("cycle detected: " + str(history))

			terminals += c.find_children_recursive(namehash, list(history))

		return terminals

	def find_children(self, namehash):
		terminals = self.find_children_recursive(namehash, [])
		terminals.sort(key = lambda fl: sum(f.stacklen for f in fl))
		return terminals


def parse_file(fname):

	# Call objdump on the file to get the disassembled output

	objin, objout = os.popen4("avr-objdump -d -j.text " + fname)
	lines = objout.read().split('\n')
	lines.append("")

	known_funcs = {}

	lineindex = 0
	while True:

		# Pull lines until we reach the beginning of an interesting function
		function_match = None
		while lineindex < len(lines):
			function_match = function_re.match(lines[lineindex])
			lineindex += 1
			if function_match: break

		# If we ran out of lines, we're done
		else:
			break

		function_name = function_match.group(1)

		state = "pushing"
		push_count = 0
		pop_count = 0
		callees = []

		# Then, parse each line of it
		while True:
			line = lines[lineindex]
			lineindex += 1

			# If this is a data symbol, skip it completely
			if dataline_re.match(line):
				push_count = None
				break

			line_match = line_re.match(line)

			if not line_match:
				if lineindex >= len(lines): break

				# If the next line is a label (starts with .), ignore it
				nextfunc_match = local_label_re.match(lines[lineindex])
				if nextfunc_match and nextfunc_match.group(1)[0] == '.':
					lineindex += 1
					continue

				break

			inst = line_match.group(1)

			if inst == "push":
				push_count += 1

			elif inst == "pop":
				pop_count += 1

			elif inst == "ret":
				if push_count != pop_count:
					raise Exception("early ret: %d push, %d pop" % (push_count, pop_count))
				break

			elif inst == "call":
				callee = line_match.group(2)
				if callee not in callees: callees.append(callee)


		# If this wasn't an actual function, ignore it.
		# Note that a function with code (but no push instructions)
		# would result in a push_count of 0, not none.

		if push_count is None: continue

#		if push_count != pop_count:
#			raise Exception("funcion \"%s\" finished with unbalanced push/pop count" % (function_name,))

		known_funcs[function_name] = Func(function_name, push_count + 2, callees)


	return known_funcs





def grind_tree(funclist):

	# Massive generator expression to sort through everything called
	# from "main" or an interrupt
	functree = (
		(key, funclist[key].find_children(funclist))
		for key
		in sorted(funclist.keys())
		if key == "main" or key.startswith("__vector_")
	)

	return functree

