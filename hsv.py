#!/usr/bin/env python

def hsv(h, s, v):
	if s <= 0:
		return (v, v, v)
	
	hh = h / 60
	i = int(hh)
	ff = hh - i
	
	p = v * (1 - s)
	q = v * (1 - (s * ff))
	t = v * (1 - (s * (1 - ff)))
	
	if i == 0:
		return (v, t, p)
	elif i == 1:
		return (q, v, p)
	elif i == 2:
		return (p, v, t)
	elif i == 3:
		return (p, q, v)
	elif i == 4:
		return (t, p, v)
	else:
		return (v, p, q)

if __name__ == "__main__":
	for i in range(256):
		c = hsv((i / 128.) * 360 % 360, 1.0, 1.0)
		print ".word rgb(%d, %d, %d)" % (c[0] * 31, c[1] * 31, c[2] * 31)
