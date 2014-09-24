/home/vagrant/bin/run-db-tests:
  file.managed:
    - source: salt://resources/run-db-tests
    - makedirs: true
    - user: vagrant
    - group: vagrant
    - mode: 755
