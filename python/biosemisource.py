# To change this template, choose Tools | Templates
# and open the template in the editor.

__author__ = "Chanel"
__date__ = "$26 April 2011 12:58:06$"

from  datetime import datetime
import numpy as np
import socket
import struct
import threading
import time
import matplotlib.pyplot as plt
#import os


#Defines
SOCK_TIMEOUT = 10 #Time for the socket timeout in seconds

EEG_CHAN = 1 #define the bit corresponding to EEG channels, only 32 EEG channels are supported
EX_CHAN = 2 #define the bit corresponding to EX channels
AUX_CHAN = 4 #define the bit corresponding to auxiliary channels

NB_BYTE_PER_SAMPLE = 3 #Number of bytes per Biosemi sample sent
MAX_DURATION = 60 #the maximum duration of a recording (in seconds), only impact on the buffer data not on the datafile
UPDATE_LOOP_BUFFER = 16 #the rate for looping buffer update: once the buffer is full we need to loop the buffer (ring buffer) but this is slow: let's update in looping mode only UPDATE_LOOP_BUFFER receptions
#initialize here all the values some of them are the same for electrodes & GSR & EX1
#for the others are not the same respiration plet, temp 

#standard electrodes
MAX_DIG_ELEC = 8388607
MIN_DIG_ELEC = -8388608
MAX_REAL_ELEC = 262143
MIN_REAL_ELEC = -262144

#ERGO
MAX_DIG_ERG = 8388607 
MIN_DIG_ERG = -8388608
MAX_REAL_ERG = 2097151
MIN_REAL_ERG = -2097152

#respiration
MAX_DIG_RESP = 8388607 
MIN_DIG_RESP = -8388608
MAX_REAL_RESP = 2097151
MIN_REAL_RESP = -2097152

#Plet
MAX_DIG_PLET = 8388607 
MIN_DIG_PLET = -8388608 
MAX_REAL_PLET = 4095875
MIN_REAL_PLET = -4096000

#Temp
MAX_DIG_TEMP = 8388607 
MIN_DIG_TEMP = -8388608 
MAX_REAL_TEMP = 8388  
MIN_REAL_TEMP = -8389


################################################################################
# BiosemiData class                                                            #
################################################################################
class BiosemiData:
    """
    This class allows to store Biosemi data and retreive the data of each
    channel simply by using its name. It can also easily store and read Biosemi
    data saved in a binary file as a 2D numpy array (lines are samples, and
    columns represent channels)
    """

################
    def __init__(self, channels, signals=None):
        """
        Constructor
        IN:
            channels: use the defines to give the type of channels of the data
                      for instance: EEG_CHAN + EX_CHAN mean 32 EEG channels + 8
                      external channels
            signals: numpy array containing some signals to consider as BiosemiData
        """
        #setup the channels (number of channels and dictionnary)
        self._setupChannels(channels)

        #if data store it in the class
        if signals != None:
            self.signals = signals
        else: #initialize empty np array
            self.signals = np.array([])

