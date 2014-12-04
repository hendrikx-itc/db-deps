.. db-deps documentation master file, created by
   sphinx-quickstart on Thu Dec  4 10:16:26 2014.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to db-deps's documentation!
===================================

The db-deps project provides functions for use in PostgreSQL projects with
dynamically managed database objects. Specifically, it provides a means to
edit database objects that require dropping and recreating of dependent
objects, without manually defining the statements for this dependent object
dropping and recreating.

Contents:

.. toctree::
   :maxdepth: 2

   dep_recurse


Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`

