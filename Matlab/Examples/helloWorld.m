Cube = Jobst;

Cube.Connect();

while(1)

    if(Cube.GetOnboardButton(1))
        Cube.SetLED(1,'on');
    else
        Cube.SetLED(1,'off');
    end
end