t = Def.ActorFrame {}

t[#t+1] = Def.Sprite {

    Texture="Bocchi 4x3.png",
    Frame0000=3,	Delay0000=0.2,
    Frame0001=4,	Delay0001=0.2,
    Frame0002=5,	Delay0002=0.2,
    Frame0003=6,	Delay0003=0.2,
    Frame0004=7,	Delay0004=0.2,
    Frame0005=8,	Delay0005=0.2,
    Frame0006=9,	Delay0006=0.2,
    Frame0007=0,	Delay0007=0.2,
    Frame0008=1,	Delay0008=0.2,
    Frame0009=2,	Delay0009=0.2,

    OnCommand=function(self)
    self:effectclock("bgm")
    self:zoom(0.2)
    end

}

return t
