% This example shows how to use Jobst.io IMU sensor, particularly
% accelerometer, which measures acceleration in 3 axes. All you need is
% jobst.io unit, jobst.io IMU and Lego NXT Motor.
% 
% For best effect, connect IMU directly to motor axle.
%
% Version of this file: 1.0 (8.11.2019)
% Author: Vojtech Mlynar
% 
% www.jobst.io

clear, close, clc;


%% User changeable variables
AccPort = 1;
MotorPort = 'A';

%% Connect Jobst
Cube = Jobst;
Cube.Connect;

%% Main loop
while 1
    %You may need to change direction of acceleration according to how sensor is connected with motor
    accX = Cube.GetAccelerationX(AccPort); 
    
    %You may need to erase minus sign to match directions of rotation and acceleration
    power = -1*double(accX)/32767*100; 
    
    power = min(100, max(-100, power)); %Saturation of action value
    
    Cube.SetMotorPercentage(MotorPort, power); %Set motor
end