# To change this template, choose Tools | Templates
# and open the template in the editor.

__author__="Chanel"
__date__ ="$17 mars 2011 16:58:41$"

import numpy as np
import scipy as sp
import scipy.io
import scipy.signal

#######################################################################
#function [nbPeaks ampPeaks riseTime posPeaks] = peaksGSR(GSR, fe)
# This function computes the number of peaks in a GSR signal. It is based
# on the analysis of local minima and local maxima preceding the local
# minima. Here is the syntax:
# Inputs:
#   GSR [1*N] : the GSR signal
#   fe : the sampling rate
#   ampThresh : the peak amplitude threshold in Ohms from which a peak is
#               accepted (default = 200)
#Outputs:
#   nbPeaks : the number of peaks in the signal
#   ampPeaks : the amplitude of the peaks (local maxima - local minima)
#   riseTime : the duration of the rise time (time local minma - time local maxima)
#   posPeaks : index of the detected peaks in the GSR signal (in samples)
#Others:
# Some constants can be modifierd in the code:
#   ampThresh : the minimum difference between a local maxima and minima
#               for the peak to be considered as relevant
#   tThreshLow : minimum duration between local macima and minima
#   tThreshUp : maximum duration between local macima and minima
def peaksGSR(GSR, fe, ampThresh = 200):

    #These are the timing threshold defined
    tThreshLow = 1
    tThreshUp = 10

    #Search low and high peaks
    #low peaks are the GSR appex reactions (highest sudation)
    #High peaks are used as starting points for the reaction
    #dN = np.diff(np.diff(GSR) <= 0)
    dN = np.array(np.diff(GSR) <= 0 ,dtype=int)
    dN = np.diff(dN)
    idxL = np.where(dN < 0)[0] + 1; #+1 to account for the double derivative
    idxH = np.where(dN > 0)[0] + 1;


    #For each low peaks find it's nearest high peak and check that there is no
    #low peak between them, if there is then reject the peak (OR SEARCH FOR CURVATURE)
    riseTime = np.array([]) #vector of rise time for each detected peak
    ampPeaks = np.array([]) #vector of amplitude for each detected peak
    posPeaks = np.array([]) #final indexes of low peaks (not used but could be usefull for plot puposes)
    for iP in range(0,len(idxL)):
        #get list of high peak before the current low peak
        nearestHP = idxH[idxH < idxL[iP]]

        #if no high peak before (this is certainly the first peak detected in
        #the signal) don't do anything else process peak
        if len(nearestHP) > 0:
            #Get nearest high peak
            nearestHP = nearestHP[-1]

            #check if there is not other low peak between the nearest high and
            #the current low peaks. If not the case than compute peak features
            if not any( (idxL > nearestHP) & (idxL < idxL[iP]) ):
                rt = (idxL[iP] - nearestHP)/fe
                amp = GSR[nearestHP]- GSR[idxL[iP]]


                #if rise time and amplitude fits threshold then the peak is
                #considered and stored
                if (rt >= tThreshLow) and (rt <= tThreshUp) and (amp >= ampThresh):
                    riseTime = np.append(riseTime, rt)
                    ampPeaks = np.append(ampPeaks, amp)
                    posPeaks = np.append(posPeaks, idxL[iP])

    #Compute the number of positive peaks
    nbPeaks = len(posPeaks);

    #retype the arrays
    posPeaks = np.array(posPeaks,dtype=int)

    #return the values
    return nbPeaks, ampPeaks, riseTime, posPeaks

##################################################
#
#
def PICtoBPM(listePic, fe):

    bpm = np.array([])
    t = np.array([])
    deltaSamp = np.array([])

    for j in range(1,len(listePic)):
        #deltaSamp = np.append(deltaSamp, listePic[j]-listePic[j-1])
        deltaSamp = np.insert(deltaSamp, j-1,listePic[j]-listePic[j-1])
        if deltaSamp[-1] <= 0:
            raise PeakRange('L''ecart entre deux pic doit etre de 1 minimum')
        bpm = np.append(bpm, 60/(deltaSamp[j-1]/fe))
        t = np.append(t, np.mean((listePic[j-1], listePic[j])))

    delta_t = deltaSamp / fe;

    return bpm, delta_t, t

