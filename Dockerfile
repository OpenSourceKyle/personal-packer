# Refernece: https://learn.hashicorp.com/tutorials/packer/get-started-install-cli

FROM debian 

RUN apt update -y
RUN apt install -y git vim zsh ca-certificates curl gnupg2

# Install Packer
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
RUN echo "deb [arch=amd64 trusted=yes] https://apt.releases.hashicorp.com buster main" | tee -a /etc/apt/sources.list
RUN apt update -y
RUN apt install -y packer

ARG UID
ARG GUID
ENV NEW_UID=$UID
ENV NEW_GUID=$GUID

# Shell customizations
RUN cp /etc/zsh/newuser.zshrc.recommended ~/.zshrc
RUN echo ' \n\
bindkey "^[[1;5C" forward-word \n\
bindkey "^[[1;5D" backward-word  \n\
alias ll="ls -la --color=auto" \n\
alias pkr="packer build -on-error=ask" \n\
clear \n\
echo "NOTE: This is only useful for remote (e.g. vSphere) Packer builds and will not work for local!" \n\
packer version \n\
packer -autocomplete-install \n\
./run_first_time_setup.sh \n\
' | tee -a ~/.zshrc

ENTRYPOINT ["/usr/bin/zsh"]