################
    def _setupChannels(self, channels, chanDict=None):
        """
        Prepare the class according to the Biosemi sent channels
        IN:
            channels: use the defines to give the type of channels of the data
                      for instance: EEG_CHAN + EX_CHAN mean 32 EEG channels + 8
                      external channels
            chanDict: dictionnary associating each channel of the class to a index
                      of the numpy array (index of the column for the channel). For
                      instance {'GSR':1},'EMG':2} indicate that the GSR channel is
                      in the first column and the EMG in the second.
        """
        if not(0 < channels < 8):
            print 'BiosemiData : The channel variable should be between 1 and 7'

        #Define a dictionnary for each type of channels and define the number of channels. The dictionnary maps each channel
        #name to a indice in the array of recevied data. The problem here is that the channels names can change
        #from a biosemi to another... change this part of the code if needed / wanted (just the channel names)
        self.nbChannels = 0
        self._getChanNb = {}
        if channels & EEG_CHAN:
            self._getChanNb.update({'FP1':self.nbChannels, 'AF3':self.nbChannels + 1, 'F7':self.nbChannels + 2, 'F3':self.nbChannels + 3, \
                                    'FC1':self.nbChannels + 4, 'FC5':self.nbChannels + 5, 'T7':self.nbChannels + 6, 'C3':self.nbChannels + 7, \
                                    'CP1':self.nbChannels + 8, 'CP5':self.nbChannels + 9, 'P7':self.nbChannels + 10, 'P3':self.nbChannels + 11, \
                                    'O1':self.nbChannels + 12, 'Oz':self.nbChannels + 13, 'Pz':self.nbChannels + 14, 'PO3':self.nbChannels + 15, \
                                    'P8':self.nbChannels + 16, 'P4':self.nbChannels + 17, 'PO4':self.nbChannels + 18, 'CP6':self.nbChannels + 19, \
                                    'CP2':self.nbChannels + 20, 'C4':self.nbChannels + 21, 'T8':self.nbChannels + 22, 'O2':self.nbChannels + 23, \
                                    'FC2':self.nbChannels + 24, 'Cz':self.nbChannels + 25, 'F8':self.nbChannels + 26, 'FC6':self.nbChannels + 27, \
                                    'Fz':self.nbChannels + 28, 'F4':self.nbChannels + 29, 'AF4':self.nbChannels + 30, 'Fp2':self.nbChannels + 31})
            self.nbChannels = self.nbChannels + 32
            
        if channels & EX_CHAN:
            self._getChanNb.update({'EXG1':self.nbChannels, 'EXG2':self.nbChannels + 1, 'EXG3':self.nbChannels + 2, \
                                    'EXG4':self.nbChannels + 3, 'EXG5':self.nbChannels + 4, 'EXG6':self.nbChannels + 5, \
                                    'EXG7':self.nbChannels + 6, 'EXG8':self.nbChannels + 7})
            self.nbChannels = self.nbChannels + 8
            
        if channels & AUX_CHAN:
            self._getChanNb.update({'GSR1':self.nbChannels, 'GSR2':self.nbChannels + 1, 'Erg1':self.nbChannels + 2, \
                                    'Erg2':self.nbChannels + 3, 'Resp':self.nbChannels + 4, 'Plet':self.nbChannels + 5, \
                                    'Temp':self.nbChannels + 6})
            self.nbChannels = self.nbChannels + 7

        #TODO: user management of dictionnary
        if chanDict != None:
            raise Exception('User management of dictionnary is not implemented yet')

################
    def getChannel(self, strChan):
        """
        Get the channel corresponding to a channel name
        IN:
            the input can be a string to get one chanel or a list of strings for several
            channels: ['Fp1', 'GSR1']. Other types are ignored and nothing is returned
            in this case.
        OUT:
            a row array for a unique channel and a 2D array with each signal in column
            for a list of channels. Return [] if there is no samples for the requested
            channels
        """
        if(self.signals.shape[0] < 1):
            return []
        else:
            if type(strChan) is type(str()):
                return self.signals[:, self._getChanNb[strChan]].squeeze()
            elif type(strChan) is type(list()):
                i = []
                for k in strChan:
                    i.append(self._getChanNb[k])
                return self.signals[:, i].squeeze()

################
    def saveToFile(self, fileName, mode, signals=None):
        """
        Save the Biosemi data in the class as a numpy array, can be used
        statically to save some external data
        IN:
            fileName: path + name of the file (string)
            mode:   string containing the type of opening: 'a' for appening at the
                    end of the file some other data (should be the same numbr of channels
                    as the previously saved data), 'w' for overwrite if the file already
                    exist
            signals: numpy array with signals in column to save in the file
        """
        file = open(fileName, mode)
        if data == None:
            self.signals.tofile(file)
        else:
            signals.tofile(file)
        file.close()


################
    def loadFromFile(self, fileName):
        """
        Load the Biosemi data in the class from the file fileName when the data
        was stored as a numpy array with signals in columns
        IN:
            fileName: path + name of the file (string)
        OUT:
            update the Biosemi data in the class + return the data as a numpy
            array
        """
        file = open(fileName, 'rb')
        self.signals = np.fromfile(file)
        if self.signals.size % float(self.nbChannels) != 0:
            raise Exception('BiosemiData : The number of found samples is not correct, are you sure the file contain the requested channels ?')
        else:
            self.signals = self.signals.reshape([self.signals.size / self.nbChannels, self.nbChannels])
        file.close()
        return self.signals


