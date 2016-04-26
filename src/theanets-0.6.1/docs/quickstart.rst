===============
Getting Started
===============

The ``theanets`` package provides tools for defining and optimizing several
common types of neural network models. It uses Python for rapid development, and
under the hood Theano_ provides graph optimization and fast computations on the
GPU.

This page provides a quick overview of the ``theanets`` package. It is aimed at
getting you up and running with a few examples. Once you understand the basic
workflow, you will be able to extend the examples to your own datasets and
modeling problems. After you've finished reading through this document, have a
look at :doc:`creating`, :doc:`training`, and :doc:`using` for more detailed
documentation.

.. _Theano: http://deeplearning.net/software/theano/

Installation
============

If you haven't already, the first thing you should do is download and install
``theanets``. The easiest way to do this is by using ``pip``::

  pip install theanets

This command will automatically install all of the dependencies for
``theanets``, including ``numpy`` and ``theano``.

If you're feeling adventurous, you can also check out the latest version of
``theanets`` and run the code from your local copy::

  git clone https://github.com/lmjohns3/theanets
  cd theanets
  python setup.py develop

This can be risky, however, since ``theanets`` is in active development---the
API might change in the development branch from time to time.

To work through the documentation you should also install a couple of supporting
packages::

  pip install skdata
  pip install matplotlib

These will help you obtain the example dataset described below, and also help in
making plots of various things.

Package Overview
================

At a high level, the ``theanets`` package is a tool for (a) defining and (b)
optimizing cost functions over a set of data. The workflow in ``theanets``
typically involves three basic steps:

#. First, you *define* the structure of the model that you'll use for your task.
   For instance, if you're trying to classify MNIST digits, you'll want
   something that takes in pixels and outputs digit classes (a "classifier"). If
   you're trying to model the unlabeled digit images, you might want to use a
   model that uses the same data for input and output (an "autoencoder").
#. Second, you *train* or adjust the parameters in your model so that it has a
   low cost or performs well with respect to some task. For classification, you
   might want to adjust your model parameters to minimize the negative
   log-likelihood of the correct image class given the pixels, and for
   autoencoders you might want to minimize the reconstruction error.

   A significant component of this step usually involves preparing the data that
   you'll use to train your model.
#. Finally, you *use* the trained model in some way, probably by predicting
   results on a test dataset, visualizing the learned features, and so on.

The ``theanets`` package provides a helper class, :class:`Experiment
<theanets.main.Experiment>`, that performs these tasks with relatively low
effort on your part. You typically define a model in ``theanets`` by creating an
experiment with a number of *model hyperparameters* that define the specific
behavior of your model, and then train your model using another set of
*optimization hyperparameters* that define the behavior of the optimization
algorithm.

The skeleton of your code will usually look something like this::

  import matplotlib.pyplot as plt
  import skdata.mnist
  import theanets

  # create an experiment to define a model.
  exp = theanets.Experiment(
      Model,
      hyperparam1=value1,
      hyperparam2=value2,
      # ...
  )

  # train the model.
  exp.train(
      training_data,
      validation_data,
      algorithm='foo',
      # ...
  )

  # use the trained model.
  model = exp.network
  model.predict(test_data)

This quickstart document shows how to implement these stages by following a
couple of examples.

Classifying MNIST Digits
========================

A standard benchmark for neural network
:class:`classification <theanets.feedforward.Classifier>` is the `MNIST digits
dataset <http://yann.lecun.com/exdb/mnist/>`_, a set of 70,000 28×28 images of
hand-written digits. Each MNIST digit is labeled with the correct digit class
(0, 1, ... 9). This example shows how to use ``theanets`` to create and train a
model that can perform this task.

.. image:: _static/mnist-digits-small.png

Networks for classification map a layer of continuous-valued inputs, through one
or more hidden layers, to an output layer that is activated through the `softmax
function`_. The softmax generates output that can be treated as a categorical
distribution over the digit labels given the input image.

.. _softmax function: http://en.wikipedia.org/wiki/Softmax_function

Defining the model
------------------

Now that you know which model to use for this task, you'll need to define some
hyperparameters that determine the structure of your network. The most important
of these is choosing a set of layer sizes that you want in your model.

The first ("input") and last ("output") layers in your network must match the
size of the data you'll be providing. For an MNIST classification task, this
means your network must have 784 inputs (one for each image pixel) and 10
outputs (one for each class).

