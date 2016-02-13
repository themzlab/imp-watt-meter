resetallkwh <- false;

// Personal, domain, keys, hosted files ----------------------------------{


mydomain <- "yourwebsite.com";//url of service where the UI page is hosted

_accessorigin <-"http://" + mydomain;//"*";

_PHPLogScript <- "http://" + mydomain + "/log_";// + impeeid + .php

referers <- ["http://" + mydomain + "/wattmeters/mod4.html", 
             "http://www." + mydomain + "/wattmeters/mod4.html" ,
             "http://" + mydomain + "/wattmeters/mod5.html" ,
             "http://www." + mydomain + "/wattmeters/mod5.html" ,
             http.agenturl(),
             ""];
             
//}


//CALIBRATION DATA -------------------------------------------------------{

//All calibration constants are saved here, in the agent and distributed by code

//Offsets are sent to the ADE chip after the device requests them from the agent
//Gains are left external - for the agent to perform

//1st pick the correct PGA and check that the signals are the correct magnitude
//Use chosen PGA, 1.0 software gain and 0 ADE offset and perform the following

//Use a low-voltage source and normal line voltage (either order) to obtain
// Counts, versus RMS Volts for two levels.  Use spreadsheet
//to determine the offset and gain; the spreadsheet iterates to solve

//Use a load of .050 A to 0.100 A as the LOW and  10 to 15A as the high
// use the spreadsheet to determine gain (sofware) and offset (ADE )

//The above offsets will affect the Watt and VA outputs
//Repeat the above tests with low current and with high current and find
// VA with low watt load and VA with high watt load and determine gain and offset
//The ADE readings can be used for Voltage and Current - to calculate the VA
// (calibrate its VA out to its own V and A readings).  I agree it is strange this
//should be required but maybe the way the blocks work inside the chip - requires
//this external manipulation



//later the calibration tables could be placed elsewhere, preferrably an
//external database

CAL_WATT3 <- {};


CAL_WATT3["20000c2a69999999"] <- { // imp 5.0-C

    //_ means that the constant is applied programmatically rather than set into the ADE meter.   
    //RMS offsets are expected^2 - actual^2 / 2^12
    PGA_I = "\x3"       //.002=\x1,.001=\x2,0.0005=\x3
    ,_VOLTSCALE = 19210.9 //might need to (did) increase it
    ,VRMSOS = -390     //
    
    ,AIRMSOS = -2725  // try to calibrated with 10K load and formula on page 8
    ,_CURRENTSCALE = 105517.2  //
    
    ,AWATTOS = 189    //Calibrated with small load AFTER having calibrated the current and voltage
    ,AVAOS = 189 //copy of the Watt offset - if they are the same, same PF?


    ,_VASCALE = 120.811
   
   
    ,_WATTSFROMENERGY = 193.6
    
    ,previous_time = 0
    
    ,Energy = 0
    
    ,reference = {
             boot = 0
            ,day = 0
            ,week = 0
            ,manual = 0
        
        }
    
    };//imp 5.0-C



CAL_NOM <- { //from calibration of the device - 
    
    //_ means that the constant is applied programmatically rather than set into the ADE meter.   
    //RMS offsets are expected^2 - actual^2 / 2^12
    PGA_I = "\x1"       //.002=\x1,.001=\x2,0.0005=\x3
    ,_VOLTSCALE = 1.0 //might need to (did) increase it
    ,VRMSOS = 0000     //
    
    ,AIRMSOS = 0000     // try to calibrated with 10K load and formula on page 8
    ,_CURRENTSCALE = 1.0
    
    ,AWATTOS = 0//32000 //Calibrated with small load AFTER having calibrated the current and voltage
    ,AVAOS = 0//32000  //copy of the Watt offset - if they are the same, same PF?


    ,_VASCALE = 1.0
   
   
    ,_WATTSFROMENERGY = 1.0
    
    ,previous_time = 0
    
    ,Energy = 0
    
    ,reference = {
             boot = 0
            ,day = 0
            ,week = 0
            ,manual = 0
        
        }
    };//Non-calibrated units start out like this
 


//END CALIBRATION DATA _________________________________________________________
//}


//---------------------------------------------------------------------------
//ABOVE HERE KEEP YOUR PERSONAL STUFF - DOWN BELOW REMOVE YOUR PERSONAL STUFF 
//---------------------------------------------------------------------------


//CREDITS
//beardedinventor, electricimp for http non-blocking messaging code
//Peter, electricimp for fast device code to get waveforms and trends

//agent will respond to the following external events
//  request_cals        device starts up and needs calibration data
//  logbyagent          device sends data to log
//  trend               array of points, sent from device
//  wave                array of points, sent from device
//  ack                 acknowledging that a button press was received
//  http.onrequest      from web page or external ??


//VARIABLE DEFINITIONS __________________________________________________ {

//server.save(CAL_WATT3["20000c2a99999999"]);//This is a temporary line to bring up new devices

CAL <- server.load();//a virgin device will not have anything here but 

