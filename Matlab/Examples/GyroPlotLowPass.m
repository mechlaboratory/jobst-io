% This example shows how to use Jobst.io IMU sensor, particularly
% gyroscope, which measures angular velocity in 3 axes. All you need is
% jobst.io unit, jobst.io IMU and jobst.io Button. This example also shows 
% basic discrete integration.
% 
% Angle, which sensor is pointing is output in command line. You can reset
% the angle via pressing button.
%
% NOTE: As you will see, drift is very significant, take it as a challenge,
% to try and minimize it.
%
% Version of this file: 1.0 (8.11.2019)
% Author: Vojtech Mlynar
% 
% www.jobst.io



close all
clear all


i = 1;
figure;
% get a handle to a plot graphics object


viewLen = 200; %Width of plot window


plotX = 1:viewLen;
gx = NaN(viewLen,1);
gy = NaN(viewLen,1);
gz = NaN(viewLen,1);
fZ = zeros(viewLen,1);
angleZ = zeros(1000,1);
omegaZ = zeros(1000,1);
omegaRaw = omegaZ;
%subplot(2,1,1);
azPlot = plot(plotX,gz,'-b', 'LineWidth', 1);
hold on
axPlot = plot(plotX,gx,'-r', 'LineWidth', 1);
ayPlot = plot(plotX,gy,'-g', 'LineWidth', 1);

grid on;
xlim([0, viewLen]);
ylim([-10000,10000]);


Cube = Jobst; %Create object
Cube.Update = 'user'; %WIP


Cube.Connect(); %Connect Cube
AccPort = 1;

readData = zeros(121,1000);
time = zeros(100,1);
%light = zeros(1000,1);
led = 1;

rawToDPS = (1000/32767); % Conversion to Degrees per second
fn = 50; 
dt = 1/100; %Frequency of loop
alfa = 0.1; %Filter constant
offsetAvg = 50; %How many readings are averaged to offset



Cube.SendData(); %User update only - WIP
%pause(1);
while(i<5000)
    tic
    Cube.GetData(); %User update only - WIP
    
    readData(:,i) = Cube.DataIn;
    if(i < viewLen)
        gx(i) = Cube.GetGyroX(AccPort);
        gy(i) = Cube.GetGyroY(AccPort);
        gz(i) = Cube.GetGyroZ(AccPort);
        f = i;
    else
        gx = circshift(gx,-1);
        gy = circshift(gy,-1);
        gz = circshift(gz,-1);
        fZ = circshift(fZ,-1);
        
        gx(end) = Cube.GetGyroX(AccPort);
        gy(end) = Cube.GetGyroY(AccPort);
        gz(end) = Cube.GetGyroZ(AccPort);
        f = viewLen;
    end
    
    if(i > 2)
        fZ(f) = (1-dt/alfa)*fZ(f-1) + (dt/alfa)*double(gz(f)); % Low pass filter
        %Low pass function recipe:
        %https://www.mathworks.com/help/physmod/sps/ref/lowpassfilterdiscreteorcontinuous.html
        omegaZ(i) = fZ(f);
        omegaRaw(i) = gz(f);
        %angleZ(i) = angleZ(i-1) + fZ(f)*rawToDPS*dt;
        
    end
    
    if(i <= offsetAvg)
        offsetGyro = mean(omegaRaw(1:i)); %Offset from average of raw signal
        %offsetGyro = mean(omegaZ(1:i)); %Offset from average of filtered signal
    else
        angleZ(i) = angleZ(i-1) + (omegaRaw(i)-offsetGyro)*rawToDPS*dt; %Use this for integrating raw unfiltered signal
        %angleZ(i) = angleZ(i-1) + (omegaZ(i)-offsetGyro)*rawToDPS*dt; %Integrating filtered signal
        disp(angleZ(i));
    end
        
    
    if(~mod(i,5))
        set(axPlot,'XData',plotX,'YData',fZ);
        set(azPlot,'XData',plotX,'YData',gz);
        drawnow;
    end   
    
    if(led == 1)
        led = 0;
    else
        led = 1;
    end
    Cube.SetLED(1,led);
    
    Cube.SendData(); %User update only - WIP
    
    while(toc() < dt);end
    time(i) = 1/toc();
    i = i+1;
end



mean(time)
Cube.Disconnect(); %Disconnect Cube when done