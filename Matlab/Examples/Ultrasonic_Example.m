% This example shows how to use jobst.io ultrasonic sensor. All you need is
% jobst unit, jobst ultrasonic sensor, NXT motor and a few lego parts. 
%
% First attach wheels to NXT motor, two wheels on one axle will suffice.
% For best effect, attach ultrasonic sensor to motor, this will allow you
% to control "car" with hand position.
%
% If sensor reads distance shorter than LowerThreshold, motor will start
% turning one way, slowing as 
% 
% Real time bar graph shows "raw" values from sensors, these are then 
% normalized and then used as R G B components (0..1).

% Version of this file: 1.0 (8.11.2019)
% Author: Vojtech Mlynar
% 
% www.jobst.io


%% User changeable variables
UltraPort = 1; %Port where ultrasonic sensor is connected
UltraMotor = 'A'; % Port where Ultrasonic motor is connected

LowerThreshold = 120; %in milimeters
UpperThreshold = 250; %in milimeters
%Note: Be careful with tinkering of these values, may lead to various
%errors


%% Connect Jobst
Cube = Jobst; %Create object
Cube.Connect; %Connect jobst



while(1)
    distance = Cube.GetDistance(UltraPort); % Get distance from ultrasonic
    
    %You may need to swap dir values to match directions
    if(distance <= LowerThreshold) % Back away from object
        pwm = uint8(3000/distance);
        dir = 0;
    elseif(distance < UpperThreshold && distance > LowerThreshold) % Move closer
        pwm = uint8(distance-80);
        dir = 1;
    else %Stop
        pwm = 0;
        dir = 0;
    end
    
    Cube.SetMotorPWM(UltraMotor,pwm,dir); % Set motor
end
