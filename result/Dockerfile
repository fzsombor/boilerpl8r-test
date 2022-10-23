FROM registry.example.net/flink/base:1.11.1
ARG JOB
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8" \
    PYENV_ENV="${pyenv_env}" \
    PYENV_ROOT="/opt/.pyenv" \
    PYENV_INSTALLER="https://github.com/pyenv/pyenv.git" \
    PYENV_VIRTUALENV_INSTALLER="https://github.com/pyenv/pyenv-virtualenv.git" \
    PYTHON_MAJOR_VERSION="3.9" \
    PYTHONUNBUFFERED="1" \
    PYTHONDONTWRITEBYTECODE="1"
ENV PATH="${PYENV_ROOT}/bin:${PATH}" \
    PYTHON_VERSION="${PYTHON_MAJOR_VERSION}.8" \
    VENV_ROOT="${PYENV_ROOT}/versions/${PYTHON_VERSION}/envs"
# install pyenv dependencies
RUN yum-install-clean \
      bzip2 bzip2-devel gcc gcc-c++ git libffi-devel make openssl-devel patch readline-devel sqlite sqlite-devel tk-devel xz-devel zlib-devel
# install pyenv
RUN git clone "${PYENV_INSTALLER}" "${PYENV_ROOT}" && git clone "${PYENV_VIRTUALENV_INSTALLER}" "${PYENV_ROOT}/plugins/pyenv-virtualenv" \
    && eval "$(pyenv init --path)" && eval "$(pyenv init -)" && eval "$(pyenv virtualenv-init -)"
# install python
RUN pyenv install "${PYTHON_VERSION}"
RUN pyenv local "${PYTHON_VERSION}"
RUN pyenv exec pip install requests
RUN rm /bin/python && ln -s "${PYENV_ROOT}/versions/${PYTHON_VERSION}/bin/python${PYTHON_MAJOR_VERSION}" /bin/python

COPY conf/common/* ${FLINK_HOME}/conf/
COPY conf/env/ ${FLINK_HOME}/conf/
RUN rm ${FLINK_HOME}/conf/flink-conf.yaml

COPY entrypoint.sh /

RUN chown yarn:hadoop ${FLINK_HOME} -R
USER yarn

EXPOSE 8081 6123 44707 1732 17320 17321
RUN touch ${FLINK_HOME}/log/output.log
ENTRYPOINT ["/entrypoint.sh"]
CMD ["help"]
