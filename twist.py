#!/usr/bin/env python

from __future__ import print_function
from PIL import Image, ImageDraw
from math import sin, radians, pi
from hsv import hsv

colors = [
#main palette
	255, 0, 255, # background color
	0, 0, 0, # used by actual background
	0, 0, 0, # used by actual background
	0, 0, 0, # used by actual background
	255, 255, 255,
	255, 0, 0,
	0, 255, 0,
	0, 0, 255,
	0, 0, 0,
	0, 0, 0,
	0, 0, 0,
	0, 0, 0,
	0, 0, 0,
	0, 0, 0,
	0, 0, 0,
	0, 0, 0,
	0, 0, 0,
	0, 0, 0,
	0, 0, 0,
]

width = 30
phase = 45

im = Image.new("P", (512, 512), 0)
im.putpalette(colors)
draw = ImageDraw.Draw(im)

def line(x1, x2, y, color):
	draw.line([x1, y, x2, y], 15)
	if (x2 - x1 > 0):
		draw.line([x1 + 0, y, x2 - 0, y], color)

for y in range(256):
	angle = y * (360 / 512.)
	
	x1 = 128 + width*sin(radians(angle + phase))
	x2 = 128 + width*sin(radians(angle + phase + 90))
	x3 = 128 + width*sin(radians(angle + phase + 180))
	x4 = 128 + width*sin(radians(angle + phase + 270))
	
	if (x1 < x2):
		line(x1, x2, y, 4)
		line(256+x1, 256+x2, y, 6)
	if (x2 < x3):
		line(x2, x3, y, 5)
		line(256+x2, 256+x3, y, 7)
	if (x3 < x4):
		line(x3, x4, y, 4)
		line(256+x3, 256+x4, y, 6)
	if (x4 < x1):
		line(x4, x1, y, 5)
		line(256+x4, 256+x1, y, 7)

im.save("data/twist.png")

with open("data/twistcolor.i", 'w') as f:
	# generate the changing twist colors now
	def makecolor(name, color, phase):
		hue, sat, val = color
		
		f.write("%s:\n" % name)
		for i in range(phase, 256):
			c = hsv(hue, sat, val * sin(pi * i / 256.))
			f.write(".word rgb(%d, %d, %d)\n" % (c[0] * 31, c[1] * 31, c[2] * 31))
		"""
		for i in range(256):
			c = hsv(hue, sat, val * sin(pi * i / 256.))
			f.write(".word rgb(%d, %d, %d)\n" % (c[0] * 31, c[1] * 31, c[2] * 31))
		"""
		for i in range(0, phase):
			c = hsv(hue, sat, val * sin(pi * i / 256.))
			f.write(".word rgb(%d, %d, %d)\n" % (c[0] * 31, c[1] * 31, c[2] * 31))
	
	# TODO: maybe only generate one color each
	# depending on ROM size needed
	
	# color 0 = bg 1 first color
	makecolor("TwistColor1", (205., 0.8, 0.9), 128)
		
	# color 1 = bg 1 second color
#	makecolor("TwistColor1B", (210., 0.8, 0.7), 128)

	# color 3 = bg 2 first color
	makecolor("TwistColor2", (40., 0.9, 0.9), 128)
		
	# color 4 = bg 2 second color
#	makecolor("TwistColor2B", (40., 0.8, 0.7), 128)

