ARG BASE_IMAGE=debian:bookworm
ARG VENV_PATH=/prod_venv

FROM ${BASE_IMAGE} as builder


# Install Poetry
ARG POETRY_HOME=/opt/poetry
ARG POETRY_VERSION=1.7.1

# Install vllm
ARG VLLM_VERSION=0.2.7

RUN apt-get update -y && apt-get install gcc python3 python3-pip python3-dev python3-venv python3-setuptools -y
RUN python3 -m venv ${POETRY_HOME} && ${POETRY_HOME}/bin/pip install poetry==${POETRY_VERSION}
ENV PATH="$PATH:${POETRY_HOME}/bin"

# Activate virtual env
ARG VENV_PATH
ENV VIRTUAL_ENV=${VENV_PATH}
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY kserve/pyproject.toml kserve/poetry.lock kserve/
RUN cd kserve && poetry install --no-root --no-interaction --no-cache
COPY kserve kserve
RUN cd kserve && poetry install --no-interaction --no-cache

COPY huggingfaceserver/pyproject.toml huggingfaceserver/poetry.lock huggingfaceserver/
RUN cd huggingfaceserver && poetry install --no-root --no-interaction --no-cache
COPY huggingfaceserver huggingfaceserver
RUN cd huggingfaceserver && poetry install --no-interaction --no-cache

RUN pip3 install vllm==${VLLM_VERSION}

# Use a Debian base image for the production stage
FROM debian:bookworm as prod

RUN apt-get update -y && apt-get install python3-venv -y

COPY third_party third_party

# Activate virtual env
ARG VENV_PATH
ENV VIRTUAL_ENV=${VENV_PATH}
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

ENV MODEL_ID=bert-base-uncased
ENV MODEL_NAME=bert

RUN useradd kserve -m -u 1000 -d /home/kserve

COPY --from=builder --chown=kserve:kserve $VIRTUAL_ENV $VIRTUAL_ENV
COPY --from=builder kserve kserve
COPY --from=builder huggingfaceserver huggingfaceserver

USER 1000
ENTRYPOINT ["python3", "-m", "huggingfaceserver", "--model_name", "bert", "--model_id", "bert-base-uncased"]