################################################################################
# BiosemiSource class                                                          #
################################################################################
class BiosemiSource:
    """
    This class is used to connect to the Actiview TCP sever and store the
    incoming Biosemi data. It can be used to store data in RAM or in a harddrive
    file. Be care full: if the duration is too long the buffer will contain only the
    last samples corresponding to maxDuration.
    """

################
    def __init__(self, duration, fs, channels, nbBytesArray, fileName="", ip="127.0.0.1", port=778, maxDuration=MAX_DURATION):
        """
        Constructor
        define the parameter of the connexion. The value of those parameters can be
        obtained by looking at the Labview program in the TCP server tab
        IN:
            duration: duration of data to collect in seconds at each call of getData.
                      If duration=0 the class acquires data until a call to the stop
                      function occurs (ActiView closed, error duting data transmition, etc...)
            fs: sampling rate choosen in Labview
            channels: an integer (between 1 and 7) giving the sent channels, use the defines to set it. For instance:
                - EEG_CHAN: 32 EEG channels (dictionnary not implemented yet)
                - EEG_CHAN + EX_CHAN: 32 EEG + EX channels
            nbBytesArray: number of bytes in the Biosemi TCP array (check actiview)
            ip: ip adress of the biosemi server (default = 127.0.0.1)
            port: port of the TCP biosemi socket (check actiview, default = 778)
            filename: if the filename is defined then the data is saved in a file with that name
            maxDuration: the maximum size of the buffer (the data in the buffer will correspond to the last maxDuration
                         seconds
        """
        #setup the channels (number of channels and dictionnary)
        self.bsdata = BiosemiData(channels)
        
        #setup the gain and offsets according to the channels
        self.initGainOffsets(channels)

        #determine size variables
        self._fs = fs
        self._maxDuration = maxDuration
        self.setDuration(duration) #Also empties the data buffer and set buffersize variables
        self._nbBytesArray = nbBytesArray
        self._nbSamples = nbBytesArray / (self.bsdata.nbChannels * NB_BYTE_PER_SAMPLE)
        print "BiosemiSource : Number of samples found (check if it corresponds to actiview): " + str(self._nbSamples)

        #setup the TCP communication
        self._ip = ip
        self._port = port

        #set the filename and initialize file pointer
        self._fileName = fileName
        self._file = None

        #Initialize the socket to None for later tests on availability
        self._sock = None
        

################
    def initGainOffsets(self, channels):
        
        """
        IN:channels, it can be EEG_CHAN, EX_CHAN, AUX_CHAN or any combination of them.
        OUT: a table with all the values of gain and offset in order to normalize the values obtained from biosemi
        the first row has the gain and the second has the offset
        This table will be used at the function _parseActiviewData
        
        The table is computed according to the way that eeglab  opens the .bdf data
        With the help of this table the digital values are transformed to the physiological ones
        The values MIN_REAL_ELEC etc are initialized at the begging of the program.
        """
        ######at the end i will have my table ready for the multiplications and add(the offset) with the signals
        self._arrayGainOffset = np.array([[], []])
                 
        if channels & EEG_CHAN:
            gain = float(MAX_REAL_ELEC - MIN_REAL_ELEC) / float(MAX_DIG_ELEC - MIN_DIG_ELEC)
            offset = MIN_REAL_ELEC - (gain * MIN_DIG_ELEC)
            arrayEEG = np.ones((2, 32)) 
            arrayEEG[0, :] *= gain
            arrayEEG[1, :] *= offset
            self._arrayGainOffset = np.hstack((self._arrayGainOffset, arrayEEG))
            
            #ajouter 32 colonnes avec gain et offset EEG  
            #the way I computed it in test i add it here 
            #
        if channels & EX_CHAN:
            gain = float(MAX_REAL_ELEC - MIN_REAL_ELEC) / float(MAX_DIG_ELEC - MIN_DIG_ELEC)
            offset = MIN_REAL_ELEC - (gain * MIN_DIG_ELEC)
            arrayEX = np.ones((2, 8)) 
            arrayEX[0, :] *= gain
            arrayEX[1, :] *= offset
            self._arrayGainOffset = np.hstack((self._arrayGainOffset, arrayEX))
           
        if channels & AUX_CHAN:
            gain_gsr = float(MAX_REAL_ELEC - MIN_REAL_ELEC) / float(MAX_DIG_ELEC - MIN_DIG_ELEC) 
            gain_erg = float(MAX_REAL_ERG - MIN_REAL_ERG) / float(MAX_DIG_ERG - MIN_DIG_ERG)
            gain_resp = float(MAX_REAL_RESP - MIN_REAL_RESP) / float(MAX_DIG_RESP - MIN_DIG_RESP) 
            gain_temp = float(MAX_REAL_TEMP - MIN_REAL_TEMP) / float(MAX_DIG_TEMP - MIN_DIG_TEMP) 
            gain_plet = float(MAX_REAL_PLET - MIN_REAL_PLET) / float(MAX_DIG_PLET - MIN_DIG_PLET)
            
            
            offset_gsr = (MIN_REAL_ELEC - (gain_gsr * MIN_DIG_ELEC))
            offset_erg = (MIN_REAL_ERG - (gain_erg * MIN_DIG_ERG))
            offset_resp = (MIN_REAL_RESP - (gain_resp * MIN_DIG_RESP))
            offset_plet = (MIN_REAL_PLET - (gain_plet * MIN_DIG_PLET))
            offset_temp = (MIN_REAL_TEMP - (gain_temp * MIN_DIG_TEMP))

            arrayAUX = np.array([[gain_gsr, gain_gsr, gain_erg, gain_erg, gain_resp, gain_plet, gain_temp],
                                 [offset_gsr, offset_gsr, offset_erg, offset_erg, offset_resp, offset_plet, offset_temp]]);
            
            #np.hstack is used to append all the tables computed before
            self._arrayGainOffset = np.hstack((self._arrayGainOffset, arrayAUX))
            
        return self._arrayGainOffset
            