impeeid <- ""; 
LifetimeEnergyCount <- 0;
const JouleTokWhr = 0.000277777778;

if (("Energy" in CAL)){
        //NEW Oct 11 to hopefully preserve kwh during imp server cycles
        LifetimeEnergyCount = CAL["Energy"];
}


LoggingON <- 1;

responsejson <- {};

meterdata <- { V = 0.0,
         I = 0.0,
         Ipeak = 0,
         Vpeak = 0,
         PF = 0,
         W = 0,
         VA = 0,
         KWH = 0,
         KWHtoday = 0,
         KWHweek = 0,
         KWHboot = 0,
         unixtime = 0,
         GMT = ""
}

_BROWSER<-"";//not used?

_cachedResponse <-"";

_cachedButtonResponse <-"";

HttpResponses <- {};

extramessage <- "";


nexttwiliotime <- time() + 30;//add 20 seconds just...

previousW <- 0;

//end Variable defs

//}


//CALIBRATION FUNCTIONS _________________________________________________ {

function Vcal (iv){
    
    //Displays smoothed VRMS counts
    filteredvalue.update(iv.rawdata.Vcount);
     
}

function Ical (iv){
    
    //Displays smoothed IRMS counts
    filteredvalue.update(iv.rawdata.Icount);
     
}

function Wcal(iv){
    
    //Displays smoothed Apparent energy, Active energy (Watts) and VRMS*IRMS
    
    server.log(":");
    filteredvalue.update(iv.rawdata.VAcount);
    
    filteredvalue2.update(iv.rawdata.Wcount);
    
    filteredvalue3.update((1.0* iv.rawdata.Vcount/CAL._VOLTSCALE)*(1.0* iv.rawdata.Icount/CAL._CURRENTSCALE) );
    
    
}

function Ecal(iv){
        
    //Displays a filtered value of the scale factor that should be entered
    //to the calibratoin table directly - _WATTSFROMENERGY 
    local wattsbyenergyscalar = ((1.0 * (1.0 * iv.rawdata.VAcount  / CAL._VASCALE))/(1.0 * iv.rawdata.AEcount/iv.rawdata.deltaT));
    
    
    if (wattsbyenergyscalar>0 && wattsbyenergyscalar<2000){
        filteredvalue.update(wattsbyenergyscalar);
    }
        
}

//}


device.on("request_cals",function(iv){
    
    //this code will run when the device powers up in order to
    //pass calibration values to the device.  The agent holds them in persistent storage
    server.log("address     is   " + iv.address);
    
    impeeid= iv.address;
    
    server.log("cals requested; " + impeeid);
   
   
        local preserveEnergyValue = CAL.Energy;
        local preserveTimeValue = CAL.previous_time;
        local preserveReferences = CAL.reference;
        server.log(preserveTimeValue + " saved time value");
        server.log(preserveEnergyValue + " saved energy value");
   
   
    CAL =  CAL_WATT3[iv.address];
    
    
    //Send the calibrations chosen back to the device
    
    device.send("cals_sent",CAL);
    
    
        CAL.Energy = preserveEnergyValue;
        CAL.previous_time =  preserveTimeValue; 
        CAL.reference =  preserveReferences;
        CAL.reference.boot = preserveEnergyValue;
        LifetimeEnergyCount = CAL.Energy;
        
        
        if (resetallkwh==true){
            CAL.reference.boot=0;
            CAL.reference.day=0;
            CAL.reference.manual=0;
            CAL.reference.week=0;
            CAL.Energy=0;
            CAL.previous_time = time()-21600;//Standard time, Chicago compared to Standard time
        }
        
        server.save(CAL);//new CALS will be saved every time the device boots
    
    //Each device has its own f script, add it to the stub created above
    //_PHPLogScript = _PHPLogScript + impeeid + ".php";
    //server.log(_PHPLogScript);
    
    
    //if (!("Energy" in CAL)){
        
    //    CAL["Energy"]<- 0; 
        
    //}
    
    server.save(CAL);//new CALS will be saved every time the device boots
    
    
    // Determine if the device is in any calibration stage or already calibrated
    
    
    if (CAL._VOLTSCALE==1.0){
        //you are at stage 1
        server.log("CAL Step 1: VRMS - perform a high load and lowest load, use spreadsheet to find gain and offset");
        logfun = Vcal;
        ::filteredvalue <- CALfilter (0 ,2,"VRMS");//N=2 at 5 second period ~ matches 40 smooth
    }
    
    else if (CAL._CURRENTSCALE==1.0)
    {
        //volts were calibrated, but not current 2
        server.log("CAL Step 2: IRMS - perform a high load and lowest load, use spreadsheet to find gain and offset");
        logfun = Ical;
        ::filteredvalue <- CALfilter (0 ,2,"IRMS");
    }
    
    else if (CAL._VASCALE==1.0)
    {
        //Current was calibrated, but not VA 3
        server.log("CAL step 3: VA and Watts  - perform a high load and lowest load, use spreadsheet to find gain and offset");
        logfun = Wcal;
        
        ::filteredvalue <- CALfilter (0 ,2,"VA");
        ::filteredvalue2 <- CALfilter (0 ,2," W");
        ::filteredvalue3 <- CALfilter (0 ,2,"V*I");
        
    }
    
    else if (CAL._WATTSFROMENERGY ==1.0){
        
        server.log("CAL step 4: Energy ");
        
        //everything has been calibrated, except this 4
        
        logfun = Ecal;
        ::filteredvalue <- CALfilter (0 ,8,"AE");
        
    }
    

   
});


