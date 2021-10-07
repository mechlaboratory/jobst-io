clc, clear all, close all

MSGOUT_LEN = 150;
SAMPLES = 500;

DataOut = uint8([hex2dec('AA'), 0:(MSGOUT_LEN-4), MSGOUT_LEN, hex2dec('CC')]);
%DataOut = uint8(95*ones(1, MSGOUT_LEN));

u = udpport("byte")



pause(1)
time = zeros(1,SAMPLES);
flag = zeros(1,SAMPLES);
L = 1;
while(L <= SAMPLES)
    tic;
    DataOut(end-1) = uint8(mod(L,250));
    write(u,DataOut,"uint8","192.168.0.108",2390)
    %disp(t.BytesAvailable)
    while(u.NumBytesAvailable < MSGOUT_LEN)      
        %pause(0.1)
        %disp(u.NumBytesAvailable)
    end
    msg = read(u,MSGOUT_LEN);
    flag(L) = msg(end-1);
    %disp(msg);
    time(L) = toc;
    L = L + 1;
    %pause(1)
end
disp(["Freq: ", 1/mean(time)])

clear t