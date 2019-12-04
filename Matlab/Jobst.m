classdef Jobst < handle
    %JOBST
    %   Changelog:
    %   - Fixed COM port clearing
    %   - Fixed battery voltage reading
    %
    %   Version 1.1
    
    
    properties
        CommunicationOpen = 'closed' % ...
        Initialized = 'false' % ...
        COM_Port % COM port name property, enter in 'COMxy' format
        Update = 'automatic' % 'user', 'automatic'
        Battery %...
        NewDataFlag = 0; %0 - No new data, 1 - New data
        CorruptedTicks = 0 %Counter of messages with CRC error
        MessagesReceived = 0 %Messages received by Matlab Jobst server
        TimeoutLimit = 3000; %Timeout for communication (approx. ms)
        FirmwareVersion %Version of Jobst firmware on Arduino
        ServerVersion = 1.1 %Version of this file
        Sensors %Structure holding data about Sensors
        Motors %Structure holding data about Motors
    end
    
    properties (Hidden = true)
        MC_baudrate = 1000000
        MSGIN_LEN = 121
        MSGOUT_LEN = 27
        serObj  %Handle for serial object
        DataIn  %Incoming message from Arduino
        DataInit
        DataOut %control variables being sent to Arduino, see datasheet for more information
        tmrObj  %handle for Timer object
        watchdog %handle for watchdog Timer
        CheckBit = 0  %CheckBit for message synchronizing purposes
        Frequency = 50 %Default 50 ... Frequency at which updates of control variables and sensor readings happen (relevant only for Update == 'timer')
        MissedTicks = 0 %Unused
        OutOfSync = 0 %Unused
        CorruptedTicksLimit = 500;
        ReconnectLimit = 0;
        WatchdogTicks = 0 %[s]
        EndMessage
        SensorList
        Garbage
    end
    
    methods (Access = public)
        function h = Jobst(~)
            %JOBST Constructor for Jobst object
            
            h.DataIn = zeros(h.MSGIN_LEN,1);
            h.DataOut = [hex2dec('AA'), zeros(1,h.MSGOUT_LEN-3), h.MSGOUT_LEN, hex2dec('CC')];
            h.EndMessage = h.DataOut;
            
            h.SensorList = {0, 255, hex2dec('EA'), hex2dec('74'), hex2dec('75'), hex2dec('76');...
                            'None','None', 'IMU', 'Ultrasonic', 'RGB', 'Button'};
            
            SCont = struct('Type', 'None', 'Readings', zeros(6,1));
            h.Sensors = struct('no1', SCont, 'no2', SCont, 'no3',SCont,...
                             'no4', SCont,'no5', SCont, 'no6', SCont);            
            clear SCont
            
            MCont = struct('Speed', [], 'Current', [], 'Position', []);
            h.Motors = struct('A', MCont,'B', MCont,'C', MCont,'D', MCont,'E', MCont,'F', MCont);
            clear MCont
            
        end
        
        
        function Connect(h,varargin)
            %CONNECT Connects to Jobst and runs initialization
            %
            % CONNECT() connects to first COM port it sees, in case of
            % using multiple COM devices, specify port manually
            % 
            % CONNECT('COMxy') connect to specified COM port
            % 
            % See also JOBST, DISCONNECT
            
            h.ReconnectLimit = 0;
            h.WatchdogTicks = 0; %[s]
            
            
            instr = instrfind('Name', 'JobstCOMPort');
            if(~isempty(instr))
