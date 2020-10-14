import numpy as np
import tensorflow as tf
import random as rn
import h5py
import os
from keras import backend as K
from keras.models import Sequential
from keras.layers import Dense, Activation

tf.compat.v1.logging.set_verbosity(tf.compat.v1.logging.ERROR)  # suppress compatibility warnings


def trainnet(netname,ntimepts,traindir):
    #  trainnet trains a neural network with ntimepts # of units in the hidden layer and 1 unit in the output layer.
    #  Tested with Python3 version 3.7.4, pip3 version 19.2.3, virtualenv version 16.7.5, and tensorflow 2.0
    #  INPUTS-
    #   1. netname: network name (string)
    #   2. ntimepts: the # of time points in a single waveform (integer)
    #   3. traindir: the path location of the training files (string), ex. "/Users/NASNet/training dir"
    #   .............each file in the traindir should contain a N x (1 + ntimepts) matrix
    #   .............The rows are the N waveforms to train the model with.
    #   .............The first column of the matrix should be the BINARY waveform labels (0 for noise, 1 for spike)
    #   .............The remaining ntimepts columns are the waveform voltage values.
    #   .............The array must be stored under the variable/group name 'waveData'
    #  OUTPUT: this function saves the following files
    #   1. the trained network (a Keras model file)
    #   2. the network weights/biases (4 text files- 1 weight file + 1 bias file for both the hidden + output layers)

    setrandomseed(0)    # use random seed to get reproducible results

    # CREATE NETWORK MODEL
    model = Sequential()
    model.add(Dense(units=50, input_dim=ntimepts))  # Hidden layer
    model.add(Activation('relu'))
    model.add(Dense(units=1))  # Output layer
    model.add(Activation('sigmoid'))

    model.compile(loss='binary_crossentropy', optimizer='Adam', metrics=['accuracy'])

    #  TRAIN MODEL
    trainingFiles = []
    for file in os.listdir(traindir):  # pull all training files from directory
        if file.endswith(".mat"):
            trainingFiles.append(file)

    nsets = len(trainingFiles)  # number of training files
    for j in range(nsets):  # loop over the different training files
        f_waves = h5py.File(traindir + '/' + trainingFiles[j],mode='r')  # load training file

        waveforms = np.transpose(f_waves['waveData'][()])
        x_train = waveforms[:, 1:(ntimepts+1)]  # waveform voltage values
        y_train = waveforms[:, 0]  # waveform labels
        model.fit(x_train, y_train, epochs=1, batch_size=100)

    print('...................finished training.........................')

    # SAVE PARAMETERS
    model.save(netname)  # save Keras model
    np.savetxt(netname + '_w_hidden', model.layers[0].get_weights()[0], fmt='%1.8f')  # save weights and biases of the model
    np.savetxt(netname + '_b_hidden', model.layers[0].get_weights()[1], fmt='%1.8f')
    np.savetxt(netname + '_w_output', model.layers[2].get_weights()[0], fmt='%1.8f')
    np.savetxt(netname + '_b_output', model.layers[2].get_weights()[1], fmt='%1.8f')

    #  Create a text file with the location of the network training data
    netinfo = open(netname + '_info.txt', 'w')
    netinfo.write('Network name: ' + netname)
    netinfo.write('\nTraining directory: ' + traindir)
    netinfo.close()
    return


def setrandomseed(seednum):
    # setrandomseed() ensures all necessary libraries are using a pre-set random seed
    # instructions from https://keras.io/getting-started/faq/#how-can-i-obtain-reproducible-results-using-keras-during-development

    os.environ["CUDA_DEVICE_ORDER"] = "PCI_BUS_ID"
    os.environ["CUDA_VISIBLE_DEVICES"] = ""
    os.environ['PYTHONHASHSEED'] = str(0)

    # The below is necessary for starting Numpy generated random numbers
    # in a well-defined initial state.
    np.random.seed(seednum)

    # The below is necessary for starting core Python generated random numbers
    # in a well-defined state.
    rn.seed(seednum)

    # Force TensorFlow to use single thread.
    # Multiple threads are a potential source of non-reproducible results.
    # For further details, see: https://stackoverflow.com/questions/42022950/
    session_conf = tf.compat.v1.ConfigProto(intra_op_parallelism_threads=1,
                                  inter_op_parallelism_threads=1)

    # The below tf.set_random_seed() will make random number generation
    # in the TensorFlow backend have a well-defined initial state.
    # For further details, see:
    # https://www.tensorflow.org/api_docs/python/tf/set_random_seed
    tf.compat.v2.random.set_seed(seednum)
    sess = tf.compat.v1.Session(graph=tf.compat.v1.get_default_graph(), config=session_conf)
    tf.compat.v1.keras.backend.set_session(sess)
    return
