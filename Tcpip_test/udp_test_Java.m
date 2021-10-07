clc, clear all, close all

MSGOUT_LEN = 150;
SAMPLES = 5000;

DataOut = uint8([hex2dec('AA'), 0:(MSGOUT_LEN-4), MSGOUT_LEN, hex2dec('CC')]);
%DataOut = uint8(95*ones(1, MSGOUT_LEN));


sock = java.net.DatagramSocket;
sock.setSoTimeout(2000);
address = java.net.InetAddress.getByName("192.168.0.108");

pause(1)
time = zeros(1,SAMPLES);
flag = zeros(1,SAMPLES);
msg = uint8(zeros(1,MSGOUT_LEN));
L = 1;
while(L <= SAMPLES)
    tic;
    DataOut(end-1) = uint8(mod(L,250));
    
    packet = java.net.DatagramPacket(DataOut, MSGOUT_LEN, address, 2390);
    sock.send(packet)
    
    inpack = java.net.DatagramPacket(msg,MSGOUT_LEN);
    sock.receive(inpack);
    in = inpack.getData;
    flag(L) = in(end-1);%msg.Data(end-1);
    %disp(msg);
    time(L) = toc;
    L = L + 1;
    %pause(0.1)
end
disp(["Freq: ", 1/mean(time)])

clear t