#################################################################
#function [bpm, delta_t, t, listePic] = PLETtoBPM3(data, fe, methodPeak, SizeWindow, verbose)
# calcul le heart rate bpm a partir du fichier des donnees data
# le signal a une frequence d'echantillonage fe. Search for the upper peak,
# if systolic upstroke is desired, simply negate the signal
#IN:
# data: the pletysmograph data
# fe: sampling frequency
# methodPeak: detection method for choice in case of many peak (default 'max')
#   'sharp': the shapest peak
#   'max: the highest peak
#   'first': the first peak of the two
# SizeWindow: for mean filtering, 0-> no fitlering (default fe/50)
# verbose: display a graph of the result if 1 (default 0)
#OUT:
# bpm : Heart rate in bpm
# delta : Heart rate in time
# t : vecteur contenant les samples central des deux pics ayant servi a
# calculer le bpm
# listePic : liste des echantillon ou il y a eu des pics detecte
# Ver 2 : n'utilise pas les wavlet mais seulement la derivee du signal
# Ver 3 : plus de gros filtrage et choix des pics suivant differentes
# methodes
def PLETtoBPM3(data, fe, methodPeak='max'):
    fe = float(fe)

    #Get the derivative of the signal
    diffS = np.diff(data)

    #recherche des pics postif : deriv decroissante = 0
    listePic = np.array([]);
    for iSpl in range(0,len(diffS)-1):
        if (diffS[iSpl] > 0) and (diffS[iSpl+1] < 0): #si il y a une derive == 0 sur le dernier sample elle n'est pas prise en compte
            listePic = np.append( listePic, iSpl+(diffS[iSpl] / (diffS[iSpl] - diffS[iSpl+1])) )
        elif (diffS[iSpl]==0) and (diffS[iSpl+1] < 0):
            listePic = np.append(listePic,iSpl)

    #Sure to keep that ?
    listePic = np.round(listePic)
    listePic = np.array(listePic,dtype=int)

    #In case there is not peak computed
    if len(listePic) < 2:
        print 'Warning: there is not enough peaks detected return 0 BPM'
        return 0


    #Procedure to keep only peaks that are separated by at least 0.5 seconds
    #other are considered as the same peak and one of the two is selected
    #according to the choosen method. Also peaks that are lie alone in the
    #first 0.5 seconds are removed (cannot dentermine wich peak it is...)
    limit = round(0.5*fe)

    #Remove too early first peak
    if (listePic[0] < limit) and ((listePic[1] - listePic[0]) >= limit):
        listePic = listePic[1:]

    #remove other peaks
    iPic = 0
    while iPic < (len(listePic) - 1):
        #If two peaks are too close keep the one depending on the method
        if(listePic[iPic+1] - listePic[iPic]) < limit:
            if methodPeak == 'sharp':
                nbSplFwd = round(0.05*fe)
                if listePic[iPic+1]+nbSplFwd > len(data):
                    nbSplFwd = len(data) - listePic[iPic+1];
                    print 'Warning: Not enough signal to look 0.05s ahead, looking at ' + str(nbSplFwd/fe) + 's ahead'
                sharp2 = data[listePic[iPic+1]] - data[listePic[iPic+1]+nbSplFwd-1];
                sharp1 = data[listePic[iPic]] - data[listePic[iPic]+nbSplFwd-1];
                if sharp1 < sharp2:
                    choice = 1
                else:
                    choice = 0

            elif methodPeak == 'max':
                if data[listePic[iPic]] > data[listePic[Pic+1]]:
                    choice = 0
                else:
                    choice = 1

            elif methodPeak == 'first':
                choice = 0

            else:
                raise UnknownPeakMethod('The method ' + methodPeak + 'is not a valid method for peak disambiguation')

            if choice == 0:
                listePic = np.delete(listePic,iPic+1)
            else:
                listePic = np.delete(listePic,iPic)

        else:
            iPic = iPic + 1

    if len(listePic) < 2:
        raise NotEnoughPeaks('There should be at least 2 peaks to detect')

    #Compute bpm from the pic list
    bpm, delta_t, t = PICtoBPM(listePic, fe)

    return bpm, delta_t, t, listePic


if __name__ == "__main__":
    print "This is just for tests"
    fileContent = sp.io.loadmat('physiosig.mat')

    print 'Test GSR signal peak computation'
    GSR = fileContent['GSR']
    GSR = GSR.squeeze()
    GSR = np.concatenate((np.ones(128)*GSR[0],GSR))
    GSR = sp.signal.lfilter(np.ones(128)/128,1,GSR)
    GSR = GSR[128:]
    nbPeaks, ampPeaks, riseTime, posPeaks = peaksGSR(GSR, 256)
    print nbPeaks
    print posPeaks


    print 'Test Plet peaks computation'
    Plet = fileContent['Plet']
    Plet = Plet.squeeze()
    Plet = np.concatenate((np.ones(5)*Plet[0],Plet))
    Plet = sp.signal.lfilter(np.ones(5)/5,1,Plet)
    Plet = Plet[5:]
    BPM, IBI, t, listePic = PLETtoBPM3(-Plet, 256, 'sharp')
    print IBI
    print BPM