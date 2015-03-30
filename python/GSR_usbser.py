from  datetime import datetime
import numpy as np
import threading
import time
import matplotlib.pyplot as plt
import sys
import serial
import pylab
import math


SERIAL_LINE = 'COM3'
MAX_DURATION = 60 #the maximum duration of a recording (in seconds), only impact on the buffer data not on the datafile
UPDATE_LOOP_BUFFER = 16 #the rate for looping buffer update: once the buffer is full we need to loop the buffer (ring buffer) but this is slow: let's update in looping mode only UPDATE_LOOP_BUFFER receptions

################################################################################
# USBSERDATA class                                                             #
################################################################################

class usbserData :
    def __init__(self):
        """
        Constructor

        """
        self._signals = np.array([])

################
        
    def getChannel(self):
        """
        Out : signals
        """
        dataReturn = self._signals[:,2]
        return dataReturn
    
################################################################################
# USBSER class                                                                 #
################################################################################

class usbser :

################    
    def __init__(self,duration,fs,port = SERIAL_LINE,fileName = "",maxDuration=MAX_DURATION):
        """
        Constructor
        IN:
            duration: duration of data to collect in seconds at each call of getData.
            fs: sampling rate choosen
            port: port of the sensor
            filename: if the filename is defined then the data is saved in a file with that name
            maxDuration: the maximum size of the buffer (the data in the buffer will correspond to the last maxDuration
                         seconds
        """  
        
        # On interdit une frequence d'echantillonnage superieure a 100Hz :
        if fs > 100 :
            print "La frequence d'echantillonnage doit etre inferieure a 100Hz !"
            sys.exit(1)
        else :
            
            self._dataBuffer = usbserData()
            
            # Declaration du port utilise :
            self._port = port
            self._ser = serial.Serial()
            
            # Fichier d'enregistrement si besoin est :
            self._fileName = fileName
            self._file = None
            self._recFile = False 
                    
            # Buffer :        
            self._fs = fs
            
            self._isRunning = False
            
            # Periode d'echantillonnage du capteur :
            self._Period = int(1/(self._fs*10**(-3)))
            if (1/float(self._Period)*10**(3) != self._fs):
                print ("La frequence reellement utilisee est : "+str(1/float(self._Period)*10**(3))+"Hz")
                self._fs  = 1/float(self._Period)*10**(3)
            
            self._maxDuration = maxDuration
            self.setDuration(duration) #Also empties the data buffer and set buffersize variables 
            
            
################        
    def setDuration(self, duration):
        """
        Change the duration of the recording (it empty the buffer)
        IN:
            duration: duration in seconds
        """
        if(duration > self._maxDuration) or (duration == 0):
            print "Usbser : requested duration is higher than the maximum duration, buffer will contain only the last " + str(self._maxDuration) + " seconds"
            self._sizeMaxBuffer = int(self._maxDuration * self._fs)
        else:
            self._sizeMaxBuffer = int(duration * self._fs)
        self._durationRecording = duration
        
        if (self._sizeMaxBuffer <= 1):
            print "Usbser : requested buffer size must be > 1"
            sys.exit(1)
        #Initialize the data buffer with NaNs everywhere     
        self._dataBuffer._signals = np.empty((self._sizeMaxBuffer, 2))
        self._dataBuffer._signals.fill(np.nan)

         #Initialize the data buffer associated variables to empty
        self._nbSamplesBuffer = 0;        
        self.isBufferFull = False; 

################         
    def storeSignals(self, newSigs):
        """
        Store the new acquired signals in the usbser and in the file if needed
        IN:
            newSigs: signals to store in the file and in the usbser
        """
        #Enregistrement :
        if self._recFile :
            self._file.write(str(newSigs)+"\n")
        
        #Add the new signals to the current usbser data
        if(self._nbSamplesBuffer < self._sizeMaxBuffer):
            
            #fill the buffer with the incoming data (replace the NaNs)
            self._dataBuffer._signals[self._nbSamplesBuffer:self._nbSamplesBuffer + 1] = newSigs
            self._nbSamplesBuffer += 1
            
            #Set the full buffer variable if the buffer is full
            if not (self._nbSamplesBuffer < self._sizeMaxBuffer):
                self.loopTmpBuff = np.empty((0, 2))
                self.isBufferFull = True
                 
        else:
            #the maximum number of samples is reached
            #looping buffer to keep the same number of samples
            #the update in looping mode is not done every time but only
            #according to UPDATE_LOOP_BUFFER       
            
            if (self._sizeMaxBuffer < UPDATE_LOOP_BUFFER):
                loop_buffer = int(self._sizeMaxBuffer/2)
            else :
                loop_buffer = UPDATE_LOOP_BUFFER
        
            
            self.isBufferFull = True;
            if(self.loopTmpBuff.shape[0] >= loop_buffer):        
                self._dataBuffer._signals = np.roll(self._dataBuffer._signals, -self.loopTmpBuff.shape[0], axis=0)
                self._dataBuffer._signals[-self.loopTmpBuff.shape[0]: , :] = self.loopTmpBuff
                self.loopTmpBuff = np.empty((0, 2))
            else:
                self.loopTmpBuff = np.vstack((self.loopTmpBuff, newSigs))

