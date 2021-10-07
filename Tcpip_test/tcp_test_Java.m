clc, clear all, close all
java.lang.System.gc

MSGOUT_LEN = 150;
SAMPLES = 5000;

DataOut = uint8([hex2dec('AA'), 0:(MSGOUT_LEN-4), MSGOUT_LEN, hex2dec('CC')]);
%DataOut = uint8(95*ones(1, MSGOUT_LEN));
javaaddpath('C:\VM\0_Git\jobst-io\Tcpip_test');

sock = java.net.ServerSocket();
sock.setReuseAddress(true);
sock.setSoTimeout(2000);
sock.bind(java.net.InetSocketAddress(4000));
address = java.net.InetAddress.getByName("192.168.0.108");

pause(1)
time = zeros(1,SAMPLES);
flag = zeros(1,SAMPLES);
msg = uint8(zeros(1,MSGOUT_LEN));
in = msg;
L = 1;

%client = java.net.Socket;

client = sock.accept();
client.setSoTimeout(1000);
client.getInetAddress();

inputStr = java.io.DataInputStream(client.getInputStream());
outputStr = client.getOutputStream();
printer = java.io.DataOutputStream(outputStr);

while(L <= SAMPLES)
    tic;
    DataOut(end-1) = uint8(mod(L,250));

    printer.write(DataOut,0,MSGOUT_LEN);
    %pause(1);
    printer.flush();
    %pause(1);
    b = inputStr.available();
    
    while(b < 150)
       %pause(0.01)
       b = inputStr.available();
       %disp(b)
    end
      
%     for ii = 1:MSGOUT_LEN
%         in(ii) = inputStr.read();     
%     end
    
    data_reader = DataReader(inputStr);
    in = data_reader.readBuffer(150);
    
    %disp(in)
    flag(L) = in(end-1);%msg.Data(end-1);
    %disp(msg);
    time(L) = toc;
    L = L + 1;
    %pause(1)
end
disp(["Freq: ", 1/mean(time)])

clear t