//buttonmessage = { button: "name of button", time: 0 , type: "measurement"}


// Utility functions ______________________________________________________{

function agentlog(message){
    if (LoggingON==1){
      server.log(message);
    }
}


function sign(val){
  if (math.abs(val)==val)
  {
    return 1;
  }
  else
  {
    return -1;
  }
}

function _round(val, decimalPoints) {
    
    local f = math.pow(10, decimalPoints) * 1.0;
    local newVal = val * f;
    newVal = math.floor(newVal + 0.5)
    newVal = (newVal * 1.0) / f;
 
   return newVal;
}


function iso8601 (){
  
  local d = date();
  
  return format("%02d-%02d-%02dT%02d:%02d:%02d",d.year,d.month+1,d.day,d.hour,d.min,d.sec);
  
}



// end utility functions
//}


function regularlog(iv){
  
    /*rawdata contains:
        Vcount
        Icount
        Vpeakcount
        Ipeakcount
        Wcount
        VAcount
        AEcount
        REcount
        ActiveEnergy
        deltaT
        unixtime
        PF
    */
    
    local presenttime = time()-21600;//Standard time, Chicago compared to Standard time
    
    local rawdata = iv.rawdata
    
    if (rawdata.Icount < 2000){
        //no load detection - over ride values sent from device
        rawdata.Icount=0;
        rawdata.Ipeakcount=0;
        rawdata.Wcount=0;
        rawdata.AEcount=0;
        rawdata.REcount=0;
        rawdata.ActiveEnergy=0;
    }
    
    meterdata.GMT = iso8601();
    
    meterdata.V = (1.0* rawdata.Vcount/CAL._VOLTSCALE);
    meterdata.I = (1.0* rawdata.Icount/CAL._CURRENTSCALE);
    
    //Calculate power by energy accumulation registers and elapsed time
    
    local We = rawdata.ActiveEnergy * CAL._WATTSFROMENERGY / (rawdata.deltaT) ;
    local VAe = rawdata.AEcount * CAL._WATTSFROMENERGY / (rawdata.deltaT) ; 
    
    //or do W and VA by instant values
  
    local Wi = 1.0 * rawdata.Wcount  / CAL._VASCALE;
    local VAi = 1.0 * rawdata.VAcount  / CAL._VASCALE;
  
 
    meterdata.PF=1.0*(rawdata.PF)/32767.0;//power factor
    meterdata.Ipeak = 2.0 * rawdata.Ipeakcount/CAL._CURRENTSCALE;
    meterdata.Vpeak = (2.0 * rawdata.Vpeakcount/CAL._VOLTSCALE);
    
    local pfe =   ((1.0 * rawdata.ActiveEnergy)/(rawdata.AEcount+1))*(sign(rawdata.REcount));
    
    if (rawdata.ActiveEnergy>0){
        //do not bother with any of this if there is no energy accumulated
        LifetimeEnergyCount += rawdata.ActiveEnergy; //ActiveEnergy
        
        CAL["Energy"]=LifetimeEnergyCount;
        
    }
    
    local presentdate = date(presenttime);
    local previousdate = date(CAL.previous_time);
    
    CAL.previous_time = presenttime;
    
    
    
    if (!(presentdate.day==previousdate.day)){
        //new day
        //6 = Saturday
        //0 = Sunday
        CAL.reference.day = LifetimeEnergyCount;
        server.log("new day");
        if ((presentdate.wday-previousdate.wday)<0){
            //new week, occurs overnight, Saturday
            CAL.reference.week = LifetimeEnergyCount;
            server.log("new week");
        }
        
    }

    server.save(CAL);
    
    
    
    //server.log(CAL._WATTSFROMENERGY + "," + JouleTokWhr + "," + LifetimeEnergyCount);
    
    local KWHscale = (CAL._WATTSFROMENERGY * JouleTokWhr / 1000000);
    
    meterdata.KWH = KWHscale * LifetimeEnergyCount ;
    meterdata.KWHboot = KWHscale * (LifetimeEnergyCount-CAL.reference.boot);
    meterdata.KWHtoday = KWHscale * (LifetimeEnergyCount-CAL.reference.day);
    meterdata.KWHweek = KWHscale * (LifetimeEnergyCount-CAL.reference.week);
    

    
    local agentlogmessage = "";
    
    
    //has been calibrated, calculate by energy - improves accuracy
    meterdata.W =  We;
    meterdata.VA = VAe;
    

    agentlogmessage = (agentlogmessage + 
    

        format("%6.2f,V", (meterdata.V)) + " , " +
        
        format("%6.3f,A", meterdata.I) + " , " + 
        
        format("%6.2f, We", (meterdata.W)) +" , " + 
        //format("%6.2f,Wi", Wi) +" , " + 
        rawdata.Wcount + " , " +
        format("%6.2f,VAi", VAi) +" , " + 
        //(rawdata.VAcount) + " ,VAc, " + 
        //Watt energy
        //format("%6.0f,WE", (rawdata.ActiveEnergy)) +" , " +
        
        //Apparant energy
        //format("%6.0f,AE", (rawdata.AEcount)) +" , " + 
        
        //format("%6.0f,RE", (rawdata.REcount)) +" , " + 
        //format("%6.3f,Pi", (meterdata.PF)) +" , " + 
        //format("%6.3f,Pe", pfe) + "," + 
        
        
        //format ("%6.2f ,VAi", VAi) + " , " +
        ""
    );
  
  
  //Sometimes extra things have been added that we want in the planner log
  //tack them to the end
  if ("infoLog" in iv){
      
      foreach (g in iv.infoLog){
          agentlogmessage += ( g.time + " , " + g.note + ",");
      }
  }
  
  agentlogmessage += extramessage;
  
  if (CAL._WATTSFROMENERGY!=1.0){
        
        agentlog(agentlogmessage);
        
  }
  
  extramessage="";
  
  //local iv = {};
  
  if (!("meterdata" in iv)){
    iv["meterdata"] <- meterdata;
  }
  {
      iv.meterdata = meterdata;
  }
  
    
    //error can be thrown here if maxX does not exist
  
  if ("chart" in iv){
      
      iv["maxX"] <- responsejson.maxX;
      iv["waveIA"] <- responsejson.waveIA;
      iv["waveV"] <- responsejson.waveV;
      
      
      iv["Iavg"] <- responsejson.Iavg;
      iv["maxYI"] <- responsejson.maxYI;
      iv["Vavg"] <- responsejson.Vavg;
      iv["unixtime"] <- responsejson.unixtime;
      
    } 

    CAL["Energy"]=rawdata.AEcount + CAL.Energy;//Important!
        
   
    server.save(CAL);
    

  if (meterdata.W > (1.0)){
    
    
    sendToHostGator(iv);//if temporarily commented out, don't send to my own web hosting via php
  }
    
  

  
   foreach(k , resp in HttpResponses){
    
    try
    {
        resp.r.send(200,http.jsonencode(iv));
        
        delete HttpResponses[k]; //now that it is sent, delete it
        
    } catch(error){
      
        agentlog("error in sending response ");
        
    }
  }
  



  if (meterdata.W <10.0 && (previousW > 15.0) ){
    
    if (time() > nexttwiliotime){
      //12623542682
      //twilio.send("12624909161", ("3D Print is done "), function(resp) { server.log(resp.statuscode + " - " + resp.body); });      
      twilio.send(numberToSendTo, ("3D Print is done "), function(resp) { server.log(resp.statuscode + " - " + resp.body); });
      agentlog("twilio sent to " + numberToSendTo);
      
      nexttwiliotime = time() + 300;//make sure requests are 5 minutes apart
    
    }
    
  }
  
  previousW = meterdata.W
    
  //server.log("done function regularlog");
}//Calc&report to all browsers that requested


