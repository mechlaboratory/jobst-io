clc, clear all, close all

MSGOUT_LEN = 150;
SAMPLES = 100;

DataOut = uint8([hex2dec('AA'), 95*ones(1,MSGOUT_LEN-3), MSGOUT_LEN, hex2dec('CC')]);
%DataOut = uint8(95*ones(1, MSGOUT_LEN));
%t = tcpclient("192.168.0.108",80);
t = tcpclient("192.168.137.8",80);

pause(1)
time = zeros(1,SAMPLES);
L = 1;
while(L <= SAMPLES)
    tic;
    write(t,DataOut);
    %disp(t.BytesAvailable)
    %while(t.BytesAvailable < MSGOUT_LEN-1)      
        %pause(0.1)
        %disp(t.BytesAvailable)
    %end
    msg = read(t,MSGOUT_LEN);
    disp(msg)
    time(L) = toc;
    L = L + 1;
    %pause(1)
end
disp(['Freq: ', num2str(1/mean(time))])

clear t