Between the input and output layers, on the other hand, can be any number of
so-called "hidden" layers, in almost any configuration. Models with more than
about two hidden layers are commonly called "deep" models and have been quite
popular recently due to their success on a variety of difficult machine learning
problems. For now, though, to keep things simple, let's start out with a model
that just has one hidden layer with 100 units.

Once you've chosen the layers you want in your model, the easiest way to use
``theanets`` is to create an :class:`Experiment <theanets.main.Experiment>` to
construct your model::

  exp = theanets.Experiment(
      theanets.Classifier,
      layers=(784, 100, (10, 'softmax')))

This is all that's required to get started. There are many different
hyperparameters that can also be useful when constructing a model; see
:doc:`creating` for more information. Particularly useful to know will be the
different ways of creating layers; see :ref:`creating-specifying-layers` for
details.

Preparing the data
------------------

In ``theanets``, the parameters of a model are initialized randomly. To improve
the model's performance on the task, you'll need to train the model parameters.
This training process requires a dataset to compute gradient and loss function
values.

In the case of the MNIST digits, our classifier model will consume a dataset
consisting of two parts---"samples" (image pixels) and corresponding "labels"
(integer class values). Each of these parts is provided as a ``numpy`` array:
the samples are a two-dimensional array, with vectorized MNIST pixels arranged
along the first axis and pixel data arranged along the second axis; the labels
are a one-dimensional array, with one integer value per MNIST image.

For easy access to the MNIST digits dataset, we'll use the ``skdata`` package
and write a little bit of glue code to get the data into the desired format::

  def load_mnist():
      mnist = skdata.mnist.dataset.MNIST()
      mnist.meta  # trigger download if needed.
      def arr(n, dtype):
          # convert an array to the proper shape and dtype
          arr = mnist.arrays[n]
          return arr.reshape((len(arr), -1)).astype(dtype)
      train_images = arr('train_images', 'f') / 255.
      train_labels = arr('train_labels', np.uint8)
      test_images = arr('test_images', 'f') / 255.
      test_labels = arr('test_labels', np.uint8)
      return ((train_images[:50000], train_labels[:50000, 0]),
              (train_images[50000:], train_labels[50000:, 0]),
              (test_images, test_labels[:, 0]))

Here we've rescaled the image data so that each pixel lies in the interval [0,
1] instead of the default [0, 255]. (In general, it's a good idea to standardize
the data for your problem so that each dimension has approximately the same
scale.) We've also reshaped the data as described above.

.. note::

   Because ``theanets`` uses Theano for its computations, most datasets need to
   be cast to a value that is compatible with your setting for
   `Theano's "floatX" configuration parameter`_. Unless you have a really
   expensive GPU, this is likely to mean that you need to use 32-bit floats.

.. _Theano's "floatX" configuration parameter: http://deeplearning.net/software/theano/library/config.html#config.floatX

The load function returns a training split (the first 50000 examples), a
validation split (the remainder of the training data from ``skdata``, containing
10000 examples), and a test split (the test split from ``skdata``, containing
10000 examples). The training dataset is used to compute parameter updates, and
the validation dataset is used to determine when the model has stopped
improving during training.

There are other ways to provide data to your model during training; for a more
complete description, see :ref:`training-providing-data`.

Training the model
------------------

Now that you have a model and some data, you're ready to train the model so that
it performs the classification task as well as possible. The :class:`Experiment
<theanets.main.Experiment>` class handles the general case of training with
fairly little work.

The main decision to make during training is to choose the training algorithm to
use, along with values for any associated hyperparameters. This is most
naturally accomplished using the :func:`Experiment.train()
<theanets.main.Experiment.train>` method::

  train, valid, test = load_mnist()

  exp.train(train,
            valid,
            algorithm='nag',
            learning_rate=1e-3,
            momentum=0.9)

The first positional argument to this method is the training dataset, and the
second (if provided) is a validation dataset. (These positional arguments can
also be passed to :func:`Experiment.train() <theanets.main.Experiment.train>`
using the ``train_set`` and ``valid_set`` keywords, respectively.) If a
validation dataset is not provided, the training dataset will be used for
validation.

The ``algorithm`` keyword argument specifies an algorithm to use for training.
If you do not provide a value for this argument, :class:`RmsProp
<theanets.trainer.RmsProp>` is used as the default training algorithm. Any
subsequent keyword arguments will be passed to the training algorithm; these
arguments typically specify hyperparameters of the algorithm like the learning
rate and so forth.

