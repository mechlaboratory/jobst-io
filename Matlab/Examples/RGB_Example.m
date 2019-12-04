% This example shows how to use Jobst.io RGB sensor to read and show any 
% colour. All you need is jobst unit, jobst RGB sensor and any coloured
% surfaces.
% 
% Real time bar graph shows "raw" values from sensors, these are then 
% normalized and then used as R G B components (0..1).
%
% NOTE: Effective range of RGB Sensor is pretty short, for best effect, put
% it only few milimeters from the measured surface.
%
% Version of this file: 1.0 (7.11.2019)
% Author: Vojtech Mlynar
% 
% www.jobst.io

clear all
close all

%% User changeable variables
RGBPort = 1; %Port where RGB sensor is connected
Frequency = 50; %Frequency of main loop in Hz

R_MAX = 13200; %Reference value for red
G_MAX = 26500; %Reference value for green
B_MAX = 36200; %Reference value for blue
 
LightOffset = 1.0; %Allows to increase „brightness“ of all colours
 
%% Init variables and plot
plotX = 1:100;
red = 0;
green = 0;
blue = 0;
light = 0;
 
b = bar([red green blue light]); %Create handle for graphic output
b.FaceColor = 'flat';
b.CData(1,:) = [1 0 0];
b.CData(2,:) = [0 1 0];
b.CData(3,:) = [0 0 1];
b.CData(4,:) = [1 1 1];
ylim([0,50000]); %Set limits of bar graph

i = 1;
%% Connect Jobst

Cube = Jobst; %Create object
Cube.Connect; %Connect Jobst


while(1) %Main loop, break with ctrl+c
    tic    

    light = Cube.GetLight(RGBPort);
    [red green blue] = Cube.GetRGB(RGBPort);
    
     if(~mod(i,10)) %Limit refresh rate (dependent on Frequency)
        ax = gca; %Get handle to current axes
        ax.XTick = [1 2 3 4]; 
        ax.XTickLabels = {num2str(red), num2str(green), ... 
        num2str(blue), num2str(light)}; 
    
        set(b,'YData',[red green blue light]); %Update bar graph
        
        redN = double(red)/R_MAX*LightOffset; %normalize red channel
        greenN = double(green)/G_MAX*LightOffset; %normalize green channel
        blueN = double(blue)/B_MAX*LightOffset; %normalize blue channel
        
        %Saturation of RGB channels
        if(redN > 1) redN = 1; end
        if(greenN > 1) greenN = 1; end
        if(blueN > 1) blueN = 1; end

        set(gca,'Color',[redN greenN blueN]); %Update background color to resulting color
        drawnow; %Redraw plot
    end   
    
    while(toc() < 1/Frequency);end %Frequency limiting
    time(i) = 1/toc();
    i = i+1;
end
