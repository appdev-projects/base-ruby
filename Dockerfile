FROM buildpack-deps:focal

### base ###
RUN yes | unminimize \
    && apt-get install -yq \
        zip \
        unzip \
        bash-completion \
        build-essential \
        htop \
        jq \
        less \
        locales \
        man-db \
        nano \
        software-properties-common \
        sudo \
        time \
        vim \
        multitail \
        lsof \
    && locale-gen en_US.UTF-8 \
    && mkdir /var/lib/apt/dazzle-marks \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

ENV LANG=en_US.UTF-8

### Git ###
RUN add-apt-repository -y ppa:git-core/ppa \
    && apt-get install -yq git \
    && rm -rf /var/lib/apt/lists/*

### Gitpod user ###
# '-l': see https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user
RUN useradd -l -u 33333 -G sudo -md /home/gitpod -s /bin/bash -p gitpod gitpod \
    # passwordless sudo for users in the 'sudo' group
    && sed -i.bkp -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers
ENV HOME=/home/gitpod
WORKDIR $HOME
# custom Bash prompt
RUN { echo && echo "PS1='\[\e]0;\u \w\a\]\[\033[01;32m\]\u\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\] \\\$ '" ; } >> .bashrc

### Gitpod user (2) ###
USER gitpod
# use sudo so that user does not get sudo usage info on (the first) login
RUN sudo echo "Running 'sudo' for Gitpod: success" && \
    # create .bashrc.d folder and source it in the bashrc
    mkdir /home/gitpod/.bashrc.d && \
    (echo; echo "for i in \$(ls \$HOME/.bashrc.d/*); do source \$i; done"; echo) >> /home/gitpod/.bashrc

### Ruby ###
LABEL dazzle/layer=lang-ruby
LABEL dazzle/test=tests/lang-ruby.yaml
USER gitpod
RUN curl -sSL https://rvm.io/mpapis.asc | gpg --import - \
    && curl -sSL https://rvm.io/pkuczynski.asc | gpg --import - \
    && curl -fsSL https://get.rvm.io | bash -s stable \
    && bash -lc " \
        rvm requirements \
        && rvm install 3.0.0 \
        && rvm use 3.0.0 --default --create \
        && rvm rubygems current \
        && gem install bundler --no-document \
        && gem install rufo htmlbeautifier --no-document" \
    && echo '[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*' >> /home/gitpod/.bashrc.d/70-ruby
RUN echo "rvm_gems_path=/home/gitpod/.rvm" > ~/.rvmrc

USER gitpod
# AppDev stuff

WORKDIR /base-rails

# Install Google Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add - 
RUN sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
RUN sudo apt-get -y update \
    && sudo apt-get -y install google-chrome-stable

# Install Chromedriver
RUN wget https://chromedriver.storage.googleapis.com/2.41/chromedriver_linux64.zip
RUN unzip chromedriver_linux64.zip

WORKDIR /base-rails
USER gitpod
RUN /bin/bash -l -c "sudo apt update && sudo apt install -y graphviz"

WORKDIR /base-rails
COPY Gemfile /base-rails/Gemfile
COPY Gemfile.lock /base-rails/Gemfile.lock
# For some reason, the copied files were owned by root so bundle could not succeed
RUN /bin/bash -l -c "sudo chown -R $(whoami):$(whoami) Gemfile Gemfile.lock"
USER gitpod
# Pre-install gems in Gemfile
RUN /bin/bash -l -c "bundle install"
# Install Heroku
RUN /bin/bash -l -c "curl https://cli-assets.heroku.com/install.sh | sh"
# Install node and yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
RUN sudo apt-get update && sudo apt-get install -y nodejs yarn

USER gitpod
# Hack to make Gitpod find pre-installed gems
RUN echo "rvm use 3.0.0" >> ~/.bashrc
RUN echo "rvm_silence_path_mismatch_check_flag=1" >> ~/.rvmrc
# Add bin/ to PATH, so bin/server executes
RUN echo 'export PATH="$PATH:$GITPOD_REPO_ROOT/bin"' >> ~/.bashrc


# Git global configuration
RUN git config --global push.default upstream \
    && git config --global merge.ff only \
    && git config --global alias.acm '!f(){ git add -A && git commit -am "${*}"; };f' \
    && git config --global alias.as '!git add -A && git stash' \
    && git config --global alias.p 'push' \
    && git config --global alias.sla 'log --oneline --decorate --graph --all' \
    && git config --global alias.co 'checkout' \
    && git config --global alias.cob 'checkout -b'

# Alias 'git' to 'g'
RUN echo 'export PATH="$PATH:$GITPOD_REPO_ROOT/bin"' >> ~/.bashrc
RUN echo "# No arguments: 'git status'\n\
# With arguments: acts like 'git'\n\
g() {\n\
  if [[ \$# > 0 ]]; then\n\
    git \$@\n\
  else\n\
    git status\n\
  fi\n\
}\n# Complete g like git\n\
source /usr/share/bash-completion/completions/git\n\
__git_complete g __git_main" >> ~/.bash_aliases

# Add current git branch to bash prompt
RUN echo "# Add current git branch to prompt\n\
parse_git_branch() {\n\
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \\\(.*\\\)/:(\\\1)/'\n\
}\n\
\n\
PS1='\[]0;\u \w\]\[[01;32m\]\u\[[00m\] \[[01;34m\]\w\[[00m\]\[\e[0;38;5;197m\]\$(parse_git_branch)\[\e[0m\] \\\$ '" >> ~/.bashrc