The available training methods are described in
:ref:`training-available-trainers`; here we've specified Nesterov's Accelerated
Gradient, a type of stochastic gradient descent with momentum.

Visualizing features
--------------------

Once you've trained a classification model for MNIST digits, it can be
informative to visually inspect the features that the model has learned. Because
the model was trained using the MNIST digits, you can reshape the learned
features and visualize them as though they were 28×28 images::

  img = np.zeros((28 * 10, 28 * 10), dtype='f')
  for i, pix in enumerate(exp.network.find('hid1', 'w').get_value().T):
      r, c = divmod(i, 10)
      img[r * 28:(r+1) * 28, c * 28:(c+1) * 28] = pix.reshape((28, 28))
  plt.imshow(img, cmap=plt.cm.gray)
  plt.show()

In this example, the weights in layer 1 connect the inputs to the first hidden
layer; these weights have one column of 784 values for each hidden node in the
network, so we can iterate over the transpose and put each column---properly
reshaped---into a giant image.

The trained model can also be used to predict the class for a new MNIST digit::

  predicted_class = exp.network.predict(new_digit)

For more information on the things you can do with a model, see :doc:`using`.

Remembering Network Inputs
==========================

Recurrent neural networks are a family of network models whose computation graph
contains a cycle---that is, there are some layers in a recurrent network whose
outputs at a certain time step depend not only on the inputs at that time step,
but also on the state of the network at some previous time step as well.

Recurrent networks, while often quite tricky to train, can be used to solve
difficult modeling tasks. Thanks to recent advances in optimization algorithms,
recurrent networks are enjoying a resurgence in popularity and have been shown
to be quite effective at a number of different temporal modeling tasks.

In this section we consider a classic task for a recurrent network: remembering
data from past inputs. In this task, a network model receives one input value at
each time step. The network is to remember the first :math:`k` values, then wait
for :math:`t` time steps, and then reproduce the first :math:`k` values that it
saw. Effectively the model must ignore the inputs after time step :math:`k` and
start producing the desired output at time step :math:`k + t`.

Defining the model
------------------

We'll set up a recurrent model by creating an :class:`Experiment
<theanets.main.Experiment>` with the appropriate model class and layers::

  exp = theanets.Experiment(
      theanets.recurrent.Regressor,
      layers=(1, ('lstm', 10), 1))

Here we've specified that we're using a :class:`recurrent regression
<theanets.recurrent.Regressor>` model. Our network has three layers: the first
just has one input unit, the next is a Long Short-Term Memory (LSTM) recurrent
layer with ten units, and the output is a linear layer with just one output
unit. This is just one way of specifying layers in a network; for more details
see :ref:`creating-specifying-layers`.

Training the model
------------------

The most difficult part of training this model is creating the required data. To
compute the loss for a recurrent regression model in ``theanets``, we need to
provide two arrays of data---one input array, and one target output array. Each
of these arrays must have three dimensions: the first is time, the second is the
batch size, and the third is the number of inputs/outputs in the dataset.

For the memory task, we can easily create random arrays with the appropriate
shape. We just need to make sure that the last :math:`k` time steps of the
output are set to the first :math:`k` time steps of the input::

  T = 20
  K = 3
  BATCH_SIZE = 32

  def generate():
      s, t = np.random.randn(2, T, BATCH_SIZE, 1).astype('f')
      s[:K] = t[-K:] = np.random.randn(K, BATCH_SIZE, 1)
      return [s, t]

In ``theanets``, data can be provided to a trainer in several ways; here we've
used a callable that generates batches of data for us. See
:ref:`training-using-callables` for more information.

Having set up a way to create training data, we just need to pass this along to
our training algorithm::

  exp.train(generate, algorithm='rmsprop')

This process will adjust the weights in the model so that the outputs of the
model, given the inputs, will be closer and closer to the targets that we
provide.

More Information
================

This concludes the quick start guide! Please read more information about
creating models in ``theanets`` in :doc:`creating`, :doc:`training`, and
:doc:`using`. Once you're familiar with the basic concepts, the :doc:`reference`
section might also be useful.

The source code for ``theanets`` lives at http://github.com/lmjohns3/theanets.
Please fork, explore, and send pull requests!

Finally, there is also a mailing list for project discussion and announcements.
Subscribe online at https://groups.google.com/forum/#!forum/theanets.