logfun <- regularlog;


device.on("logbyagent",function (iv) {logfun(iv);});


device.on("trend",function(iv){
 
 
    // now get the data ready for output
    //extract from blob, scaled and inserted to ARRAY for JSON for Highcharts
    
    local IAblob = iv.IAblob;
    local Vblob = iv.Vblob;
    local tblob = iv.tblob;
    
    local start = iv.start;
  
  
    // now get the data ready for output
    //extract from blob, scaled and inserted to ARRAY for JSON for Highcharts
    
    local Ntrend = tblob.len()/4;

    local Iwave = array(Ntrend);
    
    local Vwave = array(Ntrend);
    
    
    //This seems to be a necessary part of creating a new array with zeros
    for(local a=0;a<Ntrend;a+=1){
        Vwave[a] = [0,0];// 
        Iwave[a] = [0,0];//
    }
    
   
    local _VRMS = (1.00/CAL._VOLTSCALE);///_VRMS;
    
    //scale the current UP to fit the volt scale (have to interpret)
    //local _IRMS = (1.00) /(CAL._CURRENTSCALE);//_IRMS - removed .03 multiplier on July 13 2014
    local _IRMS = (1.00) / (CAL._VASCALE);
    //local _IRMS = (1.00) / (CAL._CURRENTSCALE);
    
    //set the blob points to the beginning
    Vblob.seek(0,'b');
    tblob.seek(0,'b');
    IAblob.seek(0,'b');
    
    local mask = (1<<24);//for converting to signed numbers
    
    local Isum = 0;
    local Vsum = 0;
  
    for(local a=0;a<Ntrend;a+=1){
  
        //build the blob back into signed integers
        local _V= (Vblob.readn('b')<<16);
        _V = _V | (Vblob.readn('b')<<8);
        _V = _V | (Vblob.readn('b'));
    
        if (_V > (mask>>1)) {
            _V=_V - mask;
        }
        
        local IA= (IAblob.readn('b')<<16);
        IA = IA | (IAblob.readn('b')<<8);
        IA = IA| (IAblob.readn('b'));
        
        if (IA > (mask>>1)) {
            IA=IA-mask;
        }
        
        local tm= tblob.readn('b');
        tm = tm | (tblob.readn('b')<<8);
        tm = tm| (tblob.readn('b')<<16);
        tm = tm| (tblob.readn('b')<<24);

        //Format the data so that Highcharts will get the JSON Array it needs
        //and apply the scaling
      
        Vwave[a][1] = (_VRMS * _V);
        Iwave[a][1] = (_IRMS * IA);
        Vwave[a][0] = 0.001*  (tm-start);
        Iwave[a][0] = 0.001*  (tm-start+590);//nominal is 423 but 590 might also be correct...
        
        Isum += Iwave[a][1]
        Vsum += Vwave[a][1]
    
    }
  
    Isum =1.0 * Isum/Ntrend;
    Vsum =1.0 * Vsum/ Ntrend;
    
    responsejson = {};
    
    responsejson["maxYI"] <- 20;//_round((meterdata.Ipeak/5.0)+0.5, 0)*5.0;//
  
    responsejson["waveIA"] <- Iwave;
    responsejson["waveV"] <- Vwave;
    responsejson["maxX"] <- 9000;
    server.log(Isum);
    server.log(Vsum);
    
    responsejson["Iavg"] <- Isum;
    responsejson["Vavg"] <- Vsum;
     
    responsejson["unixtime"] <- iv.unixtime;
    
    extramessage += ("JSON trend,");

});//trend is RMS values over perhaps a couple seconds


