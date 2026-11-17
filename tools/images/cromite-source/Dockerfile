ARG VERSION

FROM uazo/chromium:$VERSION

ARG CROMITE_SHA
ARG CROMITE_REPOSITORY
ENV CROMITE_SHA=$CROMITE_SHA
ENV CROMITE_REPOSITORY=$CROMITE_REPOSITORY

ARG HTTP_PROXY
ENV HTTP_PROXY=$HTTP_PROXY
ENV HTTPS_PROXY=$HTTP_PROXY
ENV https_proxy=$HTTP_PROXY

#USER lg
WORKDIR /home/lg/working_dir

RUN sudo chown lg /etc/apt/apt.conf.d/proxy.conf
RUN sudo echo "Acquire::http::Proxy \"$HTTP_PROXY\";" >/etc/apt/apt.conf.d/proxy.conf
RUN sudo apt-get update

COPY apply-cromite-patches.sh .

RUN sudo chmod +x ./apply-cromite-patches.sh && \
    mkdir cromite && \
    cd cromite && \
    git init && \
    git remote add origin https://github.com/$CROMITE_REPOSITORY.git && \
    git fetch origin $CROMITE_SHA && \
    git reset --hard FETCH_HEAD && \
    cd ..

RUN ./apply-cromite-patches.sh

