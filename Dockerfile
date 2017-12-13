FROM postgres:10

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    make \
    patch \
    postgresql-server-dev-10

RUN mkdir /pgtap \
    && curl -L https://github.com/theory/pgtap/archive/master.tar.gz | tar -xzv -C /pgtap --strip-components=1 \
    && cd /pgtap \
    && make \
    && make install

COPY src /src

COPY docker-resources /