################
    def setDuration(self, duration):
        """
        Change the duration of the recording (it empty the buffer)
        IN:
            duration: duration in seconds
        """
        if(duration > self._maxDuration) or (duration == 0):
            print "BiosemiSource : requested duration is higher than the maximum duration, buffer will contain only the last " + str(self._maxDuration) + " seconds"
            self._sizeMaxBuffer = self._maxDuration * self._fs
        else:
            self._sizeMaxBuffer = duration * self._fs
        self._durationRecording = duration * self._fs
	
	#Initialize the data buffer with NaNs everywhere 	
	self.bsdata.signals = np.empty((self._sizeMaxBuffer, self.bsdata.nbChannels))
	self.bsdata.signals.fill(np.nan)
	 #Initialize the data buffer associated variables to empty
	self._nbSamplesBuffer = 0;        
	self.isBufferFull = False;

################
    def setFileName(self, fileName):
        """
        Change the name of the fileName
        IN:
            fileName: name and path of the file (string)
        """
        self._fileName = fileName


################
    def startSaving(self, fileName=None):
        """
        Ask to start the saving of the acquired data (only done when the start
        fucntion will be called or if already called. Eventually Change the name
        of the fileName. A CALL TO THIS FUNCTION OVERWRITE ANY FILE THAT HAVE THE
        NAME SET FOR RECORDING.
        IN:
            fileName: name and path of the file (string, optional)
        """
        if fileName != None:
            self._fileName = fileName

        #Create the file for saving if needed
        if self._fileName != "" and self._file == None:
            self._file = open(self._fileName, 'wb')

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
    def start(self, recFile=False):
        """
        Start the recording which means:
            - connect to socket to actiview TCP server
            - get the data for the requested duration
        IN:
            recFile: boolean indicating if the data recording should start directly
        OUT:
            return an instance of  BiosemiData containing the recorded signals
        """
        self.connect()
        if recFile:
            self.startSaving()
        self.getData()
        return self.bsdata


################
    def stop(self):
        """
        Close the socket and the file + stop the acquisition loop
        """
        self._isRunning = False
        if self._sock != None:
            self._sock.close()
            self._sock = None
        
        self.stopSaving()


################
    def connect(self):
        """
        Connect the socket and open the recording file if needed
        """
        #if soket does not already exist create it and connect it
        if self._sock == None:
            self._sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self._sock.settimeout(SOCK_TIMEOUT);
            try:
                self._sock.connect((self._ip, self._port))
            except socket.error:
                print "BiosemiSource : Cannot connect to socket (" + self._ip + " [" + str(self._port) + "])... try to acquire data but this should not succeed..." #TODO check that this is correct and do correction (both classes)