%                 answer = questdlg('Jobst is already connected, are you sure you want to reconnect?', ...
%                     'Warning', ...
%                     'Reconnect','Keep current connection','Keep current connection');
%                 % Handle response
%                 switch answer
%                     case 'Keep current connection'
%                         disp('Connect command ignored');
%                     case 'Reconnect'
%                         fclose(instr);
%                 end

                fclose(instr);
                answer = 'Reconnect'; %Hack - experimental feature, implement later!
            else
                answer = 'Reconnect'; %No opened COM port -> proceed to connecting
            end
            
            
            if(isempty(varargin)) %COM port is not specified when function is called
                if(isempty(h.COM_Port)) %check if COM port was specified earlier
                    devices = seriallist; 

                    if(length(devices) > 1)
                        h.COM_Port = devices(2);
                    elseif(length(devices) == 1 && devices ~= 'COM1') %Throw away COM1. NOTE: Verify Arduino can't show on COM1
                        h.COM_Port = devices;
                    else    
                        error('Could not find Jobst, please try specifying COM port and making sure Jobst is connected')
                    end
                    clear devices;
                end
            else
                h.COM_Port = varargin;
            end
            
            if(strcmp(answer,'Reconnect'))
                oldTimer = timerfind('Name', 'JobstTimer');
                if(~isempty(oldTimer))
                    delete(oldTimer);
                end

                oldTimer = timerfind('Name', 'WatchDogTimer');
                if(~isempty(oldTimer))
                    delete(oldTimer);
                end
                
                try
                    h.serObj = serial(h.COM_Port,'BaudRate',h.MC_baudrate);
                    h.serObj.InputBufferSize = h.MSGIN_LEN*4;
                    h.serObj.OutputBufferSize = h.MSGOUT_LEN*4;
                    h.serObj.Name = 'JobstCOMPort';

                    fopen(h.serObj);
                    pause(1.2)
                    h.CommunicationOpen = 'open';
                    msg = ["Successfully connected to Jobst on port ", h.COM_Port,"\n"];
                    fprintf(join(msg,""));
                    %disp('Successfully connected to Jobst')
                catch
                    error('Could not connect to Jobst, please try checking the COM port.')
                end
                h.Initialize(); %Find out which sensors are connected to Jobst and setup Serial callback
                h.watchdog = timer;
                h.watchdog.Name = 'WatchDogTimer';
                h.watchdog.TimerFcn = @(src,evt)WatchdogFcn(h);
                h.watchdog.BusyMode = 'queue';
                h.watchdog.ExecutionMode = 'fixedSpacing';
                h.watchdog.Period = 1; %check every second if program is not stuck
                h.watchdog.StartDelay = 2;
                start(h.watchdog);
            end
        end
        
       
        
        
        function Initialize(h)
            %INITIALIZE Initializes Jobst
            %   
            %       Usage: Jobst.Initialize;
            %
            %   Find out which sensors are connected to Jobst and
            %   update property Sensors accordingly.
            %   
            %   This function fixes Update property, so any changes to "Update" 
            %   property after Initialization won't have any effect.
            %
            %   This function is called from "Connect" function, since it
            %   requires open communication. It is not necessary to call
            %   this function separately!
            %
            %   See also JOBST, CONNECT

            
            h.DataOut(h.MSGOUT_LEN) = hex2dec('CD'); %Set initialize byte
            h.DataOut(h.MSGOUT_LEN-1) = h.calculateCRC(h.DataOut(1:end-2));
            pause(1);
            fwriteJobst(h.serObj,h.DataOut,'uint8','sync');
            h.DataOut(h.MSGOUT_LEN) = hex2dec('CC');
            %h.SendData;
        
            while(h.serObj.BytesAvailable < h.MSGIN_LEN)
                pause(0.001);
                %disp(h.serObj.BytesAvailable)
            end %Wait for Arduino answer
            
            h.DataInit = freadJobst(h.serObj,h.MSGIN_LEN,'uint8');
            pause(0.5);
            h.ResolveSensors; %Parse incoming sensor types to inner structures
            h.FirmwareVersion = h.DataInit(4)/10;
            
            %disp('Sensors initialized');
            infoMsg = ["Sensors initialized ...\n",...
                       "\nSensor 1: ",h.Sensors.no1.Type,...
                       "\nSensor 2: ",h.Sensors.no2.Type,...
                       "\nSensor 3: ",h.Sensors.no3.Type,...
                       "\nSensor 4: ",h.Sensors.no4.Type,...
                       "\nSensor 5: ",h.Sensors.no5.Type,...
                       "\nSensor 6: ",h.Sensors.no6.Type,...
                       "\n",...
                       "\nJobst firmware Version: ",h.FirmwareVersion,...
                       "\nMatlab server Version: ",h.ServerVersion,"\n\n"];
            fprintf(join(infoMsg,""));
            h.DataIn(2:3) = h.DataInit(2:3);
            volt = h.GetBatteryVoltage;
            if(volt < 2.8)
                warning('Battery is low, please charge Jobst');
            end
    
            fclose(h.serObj);
            h.serObj.BytesAvailableFcnCount = h.MSGIN_LEN;
            h.serObj.BytesAvailableFcnMode = 'byte';
            
            if(strcmp(h.Update,'timer'))
                answer = questdlg('Timer update is experimental feature and using it is not recommended, use automatic update instead?', ...
                        'Warning', ...
                        'Proceed','Use automatic','Use automatic');
                % Handle response
                switch answer
                    case 'Proceed'
                        disp('Using timer update');
                    case 'Use automatic'
                        h.Update = 'automatic';
                end
            end
            
            if(strcmp(h.Update,'timer'))  %Timer Update
                h.serObj.BytesAvailableFcn = @(src,evt)NewDataFlagOnly(h);
                h.tmrObj = timer;
                h.tmrObj.Name = 'JobstTimer';
                h.tmrObj.TimerFcn = @(src,evt)SyncedTimerUpdate(h);
                h.tmrObj.BusyMode = 'queue';
                h.tmrObj.ExecutionMode = 'fixedRate';
                h.tmrObj.Period = 1/h.Frequency;
                fopen(h.serObj);
                pause(1.3);
                h.SendData;
                start(h.tmrObj);
            elseif(strcmp(h.Update,'user')) %User Cube Update
                h.serObj.BytesAvailableFcn = @(src,evt)NewDataFlagOnly(h);
                fopen(h.serObj);
                pause(1.3);
                %h.SendData;
            else %default automatic
                h.serObj.BytesAvailableFcn = @(src,evt)NewData(h);
                fopen(h.serObj);
                pause(1.3);
                h.SendData;
            end
            
            %Doplnit inicializaci na Arduinu          
            h.Initialized = 'true';
            disp('Jobst initialization successfully completed')
            %h.SendData;
        end
        
        
        
        function Disconnect(h)
            %DISCONNECT Terminate communication with Jobst
            %   
            %       Usage: Jobst.Disconnect;
            %
            %   This method can be called from various functions inside
            %   Jobst object, however if using Update = 'automatic'
            %   (default), use this method to terminate data exchange
            %   between Matlab and Jobst.
            %   
            %   See also JOBST, CONNECT
            try
                if(strcmp(h.Update,'timer'))
                    stop(h.tmrObj);
                    delete(h.tmrObj);
                end
                
                dog = timerfind('Name', 'WatchDogTimer');
                if(~isempty(dog))
                    stop(dog);
                    delete(dog);
                end
                
                if(strcmp(h.CommunicationOpen,'open'))
                    %h.EndMessage(h.MSGOUT_LEN-1) = h.calculateCRC(h.EndMessage(1:end-2));
                    while(h.serObj.BytesToOutput > 0)end
                    %fwriteJobst(h.serObj,h.EndMessage,'uint8','sync');
                    fclose(h.serObj);
                    delete(h.serObj);
                    h.CommunicationOpen = 'closed';
                    disp('Succesfully disconnected Jobst');
                else
                    disp('Jobst is already disconnected!');
                end
                