device.on("wave",function(iv){
   
   //meterdata.Ipeak = 2.0 * iv.Ipeakcount/CAL._CURRENTSCALE;
   
   
  // now get the data ready for output
  //extract from blob, scaled and inserted to ARRAY in JSON for Highcharts
  local ICOUNTA = iv.ICOUNTA;
  local VCOUNT = iv.VCOUNT;
  local IAblob = iv.IAblob;
  local Vblob = iv.Vblob;
  local PF =  ((1.0*iv.PFi)/32767);//power factor conversion, refer to datasheet
  
  
  if (PF == 0) {PF=1;}
    
    if (PF<0){PF *= -1.0;}//absolute value
  local n = Vblob.len()/3;
  
  local deltaT = 1.0 * iv.span / (1000.0 * (n-1));// increments of time
  local phase = deltaT/2.0;
  

  local Iwave = array(n);
  local Vwave = array(n);

  
  //This seems to be a necessary part of creating a new array with zeros
  for(local a=0;a<n;a+=1){
     Vwave[a] = [0,0];// 
  }
  
  
  for(local a=0;a<n;a+=1){
    Iwave[a] = [0,0];//
  }
 

  //scale the waveform so 100 is the peak of a pure sine wave
  //with waveforms different than 'sine' the peak will be other than +100/-100
  
  
  //local normalize_V = 141.42/VCOUNT;
  local normalize_V = 2.00/CAL._VOLTSCALE;
  
  //local normalize_I = (141.42/ICOUNTA)/(PF);
  local normalize_I = (2.00/CAL._CURRENTSCALE);
  
  //for power factor other than 1.0, the current waveform will grow in Pk to Pk
  //For crest factor greater than 1.41 the waveform grows in Pk to Pk
  
  
  //set the blob points to the beginning
  
  local mask = (1<<24);//for converting to signed numbers

  
  Vblob.seek(0,'b');
  IAblob.seek(0,'b');
  
  
  local x = 0.0;
  local Vlast = 0;
  for(local a=0;a<n;a+=1){
  
    //build the blob back into signed integers
    local _V= (Vblob.readn('b')<<16);
     _V = _V | (Vblob.readn('b')<<8);
    _V = _V | (Vblob.readn('b'));
    
    if (_V > (mask>>1)) {
      _V=_V - mask;
    }
 
    local IA= (IAblob.readn('b')<<16);
    IA = IA | (IAblob.readn('b')<<8);
    IA = IA| (IAblob.readn('b'));
    
    if (IA > (mask>>1)) {
      IA=IA-mask;
    }
    
 
    //Format the data so that Highcharts will get the JSON Array it needs
    //and apply the scaling
   
   
    Vwave[a][1] = (normalize_V * _V);
    
    Iwave[a][1] = (normalize_I * IA);
    //Iwave[a][1] =  IA;
    
    
    
    if (true){
        Vwave[a][0] = x;
        Iwave[a][0] = x + phase;//0.001*  (tm-start+590);//nominal is 423 but 590 might also be correct...
        x = x + deltaT;
    }
   else{
       local tm= tblob.readn('b');
        tm = tm | (tblob.readn('b')<<8);
        tm = tm| (tblob.readn('b')<<16);
        tm = tm| (tblob.readn('b')<<24);
        Vwave[a][0] = 0.001*  (tm-start);
        Iwave[a][0] = 0.001*  (tm-start+590);//nominal is 423 but 590 might also be correct...
   }
  
  
  }
  
  
  
  
  //HERE, go through the voltage waveform from the middle data point and fan out
  //left and right until you find zero-crossing
  local mm = (n >>1);//integer divide by 2
  local offset = 0.001;
  
  for(local a=mm;a<n;a+=1){
      
      if (Vwave[a-2][1] <0 && Vwave[a][1]>0){
          
          //Crossing upward
          
          local _mid = (Vwave[a][0] - Vwave[a-2][0]);
          //server.log(Vwave[a-2][0]);//24.9
          //server.log(_mid);//.38
          _mid = _mid/2.0;
          //server.log(_mid);//.19
          _mid = _mid +Vwave[a-2][0];
          //server.log(_mid);//25
          offset = _mid - Vwave[a-1][0];
          
          //server.log(offset);
          break;
          
      }
      
  }
  //server.log(offset);//
  
    for(local a=0;a<n;a+=2){
        //Vwave[a][0] = Vwave[a][0]+offset;
    }
  
  
  
  
  responsejson = {};
  
  if (meterdata.Ipeak<5.0){
    if (meterdata.Ipeak<1.0){
    
      responsejson["maxYI"] <- _round((meterdata.Ipeak/0.20)+0.5, 0)*0.2;//
    }
    else{
      responsejson["maxYI"] <- _round((meterdata.Ipeak/1.0)+0.5, 0)*1.0;//
    }
  }
  else{
    responsejson["maxYI"] <- _round((meterdata.Ipeak/5.0)+0.5, 0)*5.0;//
  }
  
  responsejson["waveIA"] <- Iwave;
  responsejson["waveV"] <- Vwave;
  responsejson["maxX"] <- 35;
  
  
  responsejson["Iavg"] <- 0;//temporary
  responsejson["Vavg"] <- 0;//temporary
  responsejson["unixtime"] <- iso8601 ();//temporary
  
  
  extramessage += ("JSON wave,");
  
    
});//wave is a waveform of DC instantaneous readings




