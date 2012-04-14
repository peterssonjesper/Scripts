#!/usr/bin/python
import sys, re, os

SCAN_EXTENSIONS = ["js", "html", "php", "py", "rb"]

def error_in_line(line):
	return True if re.search(",}", line) else False# Check inside a line

def search_file(filename):
	try:
		f = open(filename, 'r')
	except:
		print "Skipping file " + str(filename) + "..."
		return

	content = f.read().replace("\t", "").replace(" ", "").split("\n")

	i=0
	while i < len(content):
		if error_in_line(content[i]): # Check inside a line
			print "Found possible error in file " + filename + " on line " + str(i+1)
		elif i < len(content)-1:
			joined_line = content[i] + content[i+1]
			if error_in_line(joined_line) and not error_in_line(content[i+1]): # Check between two lines
				print "Found possible error in file " + filename + " between line " + str(i+1) + " and " + str(i+2)
		i += 1

def rec_search(dir_name):
	for f in os.listdir(dir_name):
		if os.path.isdir(dir_name + "/" + f):
			rec_search(dir_name + "/" + f)
		elif (dir_name + "/" + f).split(".")[-1].lower() in SCAN_EXTENSIONS:
			search_file(dir_name + "/" + f)

if len(sys.argv) != 2:
	print "Usage: js_syntax_ie.py file.js"
	sys.exit(1)

if os.path.isdir(sys.argv[1]):
	rec_search(sys.argv[1])
else:
	search_file(sys.argv[1])