################ 
    def hex2float(self,hexa) : 
        """
        Convert hexa to float
        IN:
            signal hexa
        OUT: 
            signal float converted
        """
        DECALAGE = 127
        Sint = int(hexa,16)
        Sbit = bin(Sint)
        bexposant = ""
        sgn = 0
        j = 0
        rajout = ""
        if len(Sbit)<34 :
           while j < 34 - len(Sbit):
               rajout = rajout + '0'
               j+=1
           Sbit = Sbit[0:2] + rajout + Sbit [2:len(Sbit)]
        if Sbit[2] == '1' :
            sgn += (-1)
        elif Sbit[2] == '0' :
            sgn += 1
        i = 3
        while i < 11 :
            bexposant = bexposant + str(Sbit[i])
            i += 1
        exposant = self.bin2int(bexposant)
        
        if exposant - DECALAGE == 0 :
            bmantisse = "0"
            div = 22 
            add = 0
        else:
            bmantisse = "1" 
            div = 23
            add = 1
        
                
        while i < len(Sbit) :
            bmantisse = bmantisse + str(Sbit[i]) 
            i += 1
    
        mantisse = self.bin2int(bmantisse)* 2**(-div)
        val = sgn *(add+abs(math.floor(mantisse)-mantisse)) * 2**(exposant - DECALAGE)
        return val
    
################     
    def bin2int(self,s):
        """
        Convert bin to int
        IN:
            s : binary signal
        OUT:
            bin : integer converted
        """
        bin = sum(int(n)*2**i for i, n in zip(range(len(s)), s[::-1]))
        
        return  bin
 
 ################    
    def connect(self):
        """
        Open the port and start sensor recording
        
        """
        self._ser.setPort(self._port)
        self._ser.setTimeout(5)
        self._ser.open()       

        # Demarrage du capteur :       
        self._ser.write("gstop\n")
        self._ser.write("gstart "+str(self._Period)+"\n")
 
 ################        
    def start(self, recFile=False):
        """
        Start the recording 
        """
          
        self.connect()
        self._recFile = recFile
        
        # Enregistrement si demande :
        if self._recFile:
            self.startSaving()
        self.getData()

################         
    def stop(self):
        """
        Stop the recording 
        """
        self._isRunning = False
        # Arret du capteur :
        self._ser.write("gstop\n")
        # Fermeture du port :
        self._ser.close() 
        # Arret de l'enregistrement :
        self.stopSaving()
        
   ################      
    def getData(self):                 
        """
        This is a blocking function up to the moment the requested duration of signals
        is acquired.
        OUT:
            the data acquired
        """
        Shexa = ""
        tps = ""
        #Initialize the data buffer with NaNs everywhere     
        self._dataBuffer._signals = np.empty((self._sizeMaxBuffer, 2))
        self._dataBuffer._signals.fill(np.nan)
        #Initialize the data buffer associated variables to empty
        self._nbSamplesBuffer = 0;        
        self.isBufferFull = False;
 
        #Set endloop variables
        self._isRunning = True;
        currentDuration = 0;
        
        #Get data as long as the reception is not empty and the buffer not full        
        while (self._isRunning):
            
            # Si les donnees fournies sont celles du GSR :            
            data = self._ser.readline() #read the port
            if data[0]=="g" and data[1]==",":
                
                dataSp = data.split(",") #separation de la ligne envoyee par le capteur en 3 donnees : g, tps et GSR
                tps = int(dataSp[1])*10**(-3) #temps en sec
                Shexa = str(dataSp[2])
                S = self.hex2float(Shexa) # Conversion des donnees
                Sf = [tps,S] 

                #Add the incoming data to the class data + save to file if needed
                self.storeSignals(Sf) 
                
            #Update the duration of the recording
            currentDuration = currentDuration + self._Period * 10**(-3)
                #Stop if the recording duration is bigger or equal to the requested duration
            if (self._durationRecording != 0) and not(currentDuration < self._durationRecording):
                self._isRunning = False
               
        return self._dataBuffer
                        
################ 
    def startSaving(self, fileName=None):
        """
        Ask to start the saving of the acquired data (only done when the start
        function will be called or if already called. Eventually Change the name
        of the fileName. A CALL TO THIS FUNCTION OVERWRITE ANY FILE THAT HAVE THE
        NAME SET FOR RECORDING.
        IN:
            fileName: name and path of the file (string, optional)
        """
        if fileName != None:
            self._fileName = fileName

        #Create the file for saving if needed
        if self._fileName != "" and self._file == None:
            self._file = open(self._fileName, 'wt')
            
        self._recFile = True