function sendToHostGator(tableforPHPlog) {
  
    /* 
    meterdata
        V 
        I
        Ipeak
        Vpeak
        PF
        W
        VA
        unixtime
        HZ
        GMT
    */
  
    
    // Set Content-Type header to json
    local headers = { "Content-Type": "application/json"};
    
    
    local _body = {V = tableforPHPlog.meterdata.V,
             I = tableforPHPlog.meterdata.I,
             Ipeak = tableforPHPlog.meterdata.Ipeak,
             PF = tableforPHPlog.meterdata.PF,
             W = tableforPHPlog.meterdata.W,
             VA = tableforPHPlog.meterdata.VA,
    }
        
    
    // send data to your web service
    //server.log(http.jsonencode(_body));
   http.post(_PHPLogScript, headers, http.jsonencode(_body)).sendasync(postphpisdone);
    
  
}//done


function postphpisdone(m){
  

  if (m.statuscode == 200) { // "OK"

  }
  else
  {
      //should we do anything if the PHP script does not work?
      agentlog("php error: " + m.statuscode + " ,script is " + _PHPLogScript);
  }
}


//For testing
//http.onrequest(function(req, resp) {server.log("Got response");resp.send(200, "OK");});


//Non-blocking code to respond to browsers, BEARDEDINVENTOR, electric imp { 


// web page code
const html = @"<!DOCTYPE html><html><body >Nothing here</body></html>";

//how long to wait for the imp device
//note, it should normally report in 20 seconds

const TIMEOUT = 150.0;//normally 130, I changed this at maker faire


function CleanResponses() {
    // Send timeout responses when required: By beardedinventor
    // get current time
    local now = time();
   
    // loop through response queue
    foreach(k, resp in HttpResponses) {
        // if request has timed-out
        if ((now - resp.ts) > TIMEOUT) {
            // log it, send the response, then delete it
            agentlog("Req. " + resp.ts + " " + resp.b +  " timed-out: Device no response");
            resp.r.send(408, "Req Timed-out");
            delete HttpResponses[k];
        }
    }
    // check for timeouts every XX seconds
    imp.wakeup(30.0, CleanResponses);
    
} CleanResponses();



function GetResponseKey() {
  //for making a unique timestamp
  return format(format("%d%03d", time(), date().usec));
}