################
    def getData(self):
        """
        This function fills the bsdata with the incoming data from the Biosemi TCP
        server. This is a blocking function up to the moment the requested duration of signals
        is acquired.
        OUT:
            the Biosemi data acquired
        """
        
        #Initialize the data buffer with NaNs everywhere 	
        self.bsdata.signals = np.empty((self._sizeMaxBuffer, self.bsdata.nbChannels))
        self.bsdata.signals.fill(np.nan)
        #Initialize the data buffer associated variables to empty
        self._nbSamplesBuffer = 0;        
        self.isBufferFull = False;
        #Set endloop variables
        self._isRunning = True;
        currentDuration = 0;
        #Get data as long as the reception is not empty and the buffer not full        
        while self._isRunning:
            if self._sock != None:
                #Get data from socket
                try:
                    data = self._socketrecvall(self._nbBytesArray)
                except socket.error:
                    print "BiosemiSource : Attempt to receive data from socket has timed out, stoping acquisition..."
                    self.stop()
                    return self.bsdata
                if not data:
                    print "BiosemiSource : The Actiview data buffer was empty, stoping acquisition..."
                    self.stop()
                    return self.bsdata
                elif len(data) != self._nbBytesArray: # should not occur anymore since socketrecvall was implemented
                    print "BiosemiSource : Packet does not have the expected size (" + str(len(data)) + " instead of " + str(self._nbBytesArray) + "), packet skipped..."                  
                else:
                    #Parse the recevied data packet
                    parsedData = self._parseActiviewData(data)
                    
                    """
                    here I have to call the function to normalize the data
                    before storing them 
                    """

                    #Add the incoming data to the class data + save to file if needed
                    self._storeSignals(parsedData)

                    #Update the duration of the recording
                    currentDuration = currentDuration + self._nbSamples

                #Stop if the recording duration is bigger or equal to the requested duration
                if (self._durationRecording != 0) and not(currentDuration < self._durationRecording):
                    self.stop()

        return self.bsdata

################
    def _socketrecvall(self, nbBytesToRead):
        """
        This function is usefull to make sure that the socket reads all of the
        nbBytesToRead. This replaces the call to self._sock.recv(self._nbBytesArray,
        MSG_WAITALL), since the falg is not usable under windows.
        IN:
            nbBytesToRead : number of bytes to read from the socket
        OUT:
            the data read from the socket
        """
        sockBuff = ''
        while len(sockBuff) < nbBytesToRead:
            data = self._sock.recv(nbBytesToRead - len(sockBuff))
            if not data:
                break # other end is closed!
            sockBuff += data 
        
        return sockBuff



    
################
    def _parseActiviewData(self, data):
        """
        Parse the data obtained in one socket call according to the Biosemi packet
        format (3Bytes coded in C2). Also order the data in a matrix with columns
        as signals and rows as samples.
        IN:
            data: data received from the Actiview software
        """

        values = []
        for i in range(0, len(data), NB_BYTE_PER_SAMPLE):
            toUnpack = b'\x00' + data[i:i + NB_BYTE_PER_SAMPLE]
            v = struct.unpack('<i', toUnpack)
            values.append(v[0] / 256.0)

        sigs = np.array(values)
        #one sample per row and one channel per column
        sigs = sigs.reshape((self._nbSamples, self.bsdata.nbChannels))
        
        #Normalization of values (gain*value + offset)  according to read_bdf from eeglab       
        sigs = ((sigs * self._arrayGainOffset[0]) + self._arrayGainOffset[1])
        return sigs
   
        
