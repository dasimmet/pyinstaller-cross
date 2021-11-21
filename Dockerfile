FROM ubuntu:21.10 as BASE

ENV TZ=UTC \
    DEBIAN_FRONTEND="noninteractive" \
    WINEPREFIX=/runtime/wineprefix \
    WINEARCH=win64

ADD root/tmp-install/apt-dependencies.txt /apt-dependencies.txt

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get full-upgrade -y && \
    apt-get install --no-install-recommends -y $(cat /apt-dependencies.txt) && \
    apt-get clean -y && \
    rm -rf /apt-dependencies.txt


COPY root/runtime /runtime

WORKDIR /runtime/workdir

RUN python3 -m venv /runtime/native/venv && \
    . /runtime/native/venv/bin/activate && \
    python3 -m pip install -U pip wheel


FROM BASE AS XVFB

ARG WINEPYTHON_VERSION=3.9.9

ADD root/tmp-install /tmp-install

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends $(cat /tmp-install/build-dependencies.txt)

RUN curl -Lo /tmp-install/installer.exe https://www.python.org/ftp/python/$WINEPYTHON_VERSION/python-$WINEPYTHON_VERSION-amd64.exe && \
    winetricks win10 && \
    cp /tmp-install/venv.bat /runtime/wineprefix/drive_c/venv.bat && \
    xvfb-run sh -c "\
    set -x && \
    wine /tmp-install/installer.exe /quiet InstallAllUsers=1 PrependPath=1 Include_test=0 TargetDir=C:/Python && \
    wine C:/Python/python.exe -m venv C:/venv && \
    wine cmd /c C:/venv.bat python -m pip install -U pip wheel && \
    wineserver -w"

FROM BASE AS FINAL

COPY root/bin-wine /bin-wine
COPY root/usr/local/bin /usr/local/bin
COPY --from=XVFB /runtime/wineprefix /runtime/wineprefix