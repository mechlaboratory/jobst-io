% This example shows how to use NXT motors with jobst.io. You can see basic
% PI regulator algorithm on Matlab side.
% 
% Feel free tinkering with kp and ki values.
%
%
% Version of this file: 1.0 (8.11.2019)
% Author: Vojtech Mlynar, Roman Adamek
% 
% www.jobst.io


clear, close;


%% User changeable variables
MotorPort = 'A';

kp = 0.5; % Gain of proportional part
ki = 0.04; % Gain of integration part


%% Initialization of variables and plot
u_i = 0;

tic;
start_time = toc;
last_time = start_time;
dt = 0.01; % time step of integration

pos_log = zeros(1, 500);
w_pos_log = zeros(1, 500);
t = linspace(0, -5, 500);

figure
hold on
p = plot(t,pos_log, t, w_pos_log);
pause(0.1);


%% Jobst init
Cube = Jobst; % Create object
Cube.Connect; % Connect to jobst


%% Main loop
while 1
    start_time = toc;
    if start_time >= last_time + dt
        last_time = start_time;
        
        pos = Cube.GetEncoderTicks(MotorPort); % Get position of motor
        
        w_pos = sin(toc/2)*720;
        e = double(w_pos - pos); % Calculate error
        
        % Proportional part of regulator
        u_p = kp * e;
        
        % Integrational part of regulator
        u_i = u_i + ki *e
        u_i = min(100, max(-100, u_i)); % Saturate output of I part
               
        u = u_p + u_i;
        
        u = round(min(100, max(-100, u))); % Saturate action value to +-100
        
        %You may need to erase minus sign to match direction of rotation
        Cube.SetMotorPercentage(MotorPort,-1*u); % Set motor
        
        pos_log = [pos_log(2:end), pos]; % Actual position
        w_pos_log = [w_pos_log(2:end), w_pos]; % Target position
        set(p(1), 'YData', pos_log);
        set(p(2), 'YData', w_pos_log);
        drawnow % Redraw plot
    end
end