http.onrequest(function(request,res){
    
    
    local thisreferer = "";

     
     if ("referer" in request.headers){
      
    
      thisreferer = request.headers.referer;
      
   
      //remove query strings from this
      
      local _query = thisreferer.find("?",0);
      
      
      if (_query){
        
        thisreferer = thisreferer.slice(0,_query);
        
      }
      
      res.header("Access-Control-Allow-Origin",thisreferer);
      
    }
    else
    {
       res.header("Access-Control-Allow-Origin", _accessorigin);
    }
    
    if ("origin" in request.headers){
        //until I figure out a better way, presence of origin trumps other...
        res.header("Access-Control-Allow-Origin",request.headers.origin);
    }
    
    local validreferer = false;
    foreach (url in referers){
        
        if (url ==thisreferer ){
            validreferer=true;
            break;
        }
    }
    
    
    
    if (validreferer==true){

        local key = GetResponseKey();
      
        //make sure the response is unique
      
        while(key in HttpResponses) {
            key = GetResponseKey();
        }
      
        //The browser? or OS is identified with this index
        //but it is only required for debug purposes

        local pathParts = split(request.path.tolower(),"/");
          
        local numParts = pathParts.len();
      
        if (numParts == 0) {
           
            //show the web page of this agent
            //the lack of othere data in the path
            //indicate a browser has opened the url
            
            res.send(200, html);
          
        } else if (numParts ==1  && pathParts[0] == "api") {
          
          //This is the long-polling request
          
          //any browser opened running the Reflow Oven code
          //will keep an open 'get' request that is addressed
          //to this path
                     
          res.header("Connection", "close");
          res.header("Content-Type","application/json");
          
          HttpResponses[key] <- { ts = time(), r = res, b=_BROWSER };
          
          //agentlog("GET recvd for " + _BROWSER + " at " );
         
      } //all api results with no additional paths
      
      else if(numParts ==2  && pathParts[0] == "api" && pathParts[1] == "new"){
        
            
            extramessage += ",new page";
            
     
            res.header("Content-Type","application/json");    //text/plain       
            ::_cachedResponse = res;
                      
            
            if (true){
                
                //NOTE, sometimes device.isconnected() was returning false negatives
                //I sometimes change to if(true) to avoid errors returned
                
                //Send off a chain of events 
                //send request to imp - when it sends it back
                //that gets passed to the browser to complete
                //a long-polling structure
                
                local iv = {};

                ::_cachedResponse.send(200,http.jsonencode({ "meterdata" : meterdata,"impeeid" : impeeid }));
              
            }
            else
            {

              //Directly respond, no sense asking the imp to give
              //data back because it is not connected
              //99 is a special code to tell the browser 
              ::_cachedResponse.send(200,http.jsonencode({ mode = 99 }));
              
               agentlog("device is NOT connected");
              
            }
            
            //agentlog("load the page for " + request.headers["x-forwarded-for"]);
              
      }
      else if(numParts ==2  && pathParts[0] == "api" && pathParts[1] == "btn"){
        
        
        //This http request has a query
        
        device.send("buttonpress",(request.query));
        
        res.header("Content-Type","text/plain");    //text/plain 
        //immediately respond but
        //there will still be a result triggered back through the 
        //open long-polling request.
        //the difference is it will go to all browsers
        //not just this one
        
        _cachedButtonResponse = res;
        
        //agentlog(",,,,,,,,,,,,,,button request recieved ");
        
      }
      else
      {
        
        //this is an unrecognized request
        res.send(401,"");
        agentlog("401");
        
      }
    }
  
    else{
      
      res.send(401,"");
       agentlog(" unknown source");
      
    }

});

//}


device.on("ack",function(returnvalue){
  //To let the browser know that a user pressed a button and that the
  //button press made it to the device.
  _cachedButtonResponse.send(200,returnvalue);
  
});


class CALfilter {
  
  //Smooths data and is configurable
  //by passing an integer value 
  //determining the time constant of the filter
  
  Sum = null;
  valuef = null;
  N = null;
  previous = null;
  previousf = null;
  name = null;
  
  constructor(_seed, _N, _name){
    
    Sum = _seed * _N;
    N = _N;
    valuef = _seed;
    previous=valuef;
    previousf=valuef;
    name = _name;
    
  }
  
  function refresh(_seed){
    Sum = _seed * N;
    valuef = _seed;
  }
  
  function update(newvalue){
    
    if (Sum==0.0){
        Sum = newvalue * N;
        valuef = Sum/N;
    }
    else
    {
        Sum = Sum + newvalue - valuef;
        valuef = Sum/N;
    }
    
    local change = 100.0 * (newvalue-previous) / previous;
    local changef = 100.0 * (valuef-previousf) / previousf;
    
    if (valuef<10000){
        server.log("CAL " + name + " >>," + format ("%9.2f",valuef) + " , " + format ("%9.3f",changef) + " % changef" + " , " + format ("%9.0f",newvalue) + " , " + format ("%9.3f",change) + " % change")    
    }
    else{
        server.log("CAL " + name + " >>," + valuef + " , " + changef + " % changef" + " , " + newvalue + " , " + change + " % change")
    }
    
    previous = newvalue;
    previousf = valuef;
    return valuef;
    
  }
  
}

