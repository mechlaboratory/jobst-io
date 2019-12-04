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

clear, close, clc;


%% User changeable variables
GyroPort = 1;
ButtonPort = 2;
angle = 0;
rawToDPS = (1000/32767);

%% Connect Jobst
Cube = Jobst;
Cube.Connect;

offset = rawToDPS*double(Cube.GetGyroZ(GyroPort)); % Init base value of gyro


tic;
time = toc;
last_time = toc;

while 1
    time = toc; 
    speed = double(Cube.GetGyroZ(GyroPort))*rawToDPS - offset; %Get raw reading of gyro, convert it to DPS and subtract offset
    angle = speed * (time-last_time) + angle % Integration
    last_time = time;
    
    switchState = Cube.GetButton(ButtonPort);      
    if switchState == 1; % Check if button is pressed     
        angle = 0; % Reset angle
    end
end