%                 %Clear COMPorts - Temporary, find where COM ports are not
%                 %deleted and fix that
                prts = instrfind('Name','JobstCOMPort');
                for(i = 1:length(prts))
                    fclose(prts(i));
                    delete(prts(i));
                end
            catch
                disp('Error occured during disconnecting');
            end
            
        end
        
        
        
       function GetData(h)
            %GETDATA Read incoming data from Jobst
            %
            %       usage: Jobst.GetData;
            %
            %   Use this method only when property Update is set to 'user'.
            %   At the same time, it is required to use this method when
            %   using 'user' Update, because it is only way to obtain new
            %   data from Jobst.
            %   
            %   Example 1 (User update):
            %       
            %        Cube = Jobst;
            %        Cube.Update = 'user';
            %        Cube.Connect;
            %        
            %        Cube.SendData; %This is required to "kickstart"
            %                        communication
            %        while(1)
            %            Cube.GetData; %Get new sensor readings
            %            .
            %            . %Do something with new readings
            %            .
            %            Cube.SendData; %Send new action values
            %        end
            %
            %    Example 2 (Default automatic update):
            %       
            %        Cube = Jobst;
            %        Cube.Connect;
            %        
            %        while(1)
            %            [R G B] = Cube.GetRGB(2);
            %            ...
            %            ... %Do something with new readings
            %            ...
            %            Cube.SetMotorPercentage('A',speed);
            %        end
            %        Cube.Disconnect;
            %           
            %        
            %   See also SENDDATA, JOBST, CONNECT, DISCONNECT
            
            timeout = 0;
            %retries = 0;
            while(h.NewDataFlag == 0)
                timeout = timeout + 1;
                if(timeout >= h.TimeoutLimit)
                    h.Disconnect;
                    error('Timeout exceeded - Cube not responding!');
                end
                pause(0.001);
            end
            %disp(timeout);
            h.DataIn = freadJobst(h.serObj,h.MSGIN_LEN,'uint8');
            h.NewDataFlag = 0;
            if(h.checkCRC(h.DataIn,h.DataIn(h.MSGIN_LEN-1)) == 0)
                h.CorruptedTicks = h.CorruptedTicks + 1;
                if(h.CorruptedTicks > h.CorruptedTicksLimit)
                   h.Disconnect;
                   error('Too many CRC errors, communication terminated');
                end
            else
                %h.UpdateStructures; %Doplnit
            end
        end

        
        function SendData(h)
            %SENDATA Send action values to Jobst
            %
            %       usage: Jobst.SendData;
            %
            %   Use this method only when property Update is set to 'user'.
            %   At the same time, it is required to use this method when
            %   using 'user' Update, because it is only way to control
            %   peripheries on Jobst.
            %   
            %   Example 1 (User update):
            %       
            %        Cube = Jobst;
            %        Cube.Update = 'user';
            %        Cube.Connect;
            %        
            %        Cube.SendData; %This is required to "kickstart"
            %                        communication
            %        while(1)
            %            Cube.GetData; %Get new sensor readings
            %            .
            %            . %Do something with new readings
            %            .
            %            Cube.SendData; %Send new action values
            %        end
            %
            %    Example 2 (Default automatic update):
            %       
            %        Cube = Jobst;
            %        Cube.Connect;
            %        
            %        while(1)
            %            [R G B] = Cube.GetRGB(2);
            %            ...
            %            ... %Do something with new readings
            %            ...
            %            Cube.SetMotorPercentage('A',speed);
            %        end
            %        Cube.Disconnect;
            %           
            %        
            %   See also GETDATA, JOBST, CONNECT, DISCONNECT  
            
            
            h.DataOut(h.MSGOUT_LEN-1) = h.calculateCRC(h.DataOut(1:end-2));
            %disp(h.serObj.BytesToOutput);
            %while(h.serObj.BytesToOutput > 0)
            %end
            fwriteJobst(h.serObj,h.DataOut,'uint8','sync'); %%Could be 'async' for it is a bit faster, but is less robust
            %disp('Data sent')
        end
        
        function ShowSensors(h)
            %SHOWSENSORS Print out message with human readable sensor types
            %
            %   Usage: Jobst.ShowSensors;
            %   
            %   Default sensor types are 'RGB', 'IMU', 'Button' and
            %   'Ultrasonic'. If you see 'Unknown', try plugging sensor out
            %   and back in, then running Initialize method.
            %
            %   NOTE: Connected sensors are checked only during
            %   Initialization sequence, so if you connect or disconnect
            %   any sensors from Jobst after Connect/Initialize command, it
            %   will not be shown here.
            %
            %   See also JOBST, CONNECT, INITIALIZE
            infoMsg = ["Connected sensors:\n",...
                       "\n\tSensor 1: ",h.Sensors.no1.Type,...
                       "\n\tSensor 2: ",h.Sensors.no2.Type,...
                       "\n\tSensor 3: ",h.Sensors.no3.Type,...
                       "\n\tSensor 4: ",h.Sensors.no4.Type,...
                       "\n\tSensor 5: ",h.Sensors.no5.Type,...
                       "\n\tSensor 6: ",h.Sensors.no6.Type,...
                       "\n"];
            fprintf(join(infoMsg,""));
        end
        
        function SetMotorPWM(h, port, pwm, dir)
            %SETMOTORPWM Set raw motor action values
            %
            %   SETMOTORPWM(port, pwm, dir);
            %       - port ...  Port where motor is connected in format
            %                   'A', 'B' ... 'F'
            %       - pwm ...   Integer value from 0 to 255
            %       - dir ...   Integer value 0 or 1 only
            %
            %   See also JOBST, SETMOTORPERCENTAGE, SETMOTORPOSITION,
            %   GETENCODERTICKS
            
            
            if(h.isMPortValid(port) == 0)
                error('Wrong motor port format!');
            end
            if(pwm < 0 || pwm > 255)
                error('Entered PWM is out of range <0 .. 255>!');
            end
            if(dir ~= 0 && dir ~= 1)
                error('Wrong Direction value, enter only 0 or 1!');
            end
            
            motAbyte = 6;
            h.DataOut(motAbyte + 3*(port - 'A')) = uint8(pwm);
            h.DataOut(motAbyte + 3*(port - 'A') + 1) = uint8(dir);  
            h.DataOut(motAbyte + 3*(port - 'A') + 2) = 0;
        end
        
        function SetMotorPercentage(h, port, power)
            %SETMOTORPERCENTAGE Set motor to percentage of power in both
            %directions
            %
            %   SETMOTORPERCENTAGE(port, speed);
            %       - port ...  Port where motor is connected in format
            %                   'A', 'B' ... 'F'
            %       - power ... Double value from -100 to 100
            %
            %   See also JOBST, SETMOTORPWM, SETMOTORPOSITION, GETENCODERTICKS
            if(h.isMPortValid(port) == 0)
                error('Wrong motor port format!');
            end
            if(power < -100 || power > 100)
                error('Entered speed is out of range <-100 .. 100>!');
            end
            motAbyte = 6;
            
            if(power > 0)
                dir = 1;
            else
                dir = 0;
            end
            
            pwm = abs(power*2.55);
            
            h.DataOut(motAbyte + 3*(port - 'A')) = uint8(pwm);
            h.DataOut(motAbyte + 3*(port - 'A') + 1) = uint8(dir);  
            h.DataOut(motAbyte + 3*(port - 'A') + 2) = 0;
        end
        
        
        function SetMotorPosition(h, port, ticks)
            %SETMOTORPOSITION Set motor to specified position
            %
            %   SETMOTORPOSITION(port, ticks);
            %       - port ...  Port where motor is connected in format
            %                   'A', 'B' ... 'F'
            %       - ticks ... Integer value from -32768 to 32768
            %
            %   NOTE: For NXT Motor, 360° turn equals 720 ticks
            %
            %   See also JOBST, SETMOTORPWM, SETMOTORPERCENTAGE,
            %   GETENCODERTICKS
            if(h.isMPortValid(port) == 0)
                error('Wrong motor port format!');
            end
            if(ticks < -32768 && ticks > 32767)
                error('Entered ticks value is out of range <-32768 .. 32767>!');
            end
            
            motAbyte = 6;
            if(ticks == 0) %%Workaround, because if ticks == 0, Arduino will stop motor instead of positioning
                ticks = 1;
            end
            h.DataOut(motAbyte + 3*(port - 'A')) = 0;
            bytes = typecast(int16(ticks),'uint8');
            h.DataOut(motAbyte + 3*(port - 'A') + 1) = bytes(2);  
            h.DataOut(motAbyte + 3*(port - 'A') + 2) = bytes(1);
        end
        
        function SetLED(h, port, value)
            %SETLED Turn onboard LED on or off
            %
            %   SETLED(port, value);
            %       - port ...      Integer value from 1 to 4
            %       - value ...     0 or 1, or 'on'/'off'
            %
            %   See also JOBST
            if(port < 1 || port > 4)
                error('LED port is out range <1..4>');
            end
            
            if(isa(value,'char'))
                if(strcmp(value,'on'))
                    led = 1;
                elseif(strcmp(value,'off'))
                    led = 0;
                else
                    error('Wrong format, input only "on"/"off", or 0/1!');
                end
            elseif(value == 0 || value == 1)
                led = value;
            else
                error('Wrong format, input only "on"/"off", or 0/1!');
            end
                
            h.DataOut(1+port) = uint8(led);
        end
        
        function ticks = GetEncoderTicks(h, port)
            %GETENCODERTICKS Get encoder ticks from specified motor
            %
            %   ticks = GETENCODERTICKS(port)
            %       - ticks ...     ticks of encoder
            %       - port ...      Port to which motor is connected, in
            %                       format 'A','B', ..., 'F'
            %
            %   NOTE: For Lego NXT Motor, 360° turn equals 720 ticks.
            %       
            %   See also JOBST, SETMOTORPWM, SETMOTORPOSITION,
            %   SETMOTORPERCENTAGE, GETMOTORCURRENT
            if(h.isMPortValid(port) == 0)
                error('Wrong motor port format!');
            end
            motAbyte = 22;
            posH = h.DataIn(motAbyte + 4*(port - 'A'));
            posL = h.DataIn(motAbyte + 4*(port - 'A') + 1);
            ticks = swapbytes(typecast(uint8([posH posL]),'int16'));
        end
        
        function current = GetMotorCurrent(h, port)
            %GETMOTORCURRENT Read current flowing to specified motor
            %
            %   current = GETMOTORCURRENT(port);
            %       - current ...   current in mA
            %       - port ...      Port to which motor is connected, in
            %                       format 'A','B', ..., 'F'
            %
            %
            %   See also JOBST, GETMOTORTICKS, SETMOTORPWM,
            %   SETMOTORPERCENTAGE
            
            
            if(h.isMPortValid(port) == 0)
                error('Wrong motor port format!');
            end
            
            motAbyte = 22;
            currentRaw = h.DataIn(motAbyte + 4*(port - 'A') + 3);
            current = cast(currentRaw,'double')*5/(255*3.6);
        end
        
        function voltage = GetBatteryVoltage(h)
            %GETBATTERYVOLTAGE Print out battery charge and return voltage
            %
            %   voltage = GETBATTERYVOLTAGE;
            %       - voltage ... Output voltage in Volts
            %
            % See also JOBST, GETMOTORCURRENT
            
            H = h.DataIn(2);
            L = h.DataIn(3);
            voltageRaw = swapbytes(typecast(uint8([H L]),'uint16'));
            voltage = cast(voltageRaw,'double')*5/1024;
            
            msg = ["Battery is at ",floor((voltage - 2.5)/1.7*100),"%% \n"];
            fprintf(join(msg,""));
        end
        
        function [accX, accY, accZ] = GetOnboardAcceleration(h)
            %GETONBOARDACCELERATION Return acceleration in 3 axes (onboard
            %IMU)
            %
            %   [accX accY accZ] = GETONBOARDACCELERATION;
            %       - accX ... acceleration in X
            %       - accY ... acceleration in Y
            %       - accZ ... acceleration in Z
            %
            % NOTE: IMU resolution 2g, output range is equivalent to int16
            %
            % See also JOBST, GETONBOARDGYRO, GETACCELERATION
            
            axH = h.DataIn(10);
            axL = h.DataIn(11);
            ayH = h.DataIn(12);
            ayL = h.DataIn(13);
            azH = h.DataIn(14);
            azL = h.DataIn(15);
            
            accX = swapbytes(typecast(uint8([axH axL]),'int16'));
            accY = swapbytes(typecast(uint8([ayH ayL]),'int16'));
            accZ = swapbytes(typecast(uint8([azH azL]),'int16'));
        end
        
        function [gyroX, gyroY, gyroZ] = GetOnboardGyro(h)
            %GETONBOARDGYRO Return angular velocity in 3 axes (onboard IMU)
            %
            %   [gyroX gyroY gyroZ] = GETONBOARDGYRO;
            %       - gyroX ... angular velocity in X
            %       - gyroY ... angular velocity in Y
            %       - gyroZ ... angular velocity in Z
            %
            % NOTE: IMU resolution 250 dps (degrees per second), output
            % range is equivalent to int16
            %
            % See also JOBST, GETONBOARDGYRO, GETACCELERATION
            
            gxH = h.DataIn(16);
            gxL = h.DataIn(17);
            gyH = h.DataIn(18);
            gyL = h.DataIn(19);
            gzH = h.DataIn(20);
            gzL = h.DataIn(21); 
            
            gyroX = swapbytes(typecast(uint8([gxH gxL]),'int16'));
            gyroY = swapbytes(typecast(uint8([gyH gyL]),'int16'));
            gyroZ = swapbytes(typecast(uint8([gzH gzL]),'int16'));
        end
        
        function [temperature] = GetTemperature(h)
            %GETTEMPERATURE Returns onboard temperature sensor in °C
            %
            %   temperature = GETTEMPERATURE;
            %       - temperature ... reading in Celsius
            %
            % See also: JOBST
            tempH = h.DataIn(8);
            tempL = h.DataIn(9);
            temperatureRaw = swapbytes(typecast(uint8([tempH tempL]),'uint16'));
            
            temperature = (cast(temperatureRaw,'double')*(5/1024)-0.5)/0.01;
        end
        
        function [pressed] = GetOnboardButton(h,number)
            %GETONBOARDBUTTON Return 1 if button is pressed, otherwise 0
            %
            %   pressed = GETONBOARDBUTTON(number)
            %       - pressed ...   1 if pressed, 0 if not
            %       - number ...    integer value from <1..4> corresponding
            %                       to button
            %
            % See also: JOBST, GETBUTTON
            
            if(number < 1 || number > 4)
                error('Button port is out of range <1..4>!');
            end
           pressed = h.DataIn(3+number);
        end
        
        function [pressed] = GetButton(h,port)
            %GETBUTTON Return 1 if button is pressed, otherwise 0
            %
            %   pressed = GETONBOARDBUTTON(port)
            %       - pressed ...   1 if pressed, 0 if not
            %       - port ...      integer value from <1..6> corresponding
            %                       to port, where button is connected
            %
            % See also: JOBST, GETONBOARDBUTTON
            
            if(port < 1 || port > 6)
                error('Sensor port is out of range <1 .. 6>!');
            end
           S1Byte = 46;
           pressed = h.DataIn(S1Byte + 12*(port-1));
        end
        
        function distance = GetDistance(h, port)
            %GETDISTANCE Return distance from ultrasonic sensor in mm
            %
            %   distance = GETDISTANCE(port)
            %       - distance ...  distance from sensor in milimeters
            %       - port ...      integer value from <1..6> corresponding
            %                       to port, where sensor is connected
            %
            % See also JOBST, GETLIGHT, GETRGB, GETACCELERATION
            
            if(port < 1 || port > 6)
                error('Sensor port is out of range <1 .. 6>!');
            end
            
            S1Byte = 46;
            H = h.DataIn(S1Byte + 12*(port-1));
            L = h.DataIn(S1Byte + 12*(port-1) + 1);
            int = swapbytes(typecast(uint8([H L]),'uint16'));
            distance = int*0.34/2;
        end
        
        function light = GetLight(h, port)
            %GETLIGHT Return light intensity from RGB sensor
            %
            %   light = GETLIGHT(port)
            %       - light ...  intensity of light measured by RGB sensor
            %       - port ...   integer value from <1..6> corresponding
            %                    to port, where sensor is connected
            %
            % See also JOBST, GETDISTANCE, GETRGB, GETACCELERATION
            if(port < 1 || port > 6)
                error('Sensor port is out of range <1 .. 6>!');
            end
            
            S1Byte = 46;
            clearH = h.DataIn(S1Byte + 12*(port-1) + 0);
            clearL = h.DataIn(S1Byte + 12*(port-1) + 1);

            light = swapbytes(typecast(uint8([clearH clearL]),'uint16'));
        end
        
        function [red, green, blue] = GetRGB(h, port)
            %GETRGB Return color intensity from RGB sensor
            %
            %   [red green blue] = GETLIGHT(port)
            %       - red ...   intensity of red measured by RGB sensor
            %       - green ... intensity of green measured by RGB sensor
            %       - blue ...  intensity of blue measured by RGB sensor
            %       - port ...  integer value from <1..6> corresponding
            %                   to port, where sensor is connected
            %
            % NOTE: Intensities are offsetted by default values of -3000,
            % -4500 and -5300 (Red, green, blue).
            %
            % See also JOBST, GETDISTANCE, GETLIGHT, GETACCELERATION
            if(port < 1 || port > 6)
                error('Sensor port is out of range <1 .. 6>!');
            end
            
           S1Byte = 46;
           offsetRed = -3000;
           offsetGreen = -4500;
           offsetBlue = -5300;
           %offsetting could use some rework - leave it on user side?
           redH = h.DataIn(S1Byte + 12*(port-1) + 2);
           redL = h.DataIn(S1Byte + 12*(port-1) + 3);
           grnH = h.DataIn(S1Byte + 12*(port-1) + 4);
           grnL = h.DataIn(S1Byte + 12*(port-1) + 5);
           bluH = h.DataIn(S1Byte + 12*(port-1) + 6);
           bluL = h.DataIn(S1Byte + 12*(port-1) + 7);
           
           red = swapbytes(typecast(uint8([redH redL]),'uint16')) + offsetRed;
           green = swapbytes(typecast(uint8([grnH grnL]),'uint16')) + offsetGreen;
           blue = swapbytes(typecast(uint8([bluH bluL]),'uint16')) + offsetBlue;
        end
        
        function accX = GetAccelerationX(h, port)
            %GETACCELERATIONX Return acceleration in X axis
            %
            %   accX = GETACCELERATIONX(port);
            %       - accX ...  Acceleration in X direction measured by
            %                   sensor
            %       - port ...  integer value from <1..6> corresponding
            %                   to port, where sensor is connected
            %
            % NOTE: default resolution of Jobst IMU is +-2g with resolution
            % equivalent to int16
            %
            % See also: JOBST, GETACCELERATION
            if(port < 1 || port > 6)
                error('Sensor port is out of range <1 .. 6>!');
            end
            
            S1Byte = 46;
            axH = h.DataIn(S1Byte + 12*(port-1) + 0);
            axL = h.DataIn(S1Byte + 12*(port-1) + 1);
            
            accX = swapbytes(typecast(uint8([axH axL]),'int16'));
        end
        
        function accY = GetAccelerationY(h, port)
            %GETACCELERATIONY Return acceleration in Y axis
            %
            %   accY = GETACCELERATIONY(port);
            %       - accY ...  Acceleration in Y direction measured by
            %                   sensor
            %       - port ...  integer value from <1..6> corresponding
            %                   to port, where sensor is connected
            %
            % NOTE: default resolution of Jobst IMU is +-2g with resolution
            % equivalent to int16
            %
            % See also: JOBST, GETACCELERATION
            
            if(port < 1 || port > 6)
                error('Sensor port is out of range <1 .. 6>!');
            end
            
            S1Byte = 46;
            ayH = h.DataIn(S1Byte + 12*(port-1) + 2);
            ayL = h.DataIn(S1Byte + 12*(port-1) + 3);
            
            accY = swapbytes(typecast(uint8([ayH ayL]),'int16'));
        end
        
        function accZ = GetAccelerationZ(h, port)
            %GETACCELERATIONZ Return acceleration in Z axis
            %
            %   accZ = GETACCELERATIONZ(port);
            %       - accZ ...  Acceleration in Z direction measured by
            %                   sensor
            %       - port ...  integer value from <1..6> corresponding
            %                   to port, where sensor is connected
            %
            % NOTE: default resolution of Jobst IMU is +-2g with resolution
            % equivalent to int16
            %
            % See also: JOBST, GETACCELERATION
            
            if(port < 1 || port > 6)
                error('Sensor port is out of range <1 .. 6>!');
            end
            
            S1Byte = 46;
            azH = h.DataIn(S1Byte + 12*(port-1) + 4);
            azL = h.DataIn(S1Byte + 12*(port-1) + 5);
            
            accZ = swapbytes(typecast(uint8([azH azL]),'int16'));
        end
        
        function [accX, accY, accZ] = GetAcceleration(h,port)
            %GETACCELERATION Return acceleration in 3 axes
            %
            %   [accX accY accZ] = GETACCELERATION(port);
            %       - accX ... acceleration in X
            %       - accY ... acceleration in Y
            %       - accZ ... acceleration in Z
            %       - port ... integer value from <1..6> corresponding
            %                  to port, where sensor is connected
            %
            % NOTE: default resolution of Jobst IMU is +-2g with resolution
            % equivalent to int16
            %
            % See also JOBST, GETACCELERATIONX, GETACCELERATIONY, 
            % GETACCELERATIONZ, GETONBOARDACCELERATION
            if(port < 1 || port > 6)
                error('Sensor port is out of range <1 .. 6>!');
            end
            
            accX = h.GetAccelerationX(port);
            accY = h.GetAccelerationY(port);
            accZ = h.GetAccelerationZ(port);
        end
        
        function gyroX = GetGyroX(h, port)
            %GETAGYROX Return angular velocity in X axis
            %
            %   gyroX = GETGYROX(port);
            %       - gyroX ...  Angular velocity in X direction measured by
            %                    sensor
            %       - port ...   integer value from <1..6> corresponding
            %                    to port, where sensor is connected
            %
            % NOTE: default resolution of Jobst IMU is +-1000 degrees per
            % second with resolution equivalent to int16
            %
            % See also: JOBST, GETGYRO, GETGYROY, GETGYROZ, GETACCELERATION
            
            if(port < 1 || port > 6)
                error('Sensor port is out of range <1 .. 6>!');
            end
            
            S1Byte = 46;
            gxH = h.DataIn(S1Byte + 12*(port-1) + 6);
            gxL = h.DataIn(S1Byte + 12*(port-1) + 7);
            
            gyroX = swapbytes(typecast(uint8([gxH gxL]),'int16'));
        end
        
        function gyroY = GetGyroY(h, port)
            %GETAGYROY Return angular velocity in Y axis
            %
            %   gyroY = GETGYROY(port);
            %       - gyroY ...  Angular velocity in Y direction measured by
            %                    sensor
            %       - port ...   integer value from <1..6> corresponding
            %                    to port, where sensor is connected
            %
            % NOTE: default resolution of Jobst IMU is +-250 degrees per
            % second with resolution equivalent to int16
            %
            % See also: JOBST, GETGYRO, GETGYROX, GETGYROZ, GETACCELERATION
            if(port < 1 || port > 6)
                error('Sensor port is out of range <1 .. 6>!');
            end
            
            S1Byte = 46;
            gyH = h.DataIn(S1Byte + 12*(port-1) + 8);
            gyL = h.DataIn(S1Byte + 12*(port-1) + 9);
            
            gyroY = swapbytes(typecast(uint8([gyH gyL]),'int16'));
        end
        
        function gyroZ = GetGyroZ(h, port)
            %GETAGYROZ Return angular velocity in Z axis
            %
            %   gyroZ = GETGYROZ(port);
            %       - gyroZ ...  Angular velocity in Z direction measured by
            %                    sensor
            %       - port  ...  integer value from <1..6> corresponding
            %                    to port, where sensor is connected
            %
            % NOTE: default resolution of Jobst IMU is +-250 degrees per
            % second with resolution equivalent to int16
            %
            % See also: JOBST, GETGYRO, GETGYROX, GETGYROY, GETACCELERATION
            
            if(port < 1 || port > 6)
                error('Sensor port is out of range <1 .. 6>!');
            end
            
            S1Byte = 46;
            gzH = h.DataIn(S1Byte + 12*(port-1) + 10);
            gzL = h.DataIn(S1Byte + 12*(port-1) + 11);
            
            gyroZ = swapbytes(typecast(uint8([gzH gzL]),'int16'));
        end
        
        function [gyroX, gyroY, gyroZ] = GetGyro(h,port)
            %GETGYRO Return angular velocity in 3 axes
            %
            %   [gyroX gyroY gyroZ] = GETGYRO(port);
            %       - gyroX ... angular velocity in X
            %       - gyroY ... angular velocity in Y
            %       - gyroZ ... angular velocity in Z
            %       - port  ... integer value from <1..6> corresponding
            %                   to port, where sensor is connected
            %
            % NOTE: default resolution of Jobst IMU is +-250 degrees per
            % second with resolution equivalent to int16
            %
            % See also JOBST, GETACCELERATIONX, GETACCELERATIONY, 
            % GETACCELERATIONZ, GETONBOARDACCELERATION
            if(port < 1 || port > 6)
                error('Sensor port is out of range <1 .. 6>!');
            end
            
            gyroX = h.GetGyroX(port);
            gyroY = h.GetGyroY(port);
            gyroZ = h.GetGyroZ(port);
        end
            
        
    end
   
    
    
    
    methods (Hidden = true)      
        
        function SyncedTimerUpdate(h) %Experimental, untested!
            if(h.NewDataFlag == 1)
                h.DataIn=freadJobst(h.serObj,h.MSGIN_LEN,'uint8');
                checkBitIn = h.DataIn(h.MSGIN_LEN - 2);

                if(checkBitIn == h.CheckBit)
                    if(h.CheckBit < 255)
                        h.CheckBit = h.CheckBit + 1;
                    else
                        h.CheckBit = 0;
                    end
                    h.DataOut(h.MSGOUT_LEN-2) = h.CheckBit;
                else
                    h.OutOfSync = h.OutOfSync + 1;
                end
                
                if(h.checkCRC(h.DataIn,h.DataIn(h.MSGIN_LEN-1)) == 0) %Wrong CRC
                    h.CorruptedTicks = h.CorruptedTicks + 1;
                    if(h.CorruptedTicks > h.CorruptedTicksLimit)
                       h.Disconnect;
                       error('Too many CRC errors, communication terminated');
                    end
                else %CRC OK
                    %h.UpdateStructures; %Doplnit
                end
                      
            else
                h.MissedTicks = h.MissedTicks + 1;
            end
            h.SendData;
            %fwriteJobst(h.serObj,h.DataOut,'uint8');
        end
        
        
        
        
        function delete(h)
            if(strcmp(h.Update,'timer'))
                stop(h.tmrObj);
                delete(h.tmrObj);
            end
            if(strcmp(h.CommunicationOpen,'open'))
                fclose(h.serObj);
                delete(h.serObj);
            end  
        end
    end
    
    
    
    
    
    methods (Access = private)
        function NewData(h)
            %NEWDATA callback from BytesAvailableFcn
            %Callback for default Automatic update
            h.NewDataFlag = 1;
            h.WatchdogTicks = 0;
            h.MessagesReceived = h.MessagesReceived + 1;
            h.DataIn = freadJobst(h.serObj,h.MSGIN_LEN,'uint8');
            h.NewDataFlag = 0;
            if(h.checkCRC(h.DataIn,h.DataIn(h.MSGIN_LEN-1)) == 0) %Wrong CRC
                h.CorruptedTicks = h.CorruptedTicks + 1;
                if(h.CorruptedTicks > h.CorruptedTicksLimit)
                   h.Disconnect;
                   error('Too many CRC errors, communication terminated');
                end
            else %CRC check OK
                %h.UpdateStructures; %Doplnit
            end
            h.SendData;
        end
        
        function NewDataFlagOnly(h)
            %NEWDATA callback from BytesAvailableFcn
            %Callback for User update
            h.NewDataFlag = 1;
            h.WatchdogTicks = 0;
            h.MessagesReceived = h.MessagesReceived + 1;
        end
        
        function WatchdogFcn(h)
            %Watchdog function to disconnect Jobst if it is not responding
            if(h.WatchdogTicks < h.TimeoutLimit/1000)
                h.WatchdogTicks = h.WatchdogTicks + 1;
            else
                if(h.ReconnectLimit > 0)
                    disp('Reconnecting');
                    h.ReconnectLimit = h.ReconnectLimit - 1;
                    h.SendData;
                else
                    h.Disconnect();
                    h.WatchdogTicks = 0;
                    disp('Watchdog - Communication closed, Jobst was not responding');
                end
            end
        end
        
        
        
        function ResolveSensors(h)
            %Fill Sensors's struct field Type with human-readable sensor name
            %NOTE: There should be more elegant way to write this ...
            S1 = find(cell2mat(h.SensorList(1,:)) == h.DataInit(5));
            if(~isempty(S1))
                h.Sensors.no1.Type = cell2mat(h.SensorList(2,S1));
            else
                h.Sensors.no1.Type = 'Unknown';
            end
            S1 = find(cell2mat(h.SensorList(1,:)) == h.DataInit(6));
            if(~isempty(S1))
                h.Sensors.no2.Type = cell2mat(h.SensorList(2,S1));
            else
                h.Sensors.no2.Type = 'Unknown';
            end
            S1 = find(cell2mat(h.SensorList(1,:)) == h.DataInit(7));
            if(~isempty(S1))
                h.Sensors.no3.Type = cell2mat(h.SensorList(2,S1));
            else
                h.Sensors.no3.Type = 'Unknown';
            end
            S1 = find(cell2mat(h.SensorList(1,:)) == h.DataInit(8));
            if(~isempty(S1))
                h.Sensors.no4.Type = cell2mat(h.SensorList(2,S1));
            else
                h.Sensors.no4.Type = 'Unknown';
            end
            S1 = find(cell2mat(h.SensorList(1,:)) == h.DataInit(9));
            if(~isempty(S1))
                h.Sensors.no5.Type = cell2mat(h.SensorList(2,S1));
            else
                h.Sensors.no5.Type = 'Unknown';
            end
            S1 = find(cell2mat(h.SensorList(1,:)) == h.DataInit(10));
            if(~isempty(S1))
                h.Sensors.no6.Type = cell2mat(h.SensorList(2,S1));
            else
                h.Sensors.no6.Type = 'Unknown';
            end

        end
        
        function valid = isMPortValid(h,port)
            if(ischar(port))
                if(port >= 'A' && port <= 'F')
                    valid = 1;
                else
                    valid = 0;
                end
            else
                valid = 0;
            end
        end
        
        function crc = calculateCRC(h,str)
            %XORing whole message (without last 2 bytes)
            c = 0;
            for i = 1:length(str)-2
                c = bitxor(c,str(i));
            end
            crc = c;
        end
        
        function result = checkCRC(h, str, crc)
            %Compare incoming CRC byte with CRC calculated in Matlab
            if(crc == h.calculateCRC(str))
                result = 1;
            else
                result = 0;
            end
        
        end
    
    end
    
end

