import os
from time import sleep

while True:
    os.system("python311 build_extension.py")
    os.system("python build_extension.py")
    sleep(5)