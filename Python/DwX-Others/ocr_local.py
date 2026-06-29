from PIL import Image
import pytesseract
import argparse
import cv2
import os
import re, pdb
import subprocess

def detect_text_local(path):
	dir_path = os.path.dirname(os.path.realpath(__file__))
	try:
		bashCommand = f"{dir_path}/images/textcleaner -c '0,140,0,0' -g -t 30 -s 2 -u -p 5 -T {path} {dir_path}/images/data/output.tiff"
		output = subprocess.check_output(['bash','-c', bashCommand])
		image = Image.open(f"{dir_path}/images/data/output.tiff")
		text = pytesseract.image_to_string(image)
		text = re.sub("[^A-Za-z]+", "",  text)
	except Exception as e:
		print("Error Detect text local: ", e)
	else:
		os.remove(f"{dir_path}/images/data/output.tiff")
		return text