//after booting (the agent), get the php log file again
imp.wakeup(20.0,function(){device.send("getid",true);});

//after agent boot, the imp device will send its id and we can put the log script together
device.on("id",function(_id){impeeid=_id;_PHPLogScript = _PHPLogScript + impeeid + ".php";server.log(_PHPLogScript);});



/*
server.log(time());



agentlog(date());

foreach(index,val in date()){
    agentlog(index + " , " + val);
}

agentlog(date().hour);
agentlog(date().day);
agentlog(date().min);
agentlog(date().sec);
agentlog(time());

min
hour
day
year
wday
time
sec
yday
month


newdateitem <- date(time()+86400*395);
agentlog(newdateitem.wday);

foreach(index,val in newdateitem){
    agentlog(index + " , " + val);
}

server.log(math.rand() + "   random " + RAND_MAX);

*/


Week <- {Sun = false,
Mon = false,
Tue = false,
Wed = false,
Thu = false,
Fri = false,
Sat = false,
Dur = 0,
Num = 1

}

server.log( Week.Num);

server.log( Week.Dur);

function processResponse(response) 
{
    
    // This is the completed-request callback function, which logs the
    // incoming response's message and tatus code
    if (response.statuscode != 200){
        server.log("Code: " + response.statuscode );
    }
}


server.log("CAL table");
foreach (i, v in CAL){
    server.log("," + i + " , " + v);
    
}
server.log("CAL.reference  table")
foreach (i, v in CAL.reference){
    server.log("," + i + " , " + v);
    
}











// =========================================================={

                    
const TWILIO_SID = "f5456f4f45fe45fe45t4fe45fte54ft4e5tf5";		// Your Twilio Account SID
const TWILIO_AUTH = "fe5tfetfetertft45ff44fefte4tfestrt";		// Your Twilio Auth Token
const TWILIO_NUM = "15559999";		// Your Twilio Phone Number



class Twilio {
    _baseUrl = "https://api.twilio.com/2010-04-01/Accounts/";
    
    _accountSid = null;
    _authToken = null;
    _phoneNumber = null;
    
    constructor(accountSid, authToken, phoneNumber) {
        _accountSid = accountSid;
        _authToken = authToken;
        _phoneNumber = phoneNumber;
    }
    
    function send(to, message, callback = null) {
        local url = _baseUrl + _accountSid + "/SMS/Messages.json"
        
        local auth = http.base64encode(_accountSid + ":" + _authToken);
        local headers = { "Authorization": "Basic " + auth };
        
        local body = http.urlencode({
            From = _phoneNumber,
            To = to,
            Body = message
        });
        
        local request = http.post(url, headers, body);
        if (callback == null) return request.sendsync();
        else request.sendasync(callback);
    }
    
    function Respond(resp, message) {
        local data = { Response = { Message = message } };
        local body = xmlEncode(data);
        
        resp.header("Content-Type", "text/xml");
        
        
        server.log(body);
        
        resp.send(200, body);
    }
    
    function xmlEncode(data, version="1.0", encoding="UTF-8") {
        return format("<?xml version=\"%s\" encoding=\"%s\" ?>%s", version, encoding, _recursiveEncode(data))
    }

    /******************** Private Function (DO NOT CALL) ********************/
    function _recursiveEncode(data) {
        local s = "";
        foreach(k, v in data) {
            if (typeof(v) == "table" || typeof(v) == "array") {
                s += format("<%s>%s</%s>", k.tostring(), _recursiveEncode(v), k.tostring());
            } 
            else { 
                s += format("<%s>%s</%s>", k.tostring(), v.tostring(), k.tostring());;
            }
        }
        return s
    }
}

twilio <- Twilio(TWILIO_SID, TWILIO_AUTH, TWILIO_NUM);

// sending a message
numberToSendTo <- "18885559999"
//twilio.send(numberToSendTo,( "Agent Booted The Mz Lab ~" + http.agenturl()), function(resp) { server.log(resp.statuscode + " - " + resp.body); });


// processing messages


//}//////






function agentToagent() {
  
    /* 
    meterdata
        V 
        I
        Ipeak
        Vpeak
        PF
        W
        VA
        unixtime
        HZ
        GMT
    */
  
    
    // Set Content-Type header to json
    local headers = { "Content-Type": "application/json"};
    
    
    local _body = {V = tableforPHPlog.meterdata.V,
             I = tableforPHPlog.meterdata.I,
             Ipeak = tableforPHPlog.meterdata.Ipeak,
             PF = tableforPHPlog.meterdata.PF,
             W = tableforPHPlog.meterdata.W,
             VA = tableforPHPlog.meterdata.VA,
    }
        
    
    // send data to your web service
    //server.log(http.jsonencode(_body));
   http.post(_PHPLogScript, headers, http.jsonencode(_body)).sendasync(postphpisdone);
    
  
}//done


 //twilio.send("12625550000", ("I forgot my phone..so did Maya"), function(resp) { server.log(resp.statuscode + " - " + resp.body); });
 
 
