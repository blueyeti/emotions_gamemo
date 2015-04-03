# To change this template, choose Tuools | Templates
# and open the template in the editor.
__author__ = "Chanel"
__date__ = "$16 mars 2011 15:03:02$"

import datetime
import time as t
import numpy as np
import scipy as sp
import scipy.io 
import scipy.linalg
import matplotlib
import matplotlib.pyplot as plt
import mlpy
import biosemisource as bs
import GSR_usbser as us
import sigphysio as sigphys
import win32com.client as winclient
import random
import os
import sys


TYPE_SESSION = 1
 #0: random, 1: physio adaptation

NB_FEATURES = 3
FILTER_SIZE_GSR = 0.5 #GSR filter size in seconds
#FILTER_SIZE_RESP = 0.25 #RESP filter size in seconds
FILTER_SIZE_BVP = .02 #BVP filter size in seconds

FILTER_SIZE_TEMP = 0.5 #TEMP filter size in seconds

FACTOR_SCR_GSR = 1e6# 1e9 #For SCR to GSR conversion
DISTANCE_THR = 0 #Distance beyond which we consider that the sample changes state

class EmoPlay:

    def __init__(self, duration, fs, paramSensor, playingTime,sensor):

        #Load the mat file containing the training data
        #fileContent = sp.io.loadmat('Features_Total_256Hz_nbSlices-5.mat')
        fileContent = sp.io.loadmat('Features_Total_256Hz_nbSlices-10.mat')
        #labels contains the indice 1 or -1 that corresponds whether we increase the level of the game of decrease
        #each feature corresponds to a label 
        targets = fileContent['labels']
        targets = targets.squeeze()
        features = fileContent['features']
        
        if sensor == 'usbser':
            self._trainFeatures = np.empty((features.shape[0],3))
            self._trainFeatures[:,0] = features[:,0] # selection of GSR's features
            self._trainFeatures[:,1] = features[:,3] # selection of GSR's features
            self._trainFeatures[:,2] = features[:,4] # selection of GSR's features
        else :
            self._trainFeatures = features 
        
        # Delete labels = 2 :   
        condition = (targets == 2)
        ligne = np.empty((0,1))  #index's list of "true" in condition
       
        for i in range(condition.shape[0]):
            if condition[i] == True :
                ligne = np.vstack((ligne,i))
                
        self._trainFeatures= np.delete(self._trainFeatures,ligne,axis = 0)
        targets = np.delete(targets,ligne, axis = 0)
        
        
        #store it for further normalization
        self._mean = np.mean(self._trainFeatures, axis=0)
        self._std = np.std(self._trainFeatures, axis=0)
        
        print("mean "+str(self._mean))
        print("std "+str(self._std))
        sys.stdout.flush()
        
        self._trainFeatures =  (self._trainFeatures - self._mean) / self._std
        #print fileContent['featuresNames']
        
        self._fda = mlpy.LDAC()
        self._fda.learn(self._trainFeatures, targets)
        est = self._fda.pred(self._trainFeatures)
        acc = mlpy.accuracy(targets, est) #computes the accuracy of the classification
        print "The accuracy on the training set is : " + str(acc)
        sys.stdout.flush()
        self._duration = duration
        self._fs = fs
        self.playingTime = playingTime #time in sec
        self._testFeatures = np.array([]) #define testFeatures array
        self._sensor = sensor
        self.previousEst = 0 #class of the previous classification of the sample.

        if sensor == 'biosemi' :
            #Create the Biosemi Source
            print "sensor used : BIOSEMI"
            self._sens = bs.BiosemiSourceThread(0, fs, bs.AUX_CHAN, 42, maxDuration=duration, ip=paramSensor) 
        if sensor == 'usbser' :            
            print "sensor used : USBSER"
            self._sens = us.usbserThread(0,fs,port=paramSensor, fileName = "test.txt", maxDuration=30)

        sys.stdout.flush()
        
    #The feature vector is arranged in an array like this:
    #[GSRMean GSRPerNegDeriv GSRNbPeaks VarResp MeanBPM MeanTemp]
    def _computeFeatures(self):
        #define testFeatures array
        self._testFeatures = np.zeros(NB_FEATURES)

        ##############################
        #Compute GSR features
        if (self._sensor == 'usbser'):
            #get channel and filter
            GSR = self._sens.getChannel('GSR1')[:,1]
            GSR = FACTOR_SCR_GSR / GSR ######################  this is to convert from SCR to GSR !!!! check div by 0
            winSize = round(FILTER_SIZE_GSR * self._fs)
    
            GSR = np.concatenate((np.ones(winSize) * GSR[0], GSR))
            
            GSR = sp.signal.lfilter(np.ones(winSize) / winSize, 1, GSR)
            GSR = GSR[winSize:]
    
            #GSR mean
            self._testFeatures[0] = GSR.mean()
    
            #GSR persentage of negative derivative
            dGSR = np.diff(GSR)
            
            self._testFeatures[1] = np.sum(dGSR < 0) / float(len(dGSR))
    
            #GSR number of peaks
            self._testFeatures[2] = sigphys.peaksGSR(GSR, self._fs, 0)[0]
            #ici on change le GSR amplitude

        if (self._sensor == 'biosemi'):
            GSR = self._sens.getChannel('GSR1')
            GSR = FACTOR_SCR_GSR / GSR ######################  this is to convert from SCR to GSR !!!! check div by 0
            winSize = round(FILTER_SIZE_GSR * self._fs)
            GSR = np.concatenate((np.ones(winSize) * GSR[0], GSR))
            GSR = sp.signal.lfilter(np.ones(winSize) / winSize, 1, GSR)
            GSR = GSR[winSize:]
    
    
            #GSR mean
            self._testFeatures[0] = GSR.mean()
    
            #GSR persentage of negative derivative
            dGSR = np.diff(GSR)
            self._testFeatures[1] = np.sum(dGSR < 0) / float(len(dGSR))
    
            #GSR number of peaks
            self._testFeatures[2] = sigphys.peaksGSR(GSR, self._fs, 0)[0]
            #ici on change le GSR amplitude
            ##############################
            #Compute Resp features
    
            #get channel and filter
            Resp = self._sens.getChannel('Resp')
            winSize = round(FILTER_SIZE_RESP * self._fs)
            Resp = np.concatenate((np.ones(winSize) * Resp[0], Resp))
            Resp = sp.signal.lfilter(np.ones(winSize) / winSize, 1, Resp)
            Resp = Resp[winSize:]
            Resp = sp.signal.detrend(Resp)
    
            #Resp standard deviation
            self._testFeatures[3] = Resp.std()
    
            ##############################
            #Compute BPM features
    
            #get channel and filtering
            BVP = self._sens.getChannel('Plet')
            winSize = round(FILTER_SIZE_BVP * self._fs)
            BVP = np.concatenate((np.ones(winSize) * BVP[0], BVP))
            BVP = sp.signal.lfilter(np.ones(winSize) / winSize, 1, BVP)
            BVP = BVP[winSize:]
            BVP = BVP - BVP.mean()
    
            #Compute BPM and take average
            BPM = sigphys.PLETtoBPM3(BVP, self._fs, 'sharp')[0]
            #TODO: add the BPM correction if usefull
            self._testFeatures[4] = BPM.mean()
    #        self._testFeatures[3] = BPM.mean()
    
            ##############################
            #Compute Temperature features
    
            #get channel and filtering
            Temp = self._sens.getChannel('Temp')
            winSize = round(FILTER_SIZE_TEMP * self._fs)
            Temp = np.concatenate((np.ones(winSize) * Temp[0], Temp))
            Temp = sp.signal.lfilter(np.ones(winSize) / winSize, 1, Temp)
            Temp = Temp[winSize:]
    
            #Compute temperature mean
            self._testFeatures[5] = Temp.mean()
    #        self._testFeatures[4] = Temp.mean()

    
    def computeBaseline(self):
        #Information concerning step
        print "Entering Baseline"
        sys.stdout.flush()

        #Initialize the baseline to zero
        self._baseline = np.zeros(NB_FEATURES)

        #Acquire the baseline
        if self._sens._isRunning != True :
            self._sens.start()
        #Wait for the buffer to be full
        while not self._sens.isBufferFull:
            #print "Waiting for buffer to fill up..."
            #sys.stdout.flush()
            t.sleep(.100);

        if self._sensor == 'usbser' :
            GSR = self._sens.getChannel('GSR1')[:,1]
            GSR = FACTOR_SCR_GSR / GSR
            #Create the baseline for the signals where it is simply the last sample value          
            self._baseline[0] = GSR.mean()
        
        if self._sensor == 'biosemi' :
            #Create the baseline for the signals where it is simply the last sample value
            self._baseline[0] = FACTOR_SCR_GSR / self._sens.getChannel('GSR1')[-1]
            self._baseline[4] = self._sens.getChannel('Temp')[-1]
    
            #Compute all the features (not needed but insure consistency) and create the baseline
            #for the signals where the rest feature value should be substracted
            self._computeFeatures();
            self._baseline[1] = 0
            #self._baseline[1] = self._testFeatures[1]
            
            self._baseline[2] = 0
            #self._baseline[2] = self._testFeatures[2]
            self._baseline[3] = self._testFeatures[3]

        #inform about features computation
        print 'The computed baseline vector is :'
        print self._baseline
        sys.stdout.flush()

    #Record the data for the defined time period
    #Compute the features and substract the baseline
    #Perform classification
    #send the adaptation command
    
    def playAdapted(self):
        
        #Create the shell for sending keys to applications
        shell = winclient.Dispatch("WScript.Shell")
        #Start the game with the enter key
        #shell.SendKeys('{ENTER}')

        #Wait the duration of sensor so that the signal only contains gaming signals
        #t.sleep(self._duration)
        t.sleep(self._sens._maxDuration); # !!! not the best to do

        #play adapted for 5 minutes and 20 seconds
        now_time = 0
        start_time = t.time();
        
        #while((now_time - start_time) < self.playingTime):
        while 1:
        #While the Actiview was not stopped
        #while self._sens._isRunning:
            #Compute the features on the new data and substract the baseline
            self._computeFeatures()
            print 'Computed feature vector : ' + str(self._testFeatures)
            self._testFeatures = self._testFeatures - self._baseline
            print 'Baselined feature vector : ' + str(self._testFeatures)
            sys.stdout.flush()

            #Perform classification
            features = ((self._testFeatures - self._mean)/self._std)
            print 'Standardized feature vector : ' + str(features)
            est = self._fda.pred (features)
            print 'Estimated target : ' + str(est)
            sys.stdout.flush()
           
            if self._sensor == "usbser" :
               # distance computing between the sample and the border line
                w = self._fda.w()
                b = self._fda.bias()
                x = features[0]
                y = features[1]
                z = features[2]
    
                distance = 0
                distance = self.computeDistance(w[0], w[1], w[2], b, x, y, z)
                print("distance : "+str(distance))
                sys.stdout.flush()
                
                # distances comparison
                if self.previousEst != 0 :
                    if np.abs(distance) < DISTANCE_THR :
                        est = self.previousEst 
     
            #Apply action to take
            if est == 1:
                print t.strftime('%I:%M%p') + ': Boredom inspected...Increasing game difficulty'
                #shell.SendKeys('u')
                sys.stdout.flush()
            else:
                print t.strftime('%I:%M%p') + ': Anxiety inspected...Decreasing game difficulty'
                #print t.strftime('%I:%M:%S%p') + ': Anxiety inspected...Decreasing game difficulty'
                #shell.SendKeys('d')
                sys.stdout.flush()
            
            self.previousEst = est

            #Compute features every 30 seconds (so wait 30 seconds)
            t.sleep(self._duration)
            now_time = t.time();
        self._sens.stop()
        
    def computeDistance(self,a = 0,b = 0,c = 0,d = 0,x = 0, y = 0, z = 0):
        # Compute the distance between the sample and the separation of the 2 states : boredom and anxiety, in case the sensor is usbser
        
        distance = (a*x + b*y + c*z + d) / float(np.sqrt(a**2 + b**2 + c**2))
        
        return distance
    
    def playRandom(self):
        
        #Stop biosemi acquisition since it is not usefull
        #self._sens.stop()
        
        #Create the shell for sending keys to applications
        shell = winclient.Dispatch("WScript.Shell")

        #Start the game with the enter key
        #shell.SendKeys('{ENTER}')

        #Wait one minute so that the signal only contains gaming signals (well
        #for symetry with biosemi version)
        #t.sleep(self._duration)
        t.sleep(self._sens._maxDuration); # !!! not the best to do

        #prepare a new seed (should not be needed)
        random.seed()

        #loop for 5 minutes and 20 seconds
        start_time = t.time()
        #print  "start"
        #print start_time
        now_time = 0
        start_time = t.time();
        
        
        
        while((now_time - start_time) < self.playingTime): # Playing time
#             print now_time 
#             print start_time
                
            #Choose uniformely between up and down
             choice = random.choice('du')
             shell.SendKeys(choice)

            #output the value nicely
             if choice == 'u':
                 print t.strftime('%I:%M%p') + ': Increasing game difficulty'
                 sys.stdout.flush()
             else:
                 print t.strftime('%I:%M:%S%p') + ':Decreasing game difficulty'
                 sys.stdout.flush()

            #Compute features every 30 seconds (so wait 30 seconds)
             t.sleep(self._duration);
             now_time = t.time();

if __name__ == "__main__":
    
    print ("THE BEGIN")
    sys.stdout.flush()
    
    #em = EmoPlay(60, 256, "129.194.71.0")
    #em = EmoPlay(60, 256, "127.0.0.1")
    #em = EmoPlay(30, 256, "129.194.71.231")
    em = EmoPlay(10, 50, "COM4", 320, 'usbser')
    
    #t.sleep(30);
    if(TYPE_SESSION == 1):
        
        em.computeBaseline()
        print "Starting a physiologically adapted play session"
        sys.stdout.flush()
        em.playAdapted() 
        
    else:        
        print "Starting a random play session"
        sys.stdout.flush()
        em.playRandom()
       
    print ("THE END")
