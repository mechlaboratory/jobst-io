clc, clear all, close all

MSGOUT_LEN = 150;
SAMPLES = 100;

DataOut = uint8([hex2dec('AA'), 0:(MSGOUT_LEN-4), MSGOUT_LEN, hex2dec('CC')]);
%DataOut = uint8(95*ones(1, MSGOUT_LEN));
t = tcpserver("192.168.0.131",4000);
%t = tcpclient("192.168.137.60",80);
%t = tcpip('192.168.0.108', 30000, 'NetworkRole', 'server')
%fopen(t);

time = zeros(1,SAMPLES);
L = 1;

while(t.Connected == 0)
    pause(1)
    disp('No client')
end
disp('New client')
while(L <= SAMPLES)
    tic;
    DataOut(end-1) = uint8(mod(L,250));
    write(t,DataOut);
    flush(t);
    %disp(t.BytesAvailable)
    %while(t.BytesAvailable < MSGOUT_LEN-1)      
        %pause(0.1)
        %disp(t.BytesAvailable)
    %end
    msg = read(t,MSGOUT_LEN);
    time(L) = toc;
    L = L + 1;
    %pause(1)
end
disp(['Freq: ', num2str(1/mean(time))])

clear t