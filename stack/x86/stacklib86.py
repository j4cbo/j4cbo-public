#!/usr/bin/python2.4

# AVR stack analyzer, copyright (c) 2007 Jacob Potter.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2, as published by the Free Software Foundation.

import os
import re

line_re = re.compile("""
	\ *		# Leading whitespace
	[a-f0-9]+:	# Address label, with colon
	\\t		# Tab
	[a-f0-9 ]+	# Instructions, in hex
	\\t		# Tab
	([a-z]+)	# Opcode
	\ *		# Chew up any whitespace
	(.*)		# Anything trailing
""", re.VERBOSE)

subesp_re = re.compile("\$0x([a-z0-9]+),%esp")

call_re = re.compile("[a-z0-9]+ <([a-zA-Z0-9_]+)>")

function_re = re.compile("^[a-f0-9]+ <([a-zA-Z0-9_.]+)>:$")

INVALID_FUNCTION_NAMES = [
	"L1"
]

IRREGULAR_FUNCTIONS = [
	"_start",
	"boot_hdr",
	"boot_entry",
	"__oskit_init",
	"base_multiboot_init_cmdline",
	"printnum",
	"_doprnt",
	"master_ints",
	"slave_ints",
	"alltraps"
]

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

	objin, objout = os.popen4("objdump -d -j.text " + fname)
	lines = [ line for line in objout.read().split('\n') if line != "" ]
	lines.append("")

	known_funcs = {}

	lineindex = 0
	while lineindex < len(lines):

		# Pull lines until we reach the beginning of an interesting function
		function_match = function_re.match(lines[lineindex])
		if function_match is None:
			lineindex += 1
			continue

		function_name = function_match.group(1)

		if function_name in IRREGULAR_FUNCTIONS:
			lineindex += 1
			continue

		bytes_used = 4
		callees = []
		lineindex += 1

		# Then, parse each line of it
		while lineindex < len(lines):
			line = lines[lineindex]

			# Ignore blank lines
			if line == "":
				lineindex += 1
				continue

			line_match = line_re.match(line)

			if not line_match:

				# If the next line is a label (starts with .), ignore it
				line_as_func = function_re.match(line)
				if line_as_func:
					next_func_name = line_as_func.group(1)
					if next_func_name.startswith(".") or \
					   next_func_name in INVALID_FUNCTION_NAMES:
						lineindex += 1
						continue

				break

			lineindex += 1

			inst, parameters = line_match.groups()

			if inst == "push":
				bytes_used += 4

			if inst == "pusha":
				bytes_used += 32

			elif inst == "sub" and "%esp" in parameters:
				se = subesp_re.match(parameters)
				if se:
					bytes_used += int(se.group(1), 16)
				else:
					raise Exception("esp");

			elif inst == "call":
				ca = call_re.match(parameters)
				if ca:
					callee = ca.group(1)
				else:
					print parameters
					raise Exception("call");
				
				if callee not in callees: callees.append(callee)


		# If this wasn't an actual function, ignore it.
		# Note that a function with code (but no push instructions)
		# would result in a push_count of 0, not none.

		known_funcs[function_name] = Func(function_name, bytes_used, callees)


	return known_funcs





def grind_tree(funclist, condition):

	# Massive generator expression to sort through everything called
	# from "main" or an interrupt
	functree = (
		(key, funclist[key].find_children(funclist))
		for key
		in sorted(funclist.keys())
		if condition(key)
	)

	return functree