################
    def stopSaving(self):
        """
        Stop the file recording
        IN:
            fileName: name and path of the file (string)
        """
        if self._file != None:
            self._file.close()
            self._file = None
 
 ################            
    def getChannel(self,nameChannel=''):
        """
        Get the channel corresponding to time and GSR. Perform cleaning of the
        remaining end NaNs if the buffer is not full

        OUT:
            2D array with each signal in column 
        """
    #Do some clearning of the remaining NaNs if the buffer is not full
        if(not self.isBufferFull):  
            dataReturn = self._dataBuffer._signals
            return dataReturn[:np.isnan(dataReturn).nonzero()[0][0]]
        else:
            dataReturn = self._dataBuffer._signals
            return dataReturn
           
            
#################################################################################
# USBSERTHREAD class                                                            #
#################################################################################           
            
dataLock = threading.Lock(); #lock for file access        
class usbserThread(usbser,threading.Thread):
    
    def __init__(self,duration,fs,port = SERIAL_LINE,fileName = "",maxDuration=MAX_DURATION):
        
        #usbser initialization
        usbser.__init__(self,duration,fs, port, fileName,maxDuration)
        
        #launch Thread initialization
        return threading.Thread.__init__(self)
    
    def stopSaving(self):
        """
        Stop the file recording
        IN:
            fileName: name and path of the file (string)
        """
        dataLock.acquire()
        if self._file != None:
            self._file.close()
            self._file = None
        dataLock.release() 
        
    def start(self, recFile=False):
        """
        Start the thread + deal with file saving:
        IN:
            recFile: boolean indicating if the data recording should start directly
        OUT:
            return an instance of  usbser containing the recorded signals
        """
        self._isRunning = True
        
        if recFile:
            dataLock.acquire()
            usbser.startSaving(self)
            dataLock.release()   
            
        threading.Thread.start(self)
        
    def run(self):
        
        self.connect()
        self.getData()
        
    def stop(self):
        """
        Stop the recording 
        """
             
        dataLock.acquire()
        self._isRunning = False
        dataLock.release()
        
        dataLock.acquire()
        # Arret du capteur :
        if(self._ser.isOpen()):
            # Fermeture du port :
            self._ser.write("gstop\n")
            self._ser.close()
        else:
            print "!!!!!!!!!!!!!!     port close"       
        dataLock.release()
        
        # Arret de l'enregistrement :
        self.stopSaving()         
        
       
    def getData(self):
        
        Shexa = ""
        tps = ""
        Sf = []
        #Initialize the data buffer with NaNs everywhere     
        self._dataBuffer._signals = np.empty((self._sizeMaxBuffer, 2))
        self._dataBuffer._signals.fill(np.nan)
        #Initialize the data buffer associated variables to empty
        self._nbSamplesBuffer = 0;        
        self.isBufferFull = False;
 
        #Set endloop variables
        self._isRunning = True;
        currentDuration = 0
        
        #Get data as long as the reception is not empty and the buffer not full        
        while (self._isRunning):
            
            #Stop if the recording duration is bigger or equal to the requested duration
            if (self._durationRecording != 0) and not(currentDuration < self._durationRecording):
                print "getData : fin de l'enregistrement, durationRecording depassee"
                self.stop()
                
            dataLock.acquire()
            data = self._ser.readline() #read the port
            dataLock.release()
            
            # Si les donnees fournies sont celles du GSR :
            if data[0]=="g" and data[1]==",":
                    
               dataSp = data.split(",") #separation de la ligne envoyee par le capteur en 3 donnees : g, tps et GSR
               tps = int(dataSp[1])*10**(-3) #temps en sec
               Shexa = str(dataSp[2])
               S = self.hex2float(Shexa) # Conversion des donnees
               Sf = [tps,S]
               print "rawdatas:" + str(tps) + ";" + str(S)
               sys.stdout.flush()
    
               #Acquire the lock to avoid file closing before saving
               dataLock.acquire() 
               #Add the incoming data to the class data + save to file if needed
               self.storeSignals(Sf) 
               #File can be closed, release the lock
               dataLock.release()
               #Update the duration of the recording
               
            currentDuration = currentDuration + self._Period*10**(-3)
                                            
    def getChannel(self,nameChannel=''):
        """

        """
        dataLock.acquire()
        data = usbser.getChannel(self,nameChannel)      
        dataLock.release()

        return data

            
if __name__ == "__main__":
   
 # TEST USBSER :  
#         fs = 50 # sampling rate
#         duration = 2 #duration of recording
#         sensor = usbser(2,fs,fileName = "test.txt")
#         sensor.start(True)
#             
#         plt.ion()
#         plt.show()
#              
#         for i in range(20):
#             data = sensor.getChannel()
#             sensor.getData()
#             plt.plot(data[:,0],data[:,1],color='red')
#             plt.draw()
#                
#         sensor.stop()

 # TEST USBSERTHREAD :  
        fs = 5 # sampling rate
        duration = 2 #duration of recording
        sensor = usbserThread(0,fs,fileName = "test.txt", maxDuration=30)
        sensor.start(True)  
        time.sleep(20)   

     
        plt.ion()
        plt.show()
               
        for i in range(150):
            data = sensor.getChannel()
            plt.plot(data[:,0],data[:,1],color='green')
            #time.sleep(0.5)
            plt.draw()
             
        time.sleep(2)
        if(sensor._ser.isOpen()):
            sensor.stop()  
         