################
    def _storeSignals(self, newSigs):
        """
        Store the new acquired signals in the bsdata and in the file if needed
        IN:
            newSigs: signals to store in the file and in the bsdata
        """

        #Add the new signals to the current biosemi data
        if(self._nbSamplesBuffer < self._sizeMaxBuffer):
            #fill the buffer with the incoming data (replace the NaNs)
            self.bsdata.signals[self._nbSamplesBuffer:self._nbSamplesBuffer + newSigs.shape[0]] = newSigs
            self._nbSamplesBuffer += newSigs.shape[0]
            
            #Set the full buffer variable if the buffer is full
            if not (self._nbSamplesBuffer < self._sizeMaxBuffer):
                self.loopTmpBuff = np.empty((0, self.bsdata.nbChannels))
                self.isBufferFull = True
        
        else:
            #the maximum number of samples is reached
            #looping buffer to keep the same number of samples
            #the update in looping mode is not done every time but only
            #according to UPDATE_LOOP_BUFFER
            self.isBufferFull = True;
	    
            if(self.loopTmpBuff.shape[0] >= UPDATE_LOOP_BUFFER * self._nbSamples):		
                self.bsdata.signals = np.roll(self.bsdata.signals, -self.loopTmpBuff.shape[0], axis=0)
                self.bsdata.signals[-self.loopTmpBuff.shape[0]:, :] = self.loopTmpBuff
                self.loopTmpBuff = np.empty((0, self.bsdata.nbChannels))
            else:
                self.loopTmpBuff = np.vstack((self.loopTmpBuff, newSigs))

        #Add signals to the file if it exists
        if self._file != None:
            newSigs.tofile(self._file)

        # Just in case some one want to flush the file often for security
        #    if self._file != None:
        #        self._file.flush()
        #        os.fsync(self._file)


################
    def getChannel(self, strChan):
        """
        Get the channel corresponding to a channel name. Perform cleaning of the
	remaining end NaNs if the bsdata buffer is not full
        IN:
            the input can be a string to get one chanel or a list of strings for several
            channels: ['Fp1', 'GSR1']. Other types are ignored and nothing is returned
            in this case.
        OUT:
            a row array for a unique channel and a 2D array with each signal in column
            for a list of channels
        """
	#Do some clearning of the remaining NaNs if the buffer is not full
	if(not self.isBufferFull):
	    dataReturn = self.bsdata.getChannel(strChan)
            return dataReturn[:np.isnan(dataReturn).nonzero()[0][0]]
	else:
            return self.bsdata.getChannel(strChan)



################################################################################
# BiosemiSourceThread class                                                    #
################################################################################
dataLock = threading.Lock(); #lock for file access
class BiosemiSourceThread(BiosemiSource, threading.Thread):
    
################
    def __init__(self, duration, fs, channels, nbBytesArray, fileName="", ip="127.0.0.1", port=778, maxDuration=MAX_DURATION):
        """
        Simply call Thread and Biosemi source constructors
        """
        #lunch Biosemi source initialization
        BiosemiSource.__init__(self, duration, fs, channels, nbBytesArray, fileName, ip, port, maxDuration)

        #lunch Thread initialization
        return threading.Thread.__init__(self)

################
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

################
    def start(self, recFile=False):
        """
        Start the thread + deal with file saving:
        IN:
            recFile: boolean indicating if the data recording should start directly
        OUT:
            return an instance of  BiosemiData containing the recorded signals
        """
        if recFile:
            self.startSaving()

        threading.Thread.start(self)


################
    def stop(self):
        """
        Close the socket and the file + stop the acquisition loop, that function
        was overloaded to take into account file locking mechanisms
        """
        self._isRunning = False
        if self._sock != None:
            self._sock.close()
            self._sock = None
        
        self.stopSaving()



################
    def run(self):
        """
        Start the recording which means:
            - connect to socket to actiview TCP server
            - get the data for the requested duration
        OUT:
            return an instance of  BiosemiData containing the recorded signals
        """
        self.connect()
        self.getData()




