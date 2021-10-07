import socket
import numpy as np
import time

UDP_IP = "192.168.0.108"
UDP_PORT = 2390
MESSAGE = np.arange(-1,149,dtype = np.uint8)
MESSAGE[0] = 170
MESSAGE[-1] = 204

SAMPLES = 5000

print("UDP target IP: %s" % UDP_IP)
print("UDP target port: %s" % UDP_PORT)
print("message: %s" % MESSAGE)

sock = socket.socket(socket.AF_INET, # Internet
                     socket.SOCK_DGRAM) # UDP

timeArray = np.zeros(SAMPLES)

L = 0
while L < SAMPLES:
    tic = time.perf_counter()
    MESSAGE[-2] = L%250
    sock.sendto(MESSAGE, (UDP_IP, UDP_PORT))
    data, addr = sock.recvfrom(1024) # buffer size is 1024 bytes
    print(data[-2])
    toc = time.perf_counter()
    timeArray[L] = toc-tic
    L = L + 1

print("Mean frequency: ",1/np.mean(timeArray))