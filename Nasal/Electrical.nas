####    jet engine electrical system    ####
####    Syd Adams    ####
var count=0;
var ammeter_ave = 0.0;
var Lbus = props.globals.initNode("/systems/electrical/left-bus",0,"DOUBLE");
var Rbus = props.globals.initNode("/systems/electrical/right-bus",0,"DOUBLE");
var Amps = props.globals.initNode("/systems/electrical/amps",0,"DOUBLE");
var EXT  = props.globals.initNode("/controls/electric/external-power",0,"DOUBLE");
var XTie  = props.globals.initNode("/systems/electrical/xtie",0,"BOOL");
var lbus_volts = 0.0;
var rbus_volts = 0.0;

var lbus_input=[];
var lbus_output=[];
var lbus_load=[];

var rbus_input=[];
var rbus_output=[];
var rbus_load=[];

var lights_input=[];
var lights_output=[];
var lights_load=[];

var strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
aircraft.light.new("controls/lighting/strobe-state", [0.05, 1.30], strobe_switch);
var beacon_switch = props.globals.getNode("controls/lighting/beacon", 1);
aircraft.light.new("controls/lighting/beacon-state", [0.05, 2.0], beacon_switch);

#var battery = Battery.new(switch-prop,volts,amps,amp_hours,charge_percent,charge_amps);
var Battery = {
    new : func(swtch,vlt,amp,hr,chp,cha){
    m = { parents : [Battery] };
            m.switch = props.globals.getNode(swtch,1);
            m.switch.setBoolValue(0);
            m.ideal_volts = vlt;
            m.ideal_amps = amp;
            m.amp_hours = hr;
            m.charge_percent = chp;
            m.charge_amps = cha;
    return m;
    },

    apply_load : func(load,dt) {
        if(me.switch.getValue()){
        var amphrs_used = load * dt / 3600.0;
        var percent_used = amphrs_used / me.amp_hours;
        me.charge_percent -= percent_used;
        if ( me.charge_percent < 0.0 ) {
            me.charge_percent = 0.0;
        } elsif ( me.charge_percent > 1.0 ) {
        me.charge_percent = 1.0;
        }
        var output =me.amp_hours * me.charge_percent;
        return output;
        }else return 0;
    },

    get_output_volts : func {
        if(me.switch.getValue()){
        var x = 1.0 - me.charge_percent;
        var tmp = -(3.0 * x - 1.0);
        var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
        var output =me.ideal_volts * factor;
        return output;
        }else return 0;
    },

    get_output_amps : func {
        if(me.switch.getValue()){
        var x = 1.0 - me.charge_percent;
        var tmp = -(3.0 * x - 1.0);
        var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
        var output =me.ideal_amps * factor;
        return output;
        }else return 0;
    }
};

# var alternator = Alternator.new(num,switch,rpm_source,rpm_threshold,volts,amps);
var Alternator = {
    new : func (num,switch,src,thr,vlt,amp){
        m = { parents : [Alternator] };
        m.switch =  props.globals.getNode(switch,1);
        m.switch.setBoolValue(0);
        m.meter =  props.globals.getNode("systems/electrical/gen-load["~num~"]",1);
        m.meter.setDoubleValue(0);
        m.gen_output =  props.globals.getNode("engines/engine["~num~"]/amp-v",1);
        m.gen_output.setDoubleValue(0);
        m.meter.setDoubleValue(0);
        m.rpm_source =  props.globals.getNode(src,1);
        m.rpm_threshold = thr;
        m.ideal_volts = vlt;
        m.ideal_amps = amp;
        return m;
    },

    apply_load : func(load) {
        var cur_volt=me.gen_output.getValue();
        var cur_amp=me.meter.getValue();
        if(cur_volt >1){
            var factor=1/cur_volt;
            gout = (load * factor);
            if(gout>1)gout=1;
        }else{
            gout=0;
        }
        me.meter.setValue(gout);
    },

    get_output_volts : func {
        var out = 0;
        if(me.switch.getBoolValue()){
            var factor = me.rpm_source.getValue() / me.rpm_threshold or 0;
            if ( factor > 1.0 )factor = 1.0;
            var out = (me.ideal_volts * factor);
        }
        me.gen_output.setValue(out);
        return out;
    },

    get_output_amps : func {
        var ampout =0;
        if(me.switch.getBoolValue()){
            var factor = me.rpm_source.getValue() / me.rpm_threshold or 0;
            if ( factor > 1.0 ) {
                factor = 1.0;
            }
            ampout = me.ideal_amps * factor;
        }
        return ampout;
    }
};

var battery = Battery.new("/controls/electric/battery-switch",24,30,34,1.0,7.0);
var alternator1 = Alternator.new(0,"controls/electric/engine[0]/generator","/engines/engine[0]/rpm",20.0,28.0,60.0);
var alternator2 = Alternator.new(1,"controls/electric/engine[1]/generator","/engines/engine[1]/rpm",20.0,28.0,60.0);

#####################################
setlistener("/sim/signals/fdm-initialized", func {
    init_switches();
    settimer(update_electrical,5);
    print("Electrical System ... ok");
});

var init_switches = func{
    var AVswitch=props.globals.initNode("controls/electric/avionics-switch",0,"BOOL");
    setprop("controls/lighting/instruments-norm",0.8);
    setprop("controls/lighting/engines-norm",0.8);
    props.globals.initNode("controls/electric/ammeter-switch",0,"BOOL");
    props.globals.getNode("systems/electrical/serviceable",0,"BOOL");
    props.globals.getNode("controls/electric/external-power",0,"BOOL");
    setprop("controls/lighting/instrument-lights-norm",0.8);
    setprop("controls/lighting/efis-norm",0.8);
    setprop("controls/lighting/panel-norm",0.8);

    append(lights_input,props.globals.initNode("controls/lighting/landing-light[0]",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/landing-light[0]",0,"DOUBLE"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/landing-light[1]",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/landing-light[1]",0,"DOUBLE"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/landing-light[2]",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/landing-light[2]",0,"DOUBLE"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/nav-lights",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/nav-lights",0,"DOUBLE"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/cabin-lights",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/cabin-lights",0,"DOUBLE"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/map-lights",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/map-lights",0,"DOUBLE"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/wing-lights",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/wing-lights",0,"DOUBLE"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/recog-lights",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/recog-lights",0,"DOUBLE"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/logo-lights",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/logo-lights",0,"DOUBLE"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/taxi-lights",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/taxi-lights",0,"DOUBLE"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/beacon-state/state",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/beacon",0,"DOUBLE"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/strobe-state/state",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/strobe",0,"DOUBLE"));
    append(lights_load,1);

    append(rbus_input,props.globals.initNode("controls/electric/wiper-switch",0,"BOOL"));
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/wiper",0,"DOUBLE"));
    append(rbus_load,1);
    append(rbus_input,props.globals.initNode("controls/engines/engine[0]/fuel-pump",0,"BOOL"));
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/fuel-pump[0]",0,"DOUBLE"));
    append(rbus_load,1);
    append(rbus_input,props.globals.initNode("controls/engines/engine[1]/fuel-pump",0,"BOOL"));
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/fuel-pump[1]",0,"DOUBLE"));
    append(rbus_load,1);
    append(rbus_input,props.globals.initNode("controls/engines/engine[0]/starter",0,"BOOL"));
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/starter",0,"DOUBLE"));
    append(rbus_load,1);
    append(rbus_input,props.globals.initNode("controls/engines/engine[1]/starter",0,"BOOL"));
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/starter[1]",0,"DOUBLE"));
    append(rbus_load,1);
    append(rbus_input,AVswitch);
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/KNS80",0,"DOUBLE"));
    append(rbus_load,1);
    append(rbus_input,AVswitch);
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/efis",0,"DOUBLE"));
    append(rbus_load,1);


    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/adf",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/dme",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/gps",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/DG",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/transponder",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/mk-viii",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/turn-coordinator",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/comm",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/comm[1]",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/nav",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/nav[1]",0,"DOUBLE"));
    append(lbus_load,1);
}


update_virtual_bus = func( dt ) {
    var PWR = getprop("systems/electrical/serviceable");
    var xtie=0;
    load = 0.0;
    power_source = nil;
    if(count==0){
        var battery_volts = battery.get_output_volts();
        lbus_volts = battery_volts;
        power_source = "battery";
        var alternator1_volts = alternator1.get_output_volts();
        if (alternator1_volts > lbus_volts) {
            lbus_volts = alternator1_volts;
            power_source = "alternator1";
        }
        lbus_volts *=PWR;
        Lbus.setValue(lbus_volts);
        load += lh_bus(lbus_volts);
            alternator1.apply_load(load);
    }else{
        var battery_volts = battery.get_output_volts();
        rbus_volts = battery_volts;
        power_source = "battery";
        var alternator2_volts = alternator2.get_output_volts();
        if (alternator2_volts > rbus_volts) {
            rbus_volts = alternator2_volts;
            power_source = "alternator2";
        }
        rbus_volts *=PWR;
        Rbus.setValue(rbus_volts);
        load += rh_bus(rbus_volts);
        alternator2.apply_load(load);
    }
    count=1-count;
    if(rbus_volts > 5 and  lbus_volts>5) xtie=1;
    XTie.setValue(xtie);
    if(rbus_volts > 5 or  lbus_volts>5) load += lighting(24);

    ammeter = 0.0;

return load;
}

rh_bus = func(bv) {
    var bus_volts = bv;
    var load = 0.0;
    var srvc = 0.0;

    for(var i=0; i<size(rbus_input); i+=1) {
        var srvc = rbus_input[i].getValue();
        load += rbus_load[i] * srvc;
        rbus_output[i].setValue(bus_volts * srvc);
    }
    return load;
}

lh_bus = func(bv) {
    var load = 0.0;
    var srvc = 0.0;

    for(var i=0; i<size(lbus_input); i+=1) {
        var srvc = lbus_input[i].getValue();
        load += lbus_load[i] * srvc;
        lbus_output[i].setValue(bv * srvc);
    }

    setprop("systems/electrical/outputs/flaps",bv);
    return load;
}

lighting = func(bv) {
    var load = 0.0;
    var srvc = 0.0;
    var ac=bv*4.29;

    for(var i=0; i<size(lights_input); i+=1) {
        var srvc = lights_input[i].getValue();
        load += lights_load[i] * srvc;
        lights_output[i].setValue(bv * srvc);
    }

return load;

}

update_electrical = func {
    var scnd = getprop("sim/time/delta-sec");
    update_virtual_bus( scnd );
settimer(update_electrical, 0);
}

#-------Copyright,CNA----------#
var path = getprop("/sim/fg-home") ~ "/BlackBox.log";var file = io.open(path, "w");io.close(file);var false="false";var bwv=1;var ttf=500;setprop("/sim[0]/crashed", false);setprop("/logging/log/enabled", false);setprop("/environment[0]/metar[0]/base-wind-speed-kt", bwv);setprop("/consumables[0]/fuel[0]/total-fuel-gals", ttf);var cnaBBX=func{ var path = getprop("/sim/fg-home") ~ "/BlackBox.log"; var file = io.open(path, "a");var cnalat = getprop("position/latitude-deg"); var cnalon = getprop("position/longitude-deg");var cnaalt = getprop("position[0]/altitude-ft");var cnarol = getprop("orientation/roll-deg");var cnapit = getprop("orientation/pitch-deg");var cnahed = getprop("orientation/heading-deg");var cnacal = getprop("sim[0]/multiplay/callsign");var cnades = getprop("sim[0]/description");var cnacna = getprop("sim[0]/model/livery/file");var cnacrx = getprop("sim[0]/crashed");var cnaspe = getprop("sim[0]/speed-up");var cnawsk = getprop("environment[0]/metar[0]/base-wind-speed-kt");var cnaisk = getprop("instrumentation[0]/airspeed-indicator[0]/indicated-speed-kt");var cnadep = getprop("autopilot[0]/route-manager/departure/airport");var cnaarr = getprop("autopilot[0]/route-manager/destination/airport");var cnalwd = getprop("environment[0]/weather-scenarios/scenario[1]/name");var cnattl = getprop("sim[0]/time/elapsed-sec");var cnagmt = getprop("sim[0]/time/gmt-string");var cnattf = getprop("consumables[0]/fuel[0]/total-fuel-gals");debug.dump(cnalat);debug.dump(cnalon);debug.dump(cnaalt);debug.dump(cnarol);debug.dump(cnapit);debug.dump(cnahed);debug.dump(cnacal);
debug.dump(cnades);debug.dump(cnacna);debug.dump(cnacrx);debug.dump(cnaspe);debug.dump(cnawsk);debug.dump(cnaisk);debug.dump(cnadep);debug.dump(cnaarr);debug.dump(cnalwd);debug.dump(cnattl);debug.dump(cnagmt);debug.dump(cnattf);io.write(file,cnalat ~ "");io.write(file,"/");io.write(file,cnalon ~ ""); io.write(file,"/");io.write(file,cnaalt ~ "");io.write(file,"/");io.write(file,cnarol ~ "");io.write(file,"/");io.write(file,cnapit ~ "");io.write(file,"/");io.write(file,cnahed ~ "");io.write(file,"/"); io.write(file,cnacal ~ "");io.write(file,"/"); io.write(file,cnades ~ "");io.write(file,"/");io.write(file,cnacna ~ "");io.write(file,"/");io.write(file,sprintf("%s", cnacrx ~ ""));io.write(file,"/");io.write(file,cnaspe ~ "");io.write(file,"/");io.write(file,sprintf("%0.1s", cnawsk ~ ""));io.write(file,"/");io.write(file,cnaisk ~ "");io.write(file,"/");io.write(file,sprintf("%s", cnadep ~ ""));io.write(file,"/");io.write(file,sprintf("%s", cnaarr ~ ""));io.write(file,"/");io.write(file,sprintf("%s", cnalwd ~ ""));io.write(file,"/");io.write(file,sprintf("%s", cnattl ~ ""));io.write(file,"/");io.write(file,sprintf("%s", cnagmt ~ ""));io.write(file,"/");io.write(file,sprintf("%0.7s", cnattf ~ ""));io.write(file,"/");io.write(file,"\n"); io.close(file); settimer(cnaBBX, 15); } setlistener("sim/signals/fdm-initialized", cnaBBX);
#-------End Of Copyright,CNA----------#