################
    def getData(self):
        """
        This function fills the bsdata with the incoming data from the Biosemi TCP
        server. This is not a blocking function in the thread implementation and
        can be stopped at any moment using the run function. This function was
        overloaded to account for the lock mecanisms and the pause function
        OUT:
            the Biosemi data acquired
        """
        #Initialize the data buffer with NaNs everywhere 	
        self.bsdata.signals = np.empty((self._sizeMaxBuffer, self.bsdata.nbChannels))
        self.bsdata.signals.fill(np.nan)
        #Initialize the data buffer associated variables to empty
        self._nbSamplesBuffer = 0;        
        self.isBufferFull = False;
        #Set endloop variables
        self._isRunning = True;
        currentDuration = 0;
        #Get data as long as the reception is not empty and the buffer not full      
        while self._isRunning:
            if self._sock != None:
                #Get data from socket
                try:
                    data = self._socketrecvall(self._nbBytesArray)
                except socket.error:
                    print "BiosemiSource : Attempt to receive data from socket has timed out, stoping acquisition..."
                    self.stop()
                    return self.bsdata
                if not data:
                    print "BiosemiSource : The Actiview data buffer was empty, stoping acquisition..."
                    self.stop()
                    return self.bsdata
                elif len(data) != self._nbBytesArray: # should not occur anymore since socketrecvall was implemented
                    print "BiosemiSource : Packet does not have the expected size (" + str(len(data)) + " instead of " + str(self._nbBytesArray) + "), packet skipped..."                  
                else:
                    #Acquire the lock to avoid file closing before saving
                    dataLock.acquire()

                    #Parse the recevied data packet
                    parsedData = self._parseActiviewData(data)

                    #Add the incoming data to the class data + save to file if needed
                    self._storeSignals(parsedData)

                    #File can be closed, release the lock
                    dataLock.release()

                    #Update the duration of the recording
                    currentDuration = currentDuration + self._nbSamples

                #Stop if the recording duration is bigger or equal to the requested duration
                if (self._durationRecording != 0) and not(currentDuration < self._durationRecording):
                    self.stop()

        return self.bsdata #for coherence with the BiosemiSource class bu unusefull

    ################
    def getChannel(self, strChan):
        """
        Get the channel corresponding to a channel name
        IN:
            the input can be a string to get one chanel or a list of strings for several
            channels: ['Fp1', 'GSR1']. Other types are ignored and nothing is returned
            in this case.
        OUT:
            a row array for a unique channel and a 2D array with each signal in column
            for a list of channels
        """
        dataLock.acquire()
        data = BiosemiSource.getChannel(self, strChan)
        dataLock.release()

        return data




################################################################################
# Main function                                                                #
################################################################################
if __name__ == "__main__":

    print "This is a demonstration of how to use the BiosemiSource class"
    print "For this demonstration you need to set the sampling rate to 256Hz and send the 32 EEG and auxiliary channels (only) in the actiview"
    print "----------"
    print "Check in actiview that he number of Bytes in the TCP array is 234 (change it in the python code bellow otherwise)"
    print "Remember to change the mapping channel names if needed / wanted"
    print "2 seconds of data are displayed"
    #ipTest = "129.194.71.0"
    ipTest = "127.0.0.1"


    fs = 256 #biosemi sampling rate
    nbBytesArray = 234 #number of bytes in the actiview TCP array
    channels = AUX_CHAN + EEG_CHAN
    duration = 2 #duration of recording
    
    bs = BiosemiSource(duration, fs, channels, nbBytesArray, ip=ipTest)
    bs.start()
    print "These are the GSR1 and GSR2 signals in column"
    print bs.getChannel(['GSR1', 'GSR2'])
    print "This is the Temp vector"
    d = bs.getChannel('Temp')
    print d
    print "Duration of the signals"
    print len(d) / float(fs)


    print "\nNow the same but using threading and file creation:"
    print "----------"
    
    bs = BiosemiSourceThread(0, fs, channels, nbBytesArray, "test.txt", maxDuration=1, ip=ipTest) #duration for infinit looping (up to stop command)
    bs.connect() #Not needed but allows the sleep to be more precise
    bs.start(True) #True: start the recording of the file too
    start = datetime.now()
    duration = 2
    time.sleep(duration)
    end = datetime.now()
    delta = end - start
    print "Delta : " + str(delta)
    bs.stop()
    print "This is the GSR1 vector in RAM"
    d = bs.getChannel('GSR1')
    print d
    print "Duration of the signals : " + str(len(d) / float(fs))
    print "Number of samples : " + str(len(d))


    data = BiosemiData(channels)
    data.loadFromFile("test.txt")
    print "This is the GSR1 vector from file"
    d = data.getChannel('GSR1')
    print d
    print "Duration of the signals : " + str(len(d) / float(fs))
    print "Number of samples : " + str(len(d))

    print "\nNow a small demo for online plotting of signals (temp):"
    print "----------"
    bs = BiosemiSourceThread(0, fs, channels, nbBytesArray, maxDuration=30, ip=ipTest) #duration for infinit looping (up to stop command)
    bs.start()
    i = 0
    plt.ion()
    while (i < 7):
        d = bs.getChannel('Temp')
        if (d != None):
            plt.plot(d)
            plt.draw()
            plt.cla()
        time.sleep(1)
        i = i + 1;
    bs.stop()
    plt.show()
