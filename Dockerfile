FROM ubuntu:16.04

RUN apt-get update \
        && apt-get -qy install curl libssl-dev build-essential gcc \
        && curl -sSfLo init.sh https://nim-lang.org/choosenim/init.sh \
        && bash init.sh -y \ 
        && rm init.sh \
        && echo "export PATH=/root/.nimble/bin:$PATH" >> /etc/profile \
        && echo "export PATH=/root/.nimble/bin:$PATH" >> /etc/bash